package download

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

var (
	ErrDownloadFailed     = errors.New("download: failed")
	ErrDownloadCancelled  = errors.New("download: cancelled")
	ErrInvalidURL         = errors.New("download: invalid URL")
	ErrFileExists         = errors.New("download: file already exists")
	ErrChecksumMismatch   = errors.New("download: checksum mismatch")
	ErrDiskSpace          = errors.New("download: insufficient disk space")
	ErrQueueFull          = errors.New("download: queue full")
	ErrJobNotFound        = errors.New("download: job not found")
	ErrInvalidState       = errors.New("download: invalid state transition")
)

type State string

const (
	StatePending    State = "pending"
	StateQueued     State = "queued"
	StateDownloading State = "downloading"
	StatePaused     State = "paused"
	StateCompleted  State = "completed"
	StateFailed     State = "failed"
	StateCancelled  State = "cancelled"
)

type Quality string

const (
	QualityAuto     Quality = "auto"
	QualityLow      Quality = "low"
	QualityMedium   Quality = "medium"
	QualityHigh     Quality = "high"
	QualityLossless Quality = "lossless"
)

type Job struct {
	ID              string
	URL             string
	Title           string
	Artist          string
	Album           string
	CoverURL        string
	Quality         Quality
	OutputDir       string
	OutputFilename  string
	ExpectedSize    int64
	ExpectedChecksum string

	State           State
	Progress        float64
	BytesDownloaded int64
	TotalBytes      int64
	Speed           int64
	Error           string
	Retries         int
	MaxRetries      int

	CreatedAt       time.Time
	StartedAt       time.Time
	CompletedAt     time.Time
	UpdatedAt       time.Time

	mu              sync.RWMutex
	cancelFunc      context.CancelFunc
	ctx             context.Context
}

func (j *Job) GetState() State {
	j.mu.RLock()
	defer j.mu.RUnlock()
	return j.State
}

func (j *Job) SetState(state State) {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.State = state
	j.UpdatedAt = time.Now()
}

func (j *Job) SetProgress(downloaded, total int64, speed int64) {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.BytesDownloaded = downloaded
	j.TotalBytes = total
	j.Speed = speed
	if total > 0 {
		j.Progress = float64(downloaded) / float64(total)
	}
	j.UpdatedAt = time.Now()
}

func (j *Job) SetError(err error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err != nil {
		j.Error = err.Error()
	}
	j.UpdatedAt = time.Now()
}

func (j *Job) GetProgress() (float64, int64, int64, int64) {
	j.mu.RLock()
	defer j.mu.RUnlock()
	return j.Progress, j.BytesDownloaded, j.TotalBytes, j.Speed
}

func (j *Job) IsTerminal() bool {
	s := j.GetState()
	return s == StateCompleted || s == StateFailed || s == StateCancelled
}

func (j *Job) CanRetry() bool {
	j.mu.RLock()
	defer j.mu.RUnlock()
	return j.Retries < j.MaxRetries && (j.State == StateFailed || j.State == StateCancelled)
}

func (j *Job) IncrementRetry() {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.Retries++
	j.UpdatedAt = time.Now()
}

func (j *Job) Cancel() {
	if j.cancelFunc != nil {
		j.cancelFunc()
	}
	j.SetState(StateCancelled)
}

type ProgressCallback func(jobID string, progress float64, downloaded, total, speed int64, err error)
type StateChangeCallback func(jobID string, oldState, newState State)

type DownloaderConfig struct {
	MaxConcurrentDownloads int
	MaxRetries             int
	RetryDelay             time.Duration
	Timeout                time.Duration
	ChunkSize              int64
	UserAgent              string
	TempDir                string
	VerifyChecksum         bool
	ResumeEnabled          bool
}

func DefaultDownloaderConfig() DownloaderConfig {
	return DownloaderConfig{
		MaxConcurrentDownloads: 3,
		MaxRetries:             3,
		RetryDelay:             2 * time.Second,
		Timeout:                30 * time.Minute,
		ChunkSize:              1024 * 1024,
		UserAgent:              "Melodi/1.0",
		TempDir:                "",
		VerifyChecksum:         true,
		ResumeEnabled:          true,
	}
}

type Downloader struct {
	config           DownloaderConfig
	httpClient       *http.Client
	jobs             map[string]*Job
	activeCount      int32
	queue            chan *Job
	mu               sync.RWMutex
	progressCB       ProgressCallback
	stateChangeCB    StateChangeCallback
	wg               sync.WaitGroup
	shutdown         chan struct{}
}

func NewDownloader(config DownloaderConfig) *Downloader {
	if config.MaxConcurrentDownloads <= 0 {
		config = DefaultDownloaderConfig()
	}

	client := &http.Client{
		Timeout: config.Timeout,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	d := &Downloader{
		config:     config,
		httpClient: client,
		jobs:       make(map[string]*Job),
		queue:      make(chan *Job, config.MaxConcurrentDownloads*2),
		shutdown:   make(chan struct{}),
	}

	for i := 0; i < config.MaxConcurrentDownloads; i++ {
		d.wg.Add(1)
		go d.worker()
	}

	return d
}

func (d *Downloader) SetProgressCallback(cb ProgressCallback) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.progressCB = cb
}

func (d *Downloader) SetStateChangeCallback(cb StateChangeCallback) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.stateChangeCB = cb
}

func (d *Downloader) AddJob(job *Job) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	if _, exists := d.jobs[job.ID]; exists {
		return ErrJobNotFound
	}

	if job.MaxRetries == 0 {
		job.MaxRetries = d.config.MaxRetries
	}

	ctx, cancel := context.WithCancel(context.Background())
	job.ctx = ctx
	job.cancelFunc = cancel
	job.State = StateQueued
	job.CreatedAt = time.Now()
	job.UpdatedAt = time.Now()

	d.jobs[job.ID] = job

	select {
	case d.queue <- job:
	default:
		return ErrQueueFull
	}

	return nil
}

func (d *Downloader) GetJob(id string) (*Job, bool) {
	d.mu.RLock()
	defer d.mu.RUnlock()
	job, ok := d.jobs[id]
	return job, ok
}

func (d *Downloader) CancelJob(id string) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	job, ok := d.jobs[id]
	if !ok {
		return ErrJobNotFound
	}

	job.Cancel()
	return nil
}

func (d *Downloader) PauseJob(id string) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	job, ok := d.jobs[id]
	if !ok {
		return ErrJobNotFound
	}

	if job.State == StateDownloading {
		job.Cancel()
		job.SetState(StatePaused)
	}
	return nil
}

func (d *Downloader) ResumeJob(id string) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	job, ok := d.jobs[id]
	if !ok {
		return ErrJobNotFound
	}

	if job.State == StatePaused {
		ctx, cancel := context.WithCancel(context.Background())
		job.ctx = ctx
		job.cancelFunc = cancel
		job.State = StateQueued
		select {
		case d.queue <- job:
		default:
			return ErrQueueFull
		}
	}
	return nil
}

func (d *Downloader) RetryJob(id string) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	job, ok := d.jobs[id]
	if !ok {
		return ErrJobNotFound
	}

	if !job.CanRetry() {
		return ErrInvalidState
	}

	job.IncrementRetry()
	job.SetState(StateQueued)
	job.Error = ""

	ctx, cancel := context.WithCancel(context.Background())
	job.ctx = ctx
	job.cancelFunc = cancel

	select {
	case d.queue <- job:
	default:
		return ErrQueueFull
	}

	return nil
}

func (d *Downloader) RemoveJob(id string) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	job, ok := d.jobs[id]
	if !ok {
		return ErrJobNotFound
	}

	if job.State == StateDownloading {
		job.Cancel()
	}

	delete(d.jobs, id)
	return nil
}

func (d *Downloader) ListJobs() []*Job {
	d.mu.RLock()
	defer d.mu.RUnlock()

	jobs := make([]*Job, 0, len(d.jobs))
	for _, job := range d.jobs {
		jobs = append(jobs, job)
	}
	return jobs
}

func (d *Downloader) GetStats() Stats {
	d.mu.RLock()
	defer d.mu.RUnlock()

	stats := Stats{}
	for _, job := range d.jobs {
		stats.Total++
		switch job.State {
		case StateCompleted:
			stats.Completed++
		case StateFailed:
			stats.Failed++
		case StateDownloading:
			stats.Active++
		case StateQueued, StatePending:
			stats.Queued++
		case StateCancelled:
			stats.Cancelled++
		}
	}
	stats.ActiveWorkers = atomic.LoadInt32(&d.activeCount)
	return stats
}

type Stats struct {
	Total           int
	Completed       int
	Failed          int
	Active          int
	Queued          int
	Cancelled       int
	ActiveWorkers   int32
}

func (d *Downloader) worker() {
	defer d.wg.Done()

	for {
		select {
		case <-d.shutdown:
			return
		case job := <-d.queue:
			d.processJob(job)
		}
	}
}

func (d *Downloader) processJob(job *Job) {
	atomic.AddInt32(&d.activeCount, 1)
	defer atomic.AddInt32(&d.activeCount, -1)

	job.mu.Lock()
	oldState := job.State
	job.State = StateDownloading
	job.StartedAt = time.Now()
	job.UpdatedAt = time.Now()
	job.mu.Unlock()

	d.notifyStateChange(job.ID, oldState, StateDownloading)

	err := d.download(job)

	job.mu.Lock()
	if err != nil {
		if job.ctx.Err() == context.Canceled {
			job.State = StateCancelled
			job.Error = ErrDownloadCancelled.Error()
		} else {
			job.State = StateFailed
			job.SetError(err)

			if job.CanRetry() {
				job.IncrementRetry()
				job.State = StateQueued
				job.mu.Unlock()

				time.Sleep(d.config.RetryDelay)

				select {
				case d.queue <- job:
				default:
					job.mu.Lock()
					job.State = StateFailed
					job.SetError(ErrQueueFull)
				}
			}
		}
	} else {
		job.State = StateCompleted
		job.CompletedAt = time.Now()
		job.Progress = 1.0
	}
	job.UpdatedAt = time.Now()
	job.mu.Unlock()

	d.notifyStateChange(job.ID, oldState, job.State)
	d.notifyProgress(job.ID, job.Progress, job.BytesDownloaded, job.TotalBytes, job.Speed, err)
}

func (d *Downloader) download(job *Job) error {
	req, err := http.NewRequestWithContext(job.ctx, "GET", job.URL, nil)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidURL, err)
	}

	req.Header.Set("User-Agent", d.config.UserAgent)

	if d.config.ResumeEnabled {
		tmpPath := d.getTempPath(job)
		if info, err := os.Stat(tmpPath); err == nil && info.Size() > 0 {
			req.Header.Set("Range", fmt.Sprintf("bytes=%d-", info.Size()))
		}
	}

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDownloadFailed, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		return fmt.Errorf("%w: HTTP %d", ErrDownloadFailed, resp.StatusCode)
	}

	totalSize := resp.ContentLength
	if totalSize <= 0 && resp.Header.Get("Content-Length") != "" {
		fmt.Sscanf(resp.Header.Get("Content-Length"), "%d", &totalSize)
	}

	ext := d.guessExtension(job.URL, resp.Header.Get("Content-Type"))
	outputPath := d.getOutputPath(job, ext)
	tmpPath := d.getTempPath(job)

	if err := os.MkdirAll(filepath.Dir(outputPath), 0750); err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(tmpPath), 0750); err != nil {
		return err
	}

	var file *os.File
	var downloaded int64

	if d.config.ResumeEnabled {
		if info, err := os.Stat(tmpPath); err == nil {
			downloaded = info.Size()
			file, err = os.OpenFile(tmpPath, os.O_APPEND|os.O_WRONLY, 0640)
			if err != nil {
				return err
			}
		} else {
			file, err = os.Create(tmpPath)
			if err != nil {
				return err
			}
		}
	} else {
		file, err = os.Create(tmpPath)
		if err != nil {
			return err
		}
	}
	defer file.Close()

	hasher := sha256.New()
	multiWriter := io.MultiWriter(file, hasher)

	buf := make([]byte, d.config.ChunkSize)
	startTime := time.Time{}
	lastUpdate := time.Time{}

	for {
		select {
		case <-job.ctx.Done():
			return ErrDownloadCancelled
		default:
		}

		n, err := resp.Body.Read(buf)
		if n > 0 {
			if _, err := multiWriter.Write(buf[:n]); err != nil {
				return err
			}
			downloaded += int64(n)

			if startTime.IsZero() {
				startTime = time.Now()
			}
			if time.Since(lastUpdate) > 500*time.Millisecond {
				elapsed := time.Since(startTime).Seconds()
				var speed int64
				if elapsed > 0 {
					speed = int64(float64(downloaded) / elapsed)
				}
				job.SetProgress(downloaded, totalSize, speed)
				d.notifyProgress(job.ID, job.Progress, downloaded, totalSize, speed, nil)
				lastUpdate = time.Now()
			}
		}

		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}

	if err := file.Sync(); err != nil {
		return err
	}

	if d.config.VerifyChecksum && job.ExpectedChecksum != "" {
		actual := hex.EncodeToString(hasher.Sum(nil))
		if !strings.EqualFold(actual, job.ExpectedChecksum) {
			return fmt.Errorf("%w: expected %s, got %s", ErrChecksumMismatch, job.ExpectedChecksum, actual)
		}
	}

	if err := os.Rename(tmpPath, outputPath); err != nil {
		return err
	}

	job.mu.Lock()
	job.OutputFilename = filepath.Base(outputPath)
	job.mu.Unlock()

	return nil
}

func (d *Downloader) getTempPath(job *Job) string {
	tempDir := d.config.TempDir
	if tempDir == "" {
		tempDir = os.TempDir()
	}
	return filepath.Join(tempDir, "melodi_downloads", job.ID+".part")
}

func (d *Downloader) getOutputPath(job *Job, ext string) string {
	if job.OutputFilename != "" {
		return filepath.Join(job.OutputDir, job.OutputFilename)
	}

	safeTitle := sanitizeFilename(job.Title)
	safeArtist := sanitizeFilename(job.Artist)
	filename := fmt.Sprintf("%s - %s.%s", safeArtist, safeTitle, ext)

	counter := 1
	outputPath := filepath.Join(job.OutputDir, filename)
	for {
		if _, err := os.Stat(outputPath); os.IsNotExist(err) {
			break
		}
		filename = fmt.Sprintf("%s - %s (%d).%s", safeArtist, safeTitle, counter, ext)
		outputPath = filepath.Join(job.OutputDir, filename)
		counter++
	}

	return outputPath
}

func (d *Downloader) guessExtension(url, contentType string) string {
	contentType = strings.ToLower(contentType)
	switch {
	case strings.Contains(contentType, "flac"):
		return "flac"
	case strings.Contains(contentType, "mpeg") || strings.Contains(contentType, "mp3"):
		return "mp3"
	case strings.Contains(contentType, "mp4") || strings.Contains(contentType, "m4a"):
		return "m4a"
	case strings.Contains(contentType, "aac"):
		return "aac"
	case strings.Contains(contentType, "ogg"):
		return "ogg"
	case strings.Contains(contentType, "opus"):
		return "opus"
	case strings.Contains(contentType, "wav"):
		return "wav"
	}

	if idx := strings.LastIndex(url, "."); idx != -1 {
		ext := url[idx+1:]
		ext = strings.Split(ext, "?")[0]
		ext = strings.Split(ext, "#")[0]
		validExts := map[string]bool{"flac": true, "mp3": true, "m4a": true, "aac": true, "ogg": true, "opus": true, "wav": true}
		if validExts[strings.ToLower(ext)] {
			return strings.ToLower(ext)
		}
	}

	return "m4a"
}

func sanitizeFilename(name string) string {
	replacer := strings.NewReplacer(
		"/", "-", "\\", "-", ":", "-", "*", "-", "?", "-",
		"\"", "-", "<", "-", ">", "-", "|", "-",
	)
	s := replacer.Replace(name)
	s = strings.TrimSpace(s)
	if len(s) > 200 {
		s = s[:200]
	}
	if s == "" {
		s = "unknown"
	}
	return s
}

func (d *Downloader) notifyProgress(jobID string, progress float64, downloaded, total, speed int64, err error) {
	d.mu.RLock()
	cb := d.progressCB
	d.mu.RUnlock()
	if cb != nil {
		cb(jobID, progress, downloaded, total, speed, err)
	}
}

func (d *Downloader) notifyStateChange(jobID string, oldState, newState State) {
	d.mu.RLock()
	cb := d.stateChangeCB
	d.mu.RUnlock()
	if cb != nil {
		cb(jobID, oldState, newState)
	}
}

func (d *Downloader) Shutdown() {
	close(d.shutdown)
	d.wg.Wait()

	d.mu.Lock()
	for _, job := range d.jobs {
		if job.State == StateDownloading {
			job.Cancel()
		}
	}
	d.mu.Unlock()
}