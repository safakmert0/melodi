package provider

import (
	"context"
	"errors"
	"sync"
	"time"
)

var (
	ErrProviderNotFound    = errors.New("provider: not found")
	ErrProviderUnavailable = errors.New("provider: unavailable")
	ErrNoProviders         = errors.New("provider: no providers available")
	ErrAllFailed           = errors.New("provider: all providers failed")
)

type Capability string

const (
	CapabilitySearch      Capability = "search"
	CapabilityMetadata    Capability = "metadata"
	CapabilityStream      Capability = "stream"
	CapabilityDownload    Capability = "download"
	CapabilityLyrics      Capability = "lyrics"
	CapabilityHealth      Capability = "health"
)

type ProviderType string

const (
	TypeBackend  ProviderType = "backend"
	TypeHifi     ProviderType = "hifi"
	TypeMetadata ProviderType = "metadata"
	TypeLyrics   ProviderType = "lyrics"
	TypeStream   ProviderType = "stream"
	TypeDownload ProviderType = "download"
)

type SearchQuery struct {
	Query       string
	Limit       int
	Offset      int
	Filters     map[string]string
}

type SearchResult struct {
	ID          string            `json:"id"`
	Title       string            `json:"title"`
	Artist      string            `json:"artist"`
	Album       string            `json:"album,omitempty"`
	Duration    int64             `json:"durationMs,omitempty"`
	Source      string            `json:"source"`
	Thumbnail   string            `json:"thumbnail,omitempty"`
	Quality     string            `json:"quality,omitempty"`
	Extras      map[string]string `json:"extras,omitempty"`
	Score       float64           `json:"score,omitempty"`
}

type TrackMetadata struct {
	ID          string            `json:"id"`
	Title       string            `json:"title"`
	Artist      string            `json:"artist"`
	Album       string            `json:"album,omitempty"`
	Duration    int64             `json:"durationMs,omitempty"`
	ISRC        string            `json:"isrc,omitempty"`
	TrackNumber int               `json:"trackNumber,omitempty"`
	DiscNumber  int               `json:"discNumber,omitempty"`
	Year        int               `json:"year,omitempty"`
	Genre       string            `json:"genre,omitempty"`
	CoverURL    string            `json:"coverUrl,omitempty"`
	Extras      map[string]string `json:"extras,omitempty"`
}

type StreamInfo struct {
	URL       string            `json:"url"`
	MimeType  string            `json:"mimeType"`
	Bitrate   int               `json:"bitrate,omitempty"`
	Quality   string            `json:"quality,omitempty"`
	Headers   map[string]string `json:"headers,omitempty"`
	ExpiresAt int64             `json:"expiresAt,omitempty"`
}

type DownloadInfo struct {
	URL       string            `json:"url"`
	MimeType  string            `json:"mimeType"`
	Size      int64             `json:"size,omitempty"`
	Filename  string            `json:"filename,omitempty"`
	Headers   map[string]string `json:"headers,omitempty"`
	Checksum  string            `json:"checksum,omitempty"`
}

type LyricsResult struct {
	SyncedLRC string `json:"syncedLrc,omitempty"`
	PlainText string `json:"plainText,omitempty"`
	Language  string `json:"language,omitempty"`
	Source    string `json:"source,omitempty"`
}

type HealthStatus string

const (
	HealthHealthy   HealthStatus = "healthy"
	HealthUnhealthy HealthStatus = "unhealthy"
	HealthUnknown   HealthStatus = "unknown"
)

type HealthResult struct {
	Status    HealthStatus
	Latency   time.Duration
	CheckedAt time.Time
	Error     string
	Details   map[string]string
}

type Provider interface {
	ID() string
	Name() string
	Type() ProviderType
	Capabilities() []Capability
	Priority() int

	Search(ctx context.Context, query SearchQuery) ([]SearchResult, error)
	Metadata(ctx context.Context, id string) (*TrackMetadata, error)
	Stream(ctx context.Context, id string, quality string) (*StreamInfo, error)
	Download(ctx context.Context, id string, quality string) (*DownloadInfo, error)
	Lyrics(ctx context.Context, id string) (*LyricsResult, error)
	Health(ctx context.Context) HealthResult

	IsAvailable() bool
	SetAvailable(bool)
}

type BaseProvider struct {
	id           string
	name         string
	pType        ProviderType
	capabilities []Capability
	priority     int
	available    bool
	mu           sync.RWMutex
}

func NewBaseProvider(id, name string, pType ProviderType, capabilities []Capability, priority int) *BaseProvider {
	return &BaseProvider{
		id:           id,
		name:         name,
		pType:        pType,
		capabilities: capabilities,
		priority:     priority,
		available:    true,
	}
}

func (b *BaseProvider) ID() string           { return b.id }
func (b *BaseProvider) Name() string         { return b.name }
func (b *BaseProvider) Type() ProviderType   { return b.pType }
func (b *BaseProvider) Capabilities() []Capability { return b.capabilities }
func (b *BaseProvider) Priority() int        { return b.priority }

func (b *BaseProvider) IsAvailable() bool {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.available
}

func (b *BaseProvider) SetAvailable(available bool) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.available = available
}

func (b *BaseProvider) HasCapability(cap Capability) bool {
	for _, c := range b.capabilities {
		if c == cap {
			return true
		}
	}
	return false
}

func (b *BaseProvider) Search(ctx context.Context, query SearchQuery) ([]SearchResult, error) {
	return nil, errors.New("not implemented")
}

func (b *BaseProvider) Metadata(ctx context.Context, id string) (*TrackMetadata, error) {
	return nil, errors.New("not implemented")
}

func (b *BaseProvider) Stream(ctx context.Context, id string, quality string) (*StreamInfo, error) {
	return nil, errors.New("not implemented")
}

func (b *BaseProvider) Download(ctx context.Context, id string, quality string) (*DownloadInfo, error) {
	return nil, errors.New("not implemented")
}

func (b *BaseProvider) Lyrics(ctx context.Context, id string) (*LyricsResult, error) {
	return nil, errors.New("not implemented")
}

func (b *BaseProvider) Health(ctx context.Context) HealthResult {
	return HealthResult{
		Status:    HealthUnknown,
		CheckedAt: time.Now(),
	}
}

type Registry struct {
	mu           sync.RWMutex
	providers    map[string]Provider
	byType       map[ProviderType][]Provider
	byCapability map[Capability][]Provider
}

func NewRegistry() *Registry {
	return &Registry{
		providers:    make(map[string]Provider),
		byType:       make(map[ProviderType][]Provider),
		byCapability: make(map[Capability][]Provider),
	}
}

func (r *Registry) Register(provider Provider) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.providers[provider.ID()]; exists {
		return errors.New("provider already registered: " + provider.ID())
	}

	r.providers[provider.ID()] = provider

	r.byType[provider.Type()] = append(r.byType[provider.Type()], provider)
	for _, cap := range provider.Capabilities() {
		r.byCapability[cap] = append(r.byCapability[cap], provider)
	}

	r.sortByPriority()
	return nil
}

func (r *Registry) Unregister(id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	provider, exists := r.providers[id]
	if !exists {
		return ErrProviderNotFound
	}

	delete(r.providers, id)

	r.rebuildIndexes()
	return nil
}

func (r *Registry) Get(id string) (Provider, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	p, ok := r.providers[id]
	return p, ok
}

func (r *Registry) GetByType(pType ProviderType) []Provider {
	r.mu.RLock()
	defer r.mu.RUnlock()

	providers := r.byType[pType]
	result := make([]Provider, len(providers))
	copy(result, providers)
	return result
}

func (r *Registry) GetByCapability(cap Capability) []Provider {
	r.mu.RLock()
	defer r.mu.RUnlock()

	providers := r.byCapability[cap]
	result := make([]Provider, len(providers))
	copy(result, providers)
	return result
}

func (r *Registry) GetAll() []Provider {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]Provider, 0, len(r.providers))
	for _, p := range r.providers {
		result = append(result, p)
	}
	return result
}

func (r *Registry) GetAvailableByCapability(cap Capability) []Provider {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []Provider
	for _, p := range r.byCapability[cap] {
		if p.IsAvailable() {
			result = append(result, p)
		}
	}
	return result
}

func (r *Registry) sortByPriority() {
	for _, list := range r.byType {
		sortProviders(list)
	}
	for _, list := range r.byCapability {
		sortProviders(list)
	}
}

func (r *Registry) rebuildIndexes() {
	r.byType = make(map[ProviderType][]Provider)
	r.byCapability = make(map[Capability][]Provider)

	for _, p := range r.providers {
		r.byType[p.Type()] = append(r.byType[p.Type()], p)
		for _, cap := range p.Capabilities() {
			r.byCapability[cap] = append(r.byCapability[cap], p)
		}
	}
	r.sortByPriority()
}

func (r *Registry) Count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.providers)
}

func sortProviders(providers []Provider) {
	for i := 0; i < len(providers)-1; i++ {
		for j := i + 1; j < len(providers); j++ {
			if providers[i].Priority() < providers[j].Priority() {
				providers[i], providers[j] = providers[j], providers[i]
			}
		}
	}
}

type FallbackStrategy int

const (
	FallbackSequential FallbackStrategy = iota
	FallbackParallel
	FallbackRace
)

type FallbackConfig struct {
	Strategy       FallbackStrategy
	Timeout        time.Duration
	MaxRetries     int
	RetryDelay     time.Duration
	FallbackOnError bool
}

func DefaultFallbackConfig() FallbackConfig {
	return FallbackConfig{
		Strategy:        FallbackSequential,
		Timeout:         10 * time.Second,
		MaxRetries:      2,
		RetryDelay:      500 * time.Millisecond,
		FallbackOnError: true,
	}
}

type ProviderChain struct {
	registry *Registry
	config   FallbackConfig
}

func NewProviderChain(registry *Registry, config FallbackConfig) *ProviderChain {
	return &ProviderChain{
		registry: registry,
		config:   config,
	}
}

func (c *ProviderChain) Search(ctx context.Context, query SearchQuery) ([]SearchResult, error) {
	providers := c.registry.GetAvailableByCapability(CapabilitySearch)
	if len(providers) == 0 {
		return nil, ErrNoProviders
	}

	return c.executeWithFallback(ctx, providers, func(ctx context.Context, p Provider) ([]SearchResult, error) {
		return p.Search(ctx, query)
	})
}

func (c *ProviderChain) Metadata(ctx context.Context, id string) (*TrackMetadata, error) {
	providers := c.registry.GetAvailableByCapability(CapabilityMetadata)
	if len(providers) == 0 {
		return nil, ErrNoProviders
	}

	return c.executeSingleWithFallback(ctx, providers, func(ctx context.Context, p Provider) (*TrackMetadata, error) {
		return p.Metadata(ctx, id)
	})
}

func (c *ProviderChain) Stream(ctx context.Context, id string, quality string) (*StreamInfo, error) {
	providers := c.registry.GetAvailableByCapability(CapabilityStream)
	if len(providers) == 0 {
		return nil, ErrNoProviders
	}

	return c.executeSingleWithFallback(ctx, providers, func(ctx context.Context, p Provider) (*StreamInfo, error) {
		return p.Stream(ctx, id, quality)
	})
}

func (c *ProviderChain) Download(ctx context.Context, id string, quality string) (*DownloadInfo, error) {
	providers := c.registry.GetAvailableByCapability(CapabilityDownload)
	if len(providers) == 0 {
		return nil, ErrNoProviders
	}

	return c.executeSingleWithFallback(ctx, providers, func(ctx context.Context, p Provider) (*DownloadInfo, error) {
		return p.Download(ctx, id, quality)
	})
}

func (c *ProviderChain) Lyrics(ctx context.Context, id string) (*LyricsResult, error) {
	providers := c.registry.GetAvailableByCapability(CapabilityLyrics)
	if len(providers) == 0 {
		return nil, ErrNoProviders
	}

	return c.executeSingleWithFallback(ctx, providers, func(ctx context.Context, p Provider) (*LyricsResult, error) {
		return p.Lyrics(ctx, id)
	})
}

func (c *ProviderChain) Health(ctx context.Context) map[string]HealthResult {
	providers := c.registry.GetAll()
	results := make(map[string]HealthResult)

	for _, p := range providers {
		results[p.ID()] = p.Health(ctx)
	}

	return results
}

func (c *ProviderChain) executeWithFallback(ctx context.Context, providers []Provider, fn func(context.Context, Provider) ([]SearchResult, error)) ([]SearchResult, error) {
	var lastErr error
	var allResults []SearchResult

	for _, p := range providers {
		ctxWithTimeout, cancel := context.WithTimeout(ctx, c.config.Timeout)

		results, err := fn(ctxWithTimeout, p)
		cancel()

		if err == nil && len(results) > 0 {
			for _, r := range results {
				r.Source = p.ID()
			}
			allResults = append(allResults, results...)
			if c.config.Strategy != FallbackParallel {
				return allResults, nil
			}
		} else if err != nil {
			lastErr = err
			if !c.config.FallbackOnError {
				return nil, err
			}
		}

		if c.config.Strategy == FallbackSequential {
			select {
			case <-ctx.Done():
				return allResults, ctx.Err()
			case <-time.After(c.config.RetryDelay):
			}
		}
	}

	if len(allResults) > 0 {
		return allResults, nil
	}

	return nil, lastErr
}

func (c *ProviderChain) executeSingleWithFallback(ctx context.Context, providers []Provider, fn func(context.Context, Provider) (interface{}, error)) (interface{}, error) {
	var lastErr error

	for _, p := range providers {
		ctxWithTimeout, cancel := context.WithTimeout(ctx, c.config.Timeout)

		result, err := fn(ctxWithTimeout, p)
		cancel()

		if err == nil && result != nil {
			return result, nil
		}

		if err != nil {
			lastErr = err
			if !c.config.FallbackOnError {
				return nil, err
			}
		}

		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(c.config.RetryDelay):
		}
	}

	return nil, lastErr
}