package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"time"

	"melodi/go_backend/extension/manifest"
	"melodi/go_backend/network"
)

var (
	ErrRepositoryNotFound = errors.New("repository: not found")
	ErrInvalidRegistry    = errors.New("repository: invalid registry")
	ErrFetchFailed        = errors.New("repository: fetch failed")
)

type Repository struct {
	URL         string
	Name        string
	Description string
	Enabled     bool
	AddedAt     time.Time
	LastFetched time.Time
	LastError   string
}

type RegistrySnapshot struct {
	Repository Repository
	Registry   *manifest.Registry
	Error      string
	FetchedAt  time.Time
}

type Manager struct {
	mu            sync.RWMutex
	repositories  map[string]*Repository
	httpClient    *network.HTTPClient
	cache         map[string]*RegistrySnapshot
	cacheTTL      time.Duration
	defaultRepos  []string
}

func NewManager(httpClient *network.HTTPClient, defaultRepos []string) *Manager {
	return &Manager{
		repositories: make(map[string]*Repository),
		httpClient:   httpClient,
		cache:        make(map[string]*RegistrySnapshot),
		cacheTTL:     10 * time.Minute,
		defaultRepos: defaultRepos,
	}
}

func (m *Manager) Initialize(ctx context.Context) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, url := range m.defaultRepos {
		if _, exists := m.repositories[url]; !exists {
			m.repositories[url] = &Repository{
				URL:     url,
				Enabled: true,
				AddedAt: time.Now(),
			}
		}
	}
	return nil
}

func (m *Manager) Add(ctx context.Context, url string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.repositories[url]; exists {
		return nil
	}

	m.repositories[url] = &Repository{
		URL:     url,
		Enabled: true,
		AddedAt: time.Now(),
	}
	return nil
}

func (m *Manager) Remove(ctx context.Context, url string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.repositories[url]; !exists {
		return ErrRepositoryNotFound
	}

	if len(m.repositories) <= 1 {
		return fmt.Errorf("cannot remove last repository")
	}

	delete(m.repositories, url)
	delete(m.cache, url)
	return nil
}

func (m *Manager) Enable(ctx context.Context, url string, enabled bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	repo, exists := m.repositories[url]
	if !exists {
		return ErrRepositoryNotFound
	}
	repo.Enabled = enabled
	return nil
}

func (m *Manager) List() []Repository {
	m.mu.RLock()
	defer m.mu.RUnlock()

	repos := make([]Repository, 0, len(m.repositories))
	for _, repo := range m.repositories {
		repos = append(repos, *repo)
	}
	return repos
}

func (m *Manager) Get(url string) (Repository, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	repo, ok := m.repositories[url]
	if !ok {
		return Repository{}, false
	}
	return *repo, true
}

func (m *Manager) FetchRegistry(ctx context.Context, url string) (*RegistrySnapshot, error) {
	m.mu.RLock()
	repo, ok := m.repositories[url]
	m.mu.RUnlock()

	if !ok {
		return nil, ErrRepositoryNotFound
	}
	if !repo.Enabled {
		return &RegistrySnapshot{
			Repository: *repo,
			Error:      "repository disabled",
			FetchedAt:  time.Now(),
		}, nil
	}

	if cached, ok := m.getCached(url); ok {
		return cached, nil
	}

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return m.errorSnapshot(repo, fmt.Errorf("%w: %v", ErrFetchFailed, err)), nil
	}

	req.Header.Set("Accept", "application/json")

	resp, err := m.httpClient.Do(ctx, req)
	if err != nil {
		return m.errorSnapshot(repo, fmt.Errorf("%w: %v", ErrFetchFailed, err)), nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return m.errorSnapshot(repo, fmt.Errorf("%w: HTTP %d", ErrFetchFailed, resp.StatusCode)), nil
	}

	var body json.RawMessage
	decoder := json.NewDecoder(resp.Body)
	if err := decoder.Decode(&body); err != nil {
		return m.errorSnapshot(repo, fmt.Errorf("%w: invalid JSON: %v", ErrInvalidRegistry, err)), nil
	}

	registry, err := manifest.ParseRegistry(body, url)
	if err != nil {
		return m.errorSnapshot(repo, fmt.Errorf("%w: %v", ErrInvalidRegistry, err)), nil
	}

	snapshot := &RegistrySnapshot{
		Repository: *repo,
		Registry:   registry,
		FetchedAt:  time.Now(),
	}

	m.setCache(url, snapshot)

	m.mu.Lock()
	repo.LastFetched = time.Now()
	repo.LastError = ""
	m.mu.Unlock()

	return snapshot, nil
}

func (m *Manager) FetchAllRegistries(ctx context.Context) []*RegistrySnapshot {
	m.mu.RLock()
	urls := make([]string, 0, len(m.repositories))
	for url, repo := range m.repositories {
		if repo.Enabled {
			urls = append(urls, url)
		}
	}
	m.mu.RUnlock()

	results := make([]*RegistrySnapshot, 0, len(urls))
	for _, url := range urls {
		snapshot, err := m.FetchRegistry(ctx, url)
		if err != nil {
			snapshot = &RegistrySnapshot{
				Repository: Repository{URL: url},
				Error:      err.Error(),
				FetchedAt:  time.Now(),
			}
		}
		results = append(results, snapshot)
	}
	return results
}

func (m *Manager) GetAllEntries(ctx context.Context) ([]manifest.RegistryEntry, error) {
	snapshots := m.FetchAllRegistries(ctx)
	var allEntries []manifest.RegistryEntry
	seen := make(map[string]bool)

	for _, snapshot := range snapshots {
		if snapshot.Registry == nil {
			continue
		}
		for _, entry := range snapshot.Registry.Entries {
			key := entry.ID
			if !seen[key] {
				seen[key] = true
				allEntries = append(allEntries, entry)
			}
		}
	}

	return allEntries, nil
}

func (m *Manager) FindEntry(ctx context.Context, id string) (*manifest.RegistryEntry, string, error) {
	entries, err := m.GetAllEntries(ctx)
	if err != nil {
		return nil, "", err
	}

	for _, entry := range entries {
		if entry.ID == id {
			return &entry, "", nil
		}
	}

	return nil, "", ErrRepositoryNotFound
}

func (m *Manager) RefreshCache(ctx context.Context) {
	m.mu.Lock()
	m.cache = make(map[string]*RegistrySnapshot)
	m.mu.Unlock()

	m.FetchAllRegistries(ctx)
}

func (m *Manager) getCached(url string) (*RegistrySnapshot, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	snapshot, ok := m.cache[url]
	if !ok {
		return nil, false
	}

	if time.Since(snapshot.FetchedAt) > m.cacheTTL {
		return nil, false
	}

	return snapshot, true
}

func (m *Manager) setCache(url string, snapshot *RegistrySnapshot) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cache[url] = snapshot
}

func (m *Manager) errorSnapshot(repo *Repository, err error) *RegistrySnapshot {
	m.mu.Lock()
	repo.LastError = err.Error()
	m.mu.Unlock()

	return &RegistrySnapshot{
		Repository: *repo,
		Error:      err.Error(),
		FetchedAt:  time.Now(),
	}
}

func (m *Manager) SetCacheTTL(ttl time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cacheTTL = ttl
}

func (m *Manager) ClearCache() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cache = make(map[string]*RegistrySnapshot)
}