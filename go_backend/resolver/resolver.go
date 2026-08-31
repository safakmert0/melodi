package resolver

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"melodi/go_backend/matching"
	"melodi/go_backend/provider"
)

var (
	ErrNoCandidates     = errors.New("resolver: no candidates found")
	ErrNoMatch          = errors.New("resolver: no suitable match")
	ErrNoQuality        = errors.New("resolver: requested quality not available")
	ErrAllProvidersFailed = errors.New("resolver: all providers failed")
)

type Quality string

const (
	QualityLow      Quality = "low"
	QualityMedium   Quality = "medium"
	QualityHigh     Quality = "high"
	QualityLossless Quality = "lossless"
	QualityHiRes    Quality = "hires"
	QualityAuto     Quality = "auto"
)

var qualityOrder = map[Quality]int{
	QualityLow:      0,
	QualityMedium:   1,
	QualityHigh:     2,
	QualityLossless: 3,
	QualityHiRes:    4,
}

type AudioSource struct {
	URL         string
	MimeType    string
	Bitrate     int
	Quality     Quality
	Provider    string
	TrackID     string
	Headers     map[string]string
	ExpiresAt   time.Time
	Checksum    string
	Size        int64
}

type ResolveRequest struct {
	TrackQuery  matching.TrackQuery
	Quality     Quality
	Providers   []string
	Exclude     []string
	RequireISRC bool
}

type ResolveResult struct {
	Source       AudioSource
	Match        *matching.MatchResult
	Candidates   []provider.SearchResult
	SelectedProvider string
	ResolvedAt   time.Time
}

type ResolverConfig struct {
	DefaultQuality     Quality
	MinQuality         Quality
	MaxQuality         Quality
	EnableFallback     bool
	FallbackQualities  []Quality
	Timeout            time.Duration
	MatcherConfig      matching.MatcherConfig
	QualityPreferences map[string][]Quality
}

func DefaultResolverConfig() ResolverConfig {
	return ResolverConfig{
		DefaultQuality: QualityAuto,
		MinQuality:     QualityLow,
		MaxQuality:     QualityHiRes,
		EnableFallback: true,
		FallbackQualities: []Quality{
			QualityLossless,
			QualityHiRes,
			QualityHigh,
			QualityMedium,
			QualityLow,
		},
		Timeout:       15 * time.Second,
		MatcherConfig: matching.DefaultMatcherConfig(),
		QualityPreferences: map[string][]Quality{
			"flac":    {QualityLossless, QualityHiRes, QualityHigh},
			"alac":    {QualityLossless, QualityHiRes, QualityHigh},
			"mp3":     {QualityHigh, QualityMedium, QualityLow},
			"aac":     {QualityHigh, QualityMedium, QualityLow},
			"opus":    {QualityHigh, QualityMedium, QualityLow},
			"ogg":     {QualityHigh, QualityMedium, QualityLow},
			"default": {QualityHigh, QualityMedium, QualityLow},
		},
	}
}

type Resolver struct {
	config   ResolverConfig
	provider provider.ProviderChain
	matcher  *matching.Matcher
	mu       sync.RWMutex
	stats    ResolverStats
}

type ResolverStats struct {
	TotalResolves     int64
	SuccessfulResolves int64
	FailedResolves    int64
	AvgLatency        time.Duration
}

func NewResolver(config ResolverConfig, provider provider.ProviderChain) *Resolver {
	if config.DefaultQuality == "" {
		config = DefaultResolverConfig()
	}
	return &Resolver{
		config:   config,
		provider: provider,
		matcher:  matching.NewMatcher(config.MatcherConfig),
	}
}

func (r *Resolver) Resolve(ctx context.Context, req ResolveRequest) (*ResolveResult, error) {
	start := time.Now()
	defer func() {
		r.mu.Lock()
		r.stats.TotalResolves++
		r.stats.AvgLatency = (r.stats.AvgLatency + time.Since(start)) / 2
		r.mu.Unlock()
	}()

	if req.Quality == QualityAuto {
		req.Quality = r.config.DefaultQuality
	}

	candidates, err := r.searchCandidates(ctx, req)
	if err != nil {
		r.mu.Lock()
		r.stats.FailedResolves++
		r.mu.Unlock()
		return nil, fmt.Errorf("search failed: %w", err)
	}

	if len(candidates) == 0 {
		r.mu.Lock()
		r.stats.FailedResolves++
		r.mu.Unlock()
		return nil, ErrNoCandidates
	}

	matchCandidates := r.convertToMatchCandidates(candidates)

	match, err := r.matcher.Match(req.TrackQuery, matchCandidates)
	if err != nil {
		r.mu.Lock()
		r.stats.FailedResolves++
		r.mu.Unlock()
		return nil, fmt.Errorf("matching failed: %w", err)
	}

	source, err := r.resolveSource(ctx, match, req.Quality)
	if err != nil {
		if r.config.EnableFallback {
			source, err = r.tryFallbackQualities(ctx, match, req.Quality)
		}
		if err != nil {
			r.mu.Lock()
			r.stats.FailedResolves++
			r.mu.Unlock()
			return nil, fmt.Errorf("source resolution failed: %w", err)
		}
	}

	r.mu.Lock()
	r.stats.SuccessfulResolves++
	r.mu.Unlock()

	return &ResolveResult{
		Source:            source,
		Match:             match,
		Candidates:        candidates,
		SelectedProvider:  source.Provider,
		ResolvedAt:        time.Now(),
	}, nil
}

func (r *Resolver) searchCandidates(ctx context.Context, req ResolveRequest) ([]provider.SearchResult, error) {
	query := fmt.Sprintf("%s %s", req.TrackQuery.Title, req.TrackQuery.Artist)
	query = strings.TrimSpace(query)

	searchQuery := provider.SearchQuery{
		Query:  query,
		Limit:  50,
		Offset: 0,
	}

	if len(req.Providers) > 0 {
		searchQuery.Filters = map[string]string{
			"providers": strings.Join(req.Providers, ","),
		}
	}

	ctxWithTimeout, cancel := context.WithTimeout(ctx, r.config.Timeout)
	defer cancel()

	results, err := r.provider.Search(ctxWithTimeout, searchQuery)
	if err != nil {
		return nil, err
	}

	if len(req.Exclude) > 0 {
		excludeSet := make(map[string]bool)
		for _, id := range req.Exclude {
			excludeSet[id] = true
		}
		filtered := make([]provider.SearchResult, 0, len(results))
		for _, r := range results {
			if !excludeSet[r.Source] {
				filtered = append(filtered, r)
			}
		}
		return filtered, nil
	}

	return results, nil
}

func (r *Resolver) convertToMatchCandidates(results []provider.SearchResult) []matching.TrackCandidate {
	candidates := make([]matching.TrackCandidate, 0, len(results))
	for _, r := range results {
		duration := r.Duration
		if duration == 0 {
			duration = -1
		}
		candidates = append(candidates, matching.TrackCandidate{
			ID:       r.ID,
			Title:    r.Title,
			Artist:   r.Artist,
			Album:    r.Album,
			Duration: duration,
			Source:   r.Source,
		})
	}
	return candidates
}

func (r *Resolver) resolveSource(ctx context.Context, match *matching.MatchResult, quality Quality) (AudioSource, error) {
	providers := r.provider.GetByCapability(provider.CapabilityStream)

	var lastErr error
	for _, p := range providers {
		if !p.IsAvailable() {
			continue
		}

		ctxWithTimeout, cancel := context.WithTimeout(ctx, r.config.Timeout)
		streamInfo, err := p.Stream(ctxWithTimeout, match.ID, string(quality))
		cancel()

		if err == nil && streamInfo != nil && streamInfo.URL != "" {
			return AudioSource{
				URL:       streamInfo.URL,
				MimeType:  streamInfo.MimeType,
				Bitrate:   streamInfo.Bitrate,
				Quality:   quality,
				Provider:  p.ID(),
				TrackID:   match.ID,
				Headers:   streamInfo.Headers,
				ExpiresAt: time.Unix(streamInfo.ExpiresAt, 0),
			}, nil
		}

		lastErr = err
	}

	return AudioSource{}, fmt.Errorf("%w: %v", ErrNoQuality, lastErr)
}

func (r *Resolver) tryFallbackQualities(ctx context.Context, match *matching.MatchResult, requested Quality) (AudioSource, error) {
	startIdx := -1
	for i, q := range r.config.FallbackQualities {
		if q == requested {
			startIdx = i + 1
			break
		}
	}

	if startIdx < 0 {
		startIdx = 0
	}

	for i := startIdx; i < len(r.config.FallbackQualities); i++ {
		quality := r.config.FallbackQualities[i]
		source, err := r.resolveSource(ctx, match, quality)
		if err == nil {
			return source, nil
		}
	}

	return AudioSource{}, ErrNoQuality
}

func (r *Resolver) ResolveDownload(ctx context.Context, req ResolveRequest) (*AudioSource, error) {
	req.Quality = r.config.MaxQuality

	candidates, err := r.searchCandidates(ctx, req)
	if err != nil {
		return nil, err
	}

	if len(candidates) == 0 {
		return nil, ErrNoCandidates
	}

	matchCandidates := r.convertToMatchCandidates(candidates)
	match, err := r.matcher.Match(req.TrackQuery, matchCandidates)
	if err != nil {
		return nil, err
	}

	providers := r.provider.GetByCapability(provider.CapabilityDownload)

	for _, p := range providers {
		if !p.IsAvailable() {
			continue
		}

		ctxWithTimeout, cancel := context.WithTimeout(ctx, r.config.Timeout)
		downloadInfo, err := p.Download(ctxWithTimeout, match.ID, string(req.Quality))
		cancel()

		if err == nil && downloadInfo != nil && downloadInfo.URL != "" {
			return &AudioSource{
				URL:       downloadInfo.URL,
				MimeType:  downloadInfo.MimeType,
				Bitrate:   0,
				Quality:   req.Quality,
				Provider:  p.ID(),
				TrackID:   match.ID,
				Headers:   downloadInfo.Headers,
				Size:      downloadInfo.Size,
				Checksum:  downloadInfo.Checksum,
			}, nil
		}
	}

	return nil, ErrNoQuality
}

func (r *Resolver) GetAvailableQualities(ctx context.Context, trackID string, providerIDs []string) (map[string][]Quality, error) {
	result := make(map[string][]Quality)

	providers := r.provider.GetByCapability(provider.CapabilityStream)
	for _, p := range providers {
		if len(providerIDs) > 0 {
			found := false
			for _, id := range providerIDs {
				if p.ID() == id {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}

		if !p.IsAvailable() {
			continue
		}

		qualities := []Quality{
			QualityLow, QualityMedium, QualityHigh, QualityLossless, QualityHiRes,
		}

		var available []Quality
		for _, q := range qualities {
			ctxWithTimeout, cancel := context.WithTimeout(ctx, 5*time.Second)
			info, err := p.Stream(ctxWithTimeout, trackID, string(q))
			cancel()
			if err == nil && info != nil && info.URL != "" {
				available = append(available, q)
			}
		}

		if len(available) > 0 {
			result[p.ID()] = available
		}
	}

	return result, nil
}

func (r *Resolver) CompareQualities(ctx context.Context, trackID string, providers []string) (map[string]map[Quality]*AudioSource, error) {
	result := make(map[string]map[Quality]*AudioSource)

	providerList := r.provider.GetByCapability(provider.CapabilityStream)
	for _, p := range providerList {
		if len(providers) > 0 {
			found := false
			for _, id := range providers {
				if p.ID() == id {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}

		if !p.IsAvailable() {
			continue
		}

		qualityMap := make(map[Quality]*AudioSource)
		for _, q := range []Quality{QualityLow, QualityMedium, QualityHigh, QualityLossless, QualityHiRes} {
			ctxWithTimeout, cancel := context.WithTimeout(ctx, 5*time.Second)
			info, err := p.Stream(ctxWithTimeout, trackID, string(q))
			cancel()
			if err == nil && info != nil && info.URL != "" {
				qualityMap[q] = &AudioSource{
					URL:       info.URL,
					MimeType:  info.MimeType,
					Bitrate:   info.Bitrate,
					Quality:   q,
					Provider:  p.ID(),
					TrackID:   trackID,
					Headers:   info.Headers,
					ExpiresAt: time.Unix(info.ExpiresAt, 0),
				}
			}
		}

		if len(qualityMap) > 0 {
			result[p.ID()] = qualityMap
		}
	}

	return result, nil
}

func (r *Resolver) SelectBestQuality(sources map[string]map[Quality]*AudioSource, preferredQuality Quality) *AudioSource {
	if preferredQuality != QualityAuto {
		for _, providerSources := range sources {
			if src, ok := providerSources[preferredQuality]; ok {
				return src
			}
		}
	}

	qualities := r.config.FallbackQualities
	for _, q := range qualities {
		for _, providerSources := range sources {
			if src, ok := providerSources[q]; ok {
				return src
			}
		}
	}

	for _, providerSources := range sources {
		var keys []Quality
		for k := range providerSources {
			keys = append(keys, k)
		}
		sort.Slice(keys, func(i, j int) bool {
			return qualityOrder[keys[i]] > qualityOrder[keys[j]]
		})
		if len(keys) > 0 {
			return providerSources[keys[0]]
		}
	}

	return nil
}

func (r *Resolver) GetStats() ResolverStats {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.stats
}

func (r *Resolver) ResetStats() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.stats = ResolverStats{}
}