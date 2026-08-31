package manager

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"path/filepath"
	"sync"
	"time"

	"melodi/go_backend/download"
	"melodi/go_backend/filesystem"
)

var (
	ErrJobNotFound      = errors.New("manager: job not found")
	ErrInvalidJob       = errors.New("manager: invalid job")
	ErrDuplicateJob     = errors.New("manager: duplicate job")
	ErrManagerStopped   = errors.New("manager: manager stopped")
)

type DownloadManagerConfig struct {
	DownloaderConfig download.DownloaderConfig
	StorageRoot      string
	MaxQueueSize     int
	CleanupInterval  time.Duration
	MaxCompletedAge  time.Duration
}

func DefaultDownloadManagerConfig() DownloadManagerConfig {
	return DownloadManagerConfig{
		DownloaderConfig: download.DefaultDownloaderConfig(),
		StorageRoot:      "",
		MaxQueueSize:     1000,
		CleanupInterval:  1 * time.Hour,
		MaxCompletedAge:  7 * 24 * time.Hour,
	}
}

type DownloadManager struct {
	config       DownloadManagerConfig
	downloader   *download.Downloader
	fs           filesystem.Filesystem
	jobs         map[string]*download.Job
	mu           sync.RWMutex
	ctx          context.Context
	cancel       context.CancelFunc
	wg           sync.WaitGroup
	stopped      bool
	eventCh      chan JobEvent
}

type JobEvent struct {
	JobID   string
	Type    EventType
	Job     *download.Job
	Error   error
	Time    time.Time
}

type EventType string

const (
	EventJobQueued     EventType = "queued"
	EventJobStarted    EventType = "started"
	EventJobProgress   EventType = "progress"
	EventJobCompleted  EventType = "completed"
	EventJobFailed     EventType = "failed"
	EventJobCancelled  EventType = "cancelled"
	EventJobPaused     EventType = "paused"
	EventJobResumed    EventType = "resumed"
	EventJobRetried    EventType = "retried"
)

func NewDownloadManager(config DownloadManagerConfig, fs filesystem.Filesystem) (*DownloadManager, error) {
	if config.StorageRoot == "" {
		return nil, fmt.Errorf("storage root is required")
	}

	downloader := download.NewDownloader(config.DownloaderConfig)

	ctx, cancel := context.WithCancel(context.Background())

	m := &DownloadManager{
		config:     config,
		downloader: downloader,
		fs:         fs,
		jobs:       make(map[string]*download.Job),
		ctx:        ctx,
		cancel:     cancel,
		eventCh:    make(chan JobEvent, 100),
	}

	downloader.SetProgressCallback(m.onProgress)
	downloader.SetStateChangeCallback(m.onStateChange)

	m.wg.Add(1)
	go m.cleanupLoop()

	return m, nil
}

func (m *DownloadManager) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.stopped {
		return ErrManagerStopped
	}
	return nil
}

func (m *DownloadManager) Stop() {
	m.mu.Lock()
	m.stopped = true
	m.cancel()
	m.mu.Unlock()

	m.downloader.Shutdown()
	m.wg.Wait()
	close(m.eventCh)
}

func (m *DownloadManager) Download(ctx context.Context, req DownloadRequest) (*download.Job, error) {
	m.mu.RLock()
	if m.stopped {
		m.mu.RUnlock()
		return nil, ErrManagerStopped
	}
	m.mu.RUnlock()

	jobID := generateJobID(req.URL)
	m.mu.Lock()
	if _, exists := m.jobs[jobID]; exists {
		m.mu.Unlock()
		return nil, ErrDuplicateJob
	}
	m.mu.Unlock()

	outputDir := req.OutputDir
	if outputDir == "" {
		outputDir = filepath.Join(m.config.StorageRoot, "downloads")
	}

	if err := m.fs.MkdirAll(outputDir, 0750); err != nil {
		return nil, err
	}

	job := &download.Job{
		ID:               jobID,
		URL:              req.URL,
		Title:            req.Title,
		Artist:           req.Artist,
		Album:            req.Album,
		CoverURL:         req.CoverURL,
		Quality:          req.Quality,
		OutputDir:        outputDir,
		ExpectedSize:     req.ExpectedSize,
		ExpectedChecksum: req.ExpectedChecksum,
		MaxRetries:       m.config.DownloaderConfig.MaxRetries,
	}

	if err := m.downloader.AddJob(job); err != nil {
		return nil, err
	}

	m.mu.Lock()
	m.jobs[jobID] = job
	m.mu.Unlock()

	return job, nil
}

func (m *DownloadManager) GetJob(id string) (*download.Job, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	job, ok := m.jobs[id]
	return job, ok
}

func (m *DownloadManager) CancelJob(id string) error {
	return m.downloader.CancelJob(id)
}

func (m *DownloadManager) PauseJob(id string) error {
	return m.downloader.PauseJob(id)
}

func (m *DownloadManager) ResumeJob(id string) error {
	return m.downloader.ResumeJob(id)
}

func (m *DownloadManager) RetryJob(id string) error {
	return m.downloader.RetryJob(id)
}

func (m *DownloadManager) RemoveJob(id string) error {
	return m.downloader.RemoveJob(id)
}

func (m *DownloadManager) ListJobs() []*download.Job {
	return m.downloader.ListJobs()
}

func (m *DownloadManager) GetStats() download.Stats {
	return m.downloader.GetStats()
}

func (m *DownloadManager) Events() <-chan JobEvent {
	return m.eventCh
}

func (m *DownloadManager) onProgress(jobID string, progress float64, downloaded, total, speed int64, err error) {
	m.mu.RLock()
	job, ok := m.jobs[jobID]
	m.mu.RUnlock()

	if !ok {
		return
	}

	m.emitEvent(JobEvent{
		JobID: jobID,
		Type:  EventJobProgress,
		Job:   job,
		Time:  time.Now(),
	})
}

func (m *DownloadManager) onStateChange(jobID string, oldState, newState download.State) {
	m.mu.RLock()
	job, ok := m.jobs[jobID]
	m.mu.RUnlock()

	if !ok {
		return
	}

	var eventType EventType
	switch newState {
	case download.StateQueued:
		eventType = EventJobQueued
	case download.StateDownloading:
		eventType = EventJobStarted
	case download.StateCompleted:
		eventType = EventJobCompleted
	case download.StateFailed:
		eventType = EventJobFailed
	case download.StateCancelled:
		eventType = EventJobCancelled
	case download.StatePaused:
		eventType = EventJobPaused
	}

	if eventType != "" {
		m.emitEvent(JobEvent{
			JobID: jobID,
			Type:  eventType,
			Job:   job,
			Time:  time.Now(),
		})
	}
}

func (m *DownloadManager) emitEvent(event JobEvent) {
	select {
	case m.eventCh <- event:
	default:
	}
}

func (m *DownloadManager) cleanupLoop() {
	defer m.wg.Done()

	ticker := time.NewTicker(m.config.CleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			return
		case <-ticker.C:
			m.cleanup()
		}
	}
}

func (m *DownloadManager) cleanup() {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now()
	for id, job := range m.jobs {
		if job.State == download.StateCompleted || job.State == download.StateFailed || job.State == download.StateCancelled {
			if now.Sub(job.UpdatedAt) > m.config.MaxCompletedAge {
				delete(m.jobs, id)
			}
		}
	}
}

type DownloadRequest struct {
	URL               string
	Title             string
	Artist            string
	Album             string
	CoverURL          string
	Quality           download.Quality
	OutputDir         string
	ExpectedSize      int64
	ExpectedChecksum  string
}

func generateJobID(url string) string {
	hash := sha256.Sum256([]byte(url + time.Now().String()))
	return "dl_" + hex.EncodeToString(hash[:12])
}