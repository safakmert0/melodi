package manager

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"melodi/go_backend/extension/health"
	"melodi/go_backend/extension/installer"
	"melodi/go_backend/extension/manifest"
	"melodi/go_backend/extension/permissions"
	"melodi/go_backend/extension/repository"
	"melodi/go_backend/extension/runtime"
	"melodi/go_backend/extension/storage"
	"melodi/go_backend/network"
)

var (
	ErrExtensionNotFound   = errors.New("manager: extension not found")
	ErrExtensionExists     = errors.New("manager: extension already installed")
	ErrExtensionDisabled   = errors.New("manager: extension disabled")
	ErrInvalidManifest     = errors.New("manager: invalid manifest")
	ErrRuntimeInitFailed   = errors.New("manager: runtime initialization failed")
	ErrNotInitialized      = errors.New("manager: not initialized")
)

type InstalledExtension struct {
	Manifest    *manifest.Manifest
	Enabled     bool
	InstalledAt time.Time
	UpdatedAt   time.Time
	StoragePath string
	Runtime     *runtime.Runtime
	Health      *health.HTTPEndpointChecker
}

type ManagerConfig struct {
	StorageRoot            string
	StorageQuota           int64
	MaxFileSize            int64
	CurrentAppVersion      string
	APIVersion             string
	HealthInterval         time.Duration
	HealthTimeout          time.Duration
	DefaultPermissions     []string
	DefaultNetworkDomains  []string
}

func DefaultManagerConfig() ManagerConfig {
	return ManagerConfig{
		StorageRoot:            "",
		StorageQuota:           100 * 1024 * 1024,
		MaxFileSize:            10 * 1024 * 1024,
		CurrentAppVersion:      "1.0.0",
		APIVersion:             "1",
		HealthInterval:         5 * time.Minute,
		HealthTimeout:          10 * time.Second,
		DefaultPermissions:     []string{"network", "storage"},
		DefaultNetworkDomains:  []string{},
	}
}

type Manager struct {
	mu               sync.RWMutex
	config           ManagerConfig
	httpClient       *network.HTTPClient
	storage          storage.Storage
	installed        map[string]*InstalledExtension
	repoManager      *repository.Manager
	installer        *installer.Installer
	permManager      *permissions.PermissionManager
	healthManager    *health.Manager
	initialized      bool
}

func NewManager(httpClient *network.HTTPClient, config ManagerConfig) (*Manager, error) {
	if config.StorageRoot == "" {
		return nil, fmt.Errorf("storage root is required")
	}

	rootStorage, err := storage.NewStorage(config.StorageRoot, config.StorageQuota, config.MaxFileSize)
	if err != nil {
		return nil, fmt.Errorf("failed to create root storage: %w", err)
	}

	permManager := permissions.NewPermissionManager(
		config.DefaultPermissions,
		config.DefaultNetworkDomains,
	)

	healthManager := health.NewManager()

	repoManager := repository.NewManager(httpClient, []string{})

	inst := installer.NewInstaller(httpClient, rootStorage, installer.InstallOptions{
		StorageRoot:        config.StorageRoot,
		StorageQuota:       config.StorageQuota,
		MaxFileSize:        config.MaxFileSize,
		CurrentAppVersion:  config.CurrentAppVersion,
		APIVersion:         config.APIVersion,
	})

	m := &Manager{
		config:        config,
		httpClient:    httpClient,
		storage:       rootStorage,
		installed:     make(map[string]*InstalledExtension),
		repoManager:   repoManager,
		installer:     inst,
		permManager:   permManager,
		healthManager: healthManager,
		initialized:   false,
	}

	return m, nil
}

func (m *Manager) Initialize(ctx context.Context) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.initialized {
		return nil
	}

	if err := m.repoManager.Initialize(ctx); err != nil {
		return fmt.Errorf("failed to initialize repository manager: %w", err)
	}

	if err := m.loadInstalledExtensions(ctx); err != nil {
		return fmt.Errorf("failed to load installed extensions: %w", err)
	}

	m.healthManager.StartAll(ctx)

	m.initialized = true
	return nil
}

func (m *Manager) loadInstalledExtensions(ctx context.Context) error {
	extDirs, err := m.storage.ListFiles("extensions/")
	if err != nil {
		return err
	}

	for _, dir := range extDirs {
		if !dir.IsDir {
			continue
		}

		manifestData, err := m.storage.ReadFile(dir.Path + "/manifest.json")
		if err != nil {
			continue
		}

		mf, err := manifest.ParseManifest(manifestData)
		if err != nil {
			continue
		}

		extStorage, err := storage.NewStorage(dir.Path, mf.StorageQuota, mf.MaxPackageSize)
		if err != nil {
			continue
		}

		rt, err := runtime.NewRuntime(mf, m.httpClient, extStorage)
		if err != nil {
			continue
		}

		healthChecker := health.NewHTTPEndpointChecker(
			m.httpClient,
			mf.HealthURL(),
			mf.HealthMethod,
			m.config.HealthInterval,
			m.config.HealthTimeout,
			[]int{200, 201, 202, 204},
		)

		installed := &InstalledExtension{
			Manifest:    mf,
			Enabled:     true,
			InstalledAt: time.Now(),
			StoragePath: dir.Path,
			Runtime:     rt,
			Health:      healthChecker,
		}

		m.installed[mf.ID] = installed
		m.permManager.Register(mf.ID, mf.Permissions, mf.NetworkDomains)
		m.healthManager.Register(mf.ID, healthChecker)
		healthChecker.Start(ctx)
	}

	return nil
}

func (m *Manager) Install(ctx context.Context, opts installer.InstallOptions) (*InstalledExtension, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.initialized {
		return nil, ErrNotInitialized
	}

	result, err := m.installer.Install(ctx, opts)
	if err != nil {
		return nil, err
	}

	mf := result.Manifest

	if _, exists := m.installed[mf.ID]; exists && !opts.Force {
		return nil, fmt.Errorf("%w: %s", ErrExtensionExists, mf.ID)
	}

	extStorage, err := storage.NewStorage(result.ExtractedPath, mf.StorageQuota, mf.MaxPackageSize)
	if err != nil {
		return nil, fmt.Errorf("failed to create extension storage: %w", err)
	}

	rt, err := runtime.NewRuntime(mf, m.httpClient, extStorage)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRuntimeInitFailed, err)
	}

	healthChecker := health.NewHTTPEndpointChecker(
		m.httpClient,
		mf.HealthURL(),
		mf.HealthMethod,
		m.config.HealthInterval,
		m.config.HealthTimeout,
		[]int{200, 201, 202, 204},
	)

	installed := &InstalledExtension{
		Manifest:    mf,
		Enabled:     true,
		InstalledAt: result.InstalledAt,
		UpdatedAt:   result.InstalledAt,
		StoragePath: result.ExtractedPath,
		Runtime:     rt,
		Health:      healthChecker,
	}

	m.installed[mf.ID] = installed
	m.permManager.Register(mf.ID, mf.Permissions, mf.NetworkDomains)
	m.healthManager.Register(mf.ID, healthChecker)
	healthChecker.Start(ctx)

	return installed, nil
}

func (m *Manager) Uninstall(ctx context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	ext, exists := m.installed[id]
	if !exists {
		return ErrExtensionNotFound
	}

	if ext.Runtime != nil {
		ext.Runtime.Close()
	}

	if ext.Health != nil {
		ext.Health.Stop()
		m.healthManager.Unregister(id)
	}

	m.permManager.Unregister(id)
	delete(m.installed, id)

	return nil
}

func (m *Manager) Enable(ctx context.Context, id string, enabled bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	ext, exists := m.installed[id]
	if !exists {
		return ErrExtensionNotFound
	}

	ext.Enabled = enabled
	ext.UpdatedAt = time.Now()
	return nil
}

func (m *Manager) Get(id string) (*InstalledExtension, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	ext, ok := m.installed[id]
	return ext, ok
}

func (m *Manager) List() []*InstalledExtension {
	m.mu.RLock()
	defer m.mu.RUnlock()

	list := make([]*InstalledExtension, 0, len(m.installed))
	for _, ext := range m.installed {
		list = append(list, ext)
	}
	return list
}

func (m *Manager) ListEnabled() []*InstalledExtension {
	m.mu.RLock()
	defer m.mu.RUnlock()

	list := make([]*InstalledExtension, 0)
	for _, ext := range m.installed {
		if ext.Enabled {
			list = append(list, ext)
		}
	}
	return list
}

func (m *Manager) GetByKind(kind manifest.Kind) []*InstalledExtension {
	m.mu.RLock()
	defer m.mu.RUnlock()

	list := make([]*InstalledExtension, 0)
	for _, ext := range m.installed {
		if ext.Enabled && ext.Manifest.Kind == kind {
			list = append(list, ext)
		}
	}
	return list
}

func (m *Manager) GetByCapability(cap string) []*InstalledExtension {
	m.mu.RLock()
	defer m.mu.RUnlock()

	list := make([]*InstalledExtension, 0)
	for _, ext := range m.installed {
		if ext.Enabled && ext.Manifest.HasCapability(cap) {
			list = append(list, ext)
		}
	}
	return list
}

func (m *Manager) GetRuntime(id string) (*runtime.Runtime, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	ext, ok := m.installed[id]
	if !ok {
		return nil, ErrExtensionNotFound
	}
	if !ext.Enabled {
		return nil, ErrExtensionDisabled
	}
	return ext.Runtime, nil
}

func (m *Manager) CheckHealth(ctx context.Context, id string) (health.HealthCheckResult, bool) {
	return m.healthManager.Check(ctx, id)
}

func (m *Manager) CheckAllHealth(ctx context.Context) map[string]health.HealthCheckResult {
	return m.healthManager.CheckAll(ctx)
}

func (m *Manager) Update(ctx context.Context, id string) (*InstalledExtension, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	ext, exists := m.installed[id]
	if !exists {
		return nil, ErrExtensionNotFound
	}

	snapshots := m.repoManager.FetchAllRegistries(ctx)
	var entry *manifest.RegistryEntry
	for _, snap := range snapshots {
		if snap.Registry != nil {
			for _, e := range snap.Registry.Entries {
				if e.ID == id {
					entry = &e
					break
				}
			}
		}
		if entry != nil {
			break
		}
	}

	if entry == nil {
		return nil, fmt.Errorf("extension not found in repositories")
	}

	manifestData, err := m.fetchManifest(ctx, entry.URL)
	if err != nil {
		return nil, err
	}

	newManifest, err := manifest.ParseManifest(manifestData)
	if err != nil {
		return nil, err
	}

	if newManifest.Version == ext.Manifest.Version && newManifest.BaseURL == ext.Manifest.BaseURL {
		return ext, nil
	}

	if ext.Runtime != nil {
		ext.Runtime.Close()
	}

	extStorage, err := storage.NewStorage(ext.StoragePath, newManifest.StorageQuota, newManifest.MaxPackageSize)
	if err != nil {
		return nil, err
	}

	rt, err := runtime.NewRuntime(newManifest, m.httpClient, extStorage)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrRuntimeInitFailed, err)
	}

	healthChecker := health.NewHTTPEndpointChecker(
		m.httpClient,
		newManifest.HealthURL(),
		newManifest.HealthMethod,
		m.config.HealthInterval,
		m.config.HealthTimeout,
		[]int{200, 201, 202, 204},
	)

	ext.Manifest = newManifest
	ext.Runtime = rt
	ext.Health = healthChecker
	ext.UpdatedAt = time.Now()

	m.permManager.Register(newManifest.ID, newManifest.Permissions, newManifest.NetworkDomains)
	m.healthManager.Register(newManifest.ID, healthChecker)
	healthChecker.Start(ctx)

	return ext, nil
}

func (m *Manager) UpdateAll(ctx context.Context) ([]*InstalledExtension, error) {
	m.mu.RLock()
	ids := make([]string, 0, len(m.installed))
	for id := range m.installed {
		ids = append(ids, id)
	}
	m.mu.RUnlock()

	var updated []*InstalledExtension
	for _, id := range ids {
		ext, err := m.Update(ctx, id)
		if err != nil {
			continue
		}
		if ext != nil {
			updated = append(updated, ext)
		}
	}

	return updated, nil
}

func (m *Manager) fetchManifest(ctx context.Context, url string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := m.httpClient.Do(ctx, req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}

func (m *Manager) GetRepositories() []repository.Repository {
	return m.repoManager.List()
}

func (m *Manager) AddRepository(ctx context.Context, url string) error {
	return m.repoManager.Add(ctx, url)
}

func (m *Manager) RemoveRepository(ctx context.Context, url string) error {
	return m.repoManager.Remove(ctx, url)
}

func (m *Manager) FetchRegistry(ctx context.Context, url string) (*repository.RegistrySnapshot, error) {
	return m.repoManager.FetchRegistry(ctx, url)
}

func (m *Manager) SearchRegistries(ctx context.Context, query string) ([]manifest.RegistryEntry, error) {
	return m.repoManager.GetAllEntries(ctx)
}

func (m *Manager) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, ext := range m.installed {
		if ext.Runtime != nil {
			ext.Runtime.Close()
		}
		if ext.Health != nil {
			ext.Health.Stop()
		}
	}

	m.healthManager.StopAll()
	m.initialized = false
	return nil
}