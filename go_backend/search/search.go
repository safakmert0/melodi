package search

import (
	"context"
	"errors"
	"sort"
	"strings"
	"sync"
	"time"

	"melodi/go_backend/matching"
	"melodi/go_backend/provider"
)

var (
	ErrNoResults      = errors.New("search: no results")
	ErrAllSourcesFailed = errors.New("search: all sources failed")
	ErrTimeout        = errors.New("search: timeout")
)

type SearchQuery struct {
	Query       string
	Limit       int
	Offset      int
	Filters     map[string]string
	Sources     []string
	ExcludeSources []string
}

type SearchResult struct {
	provider.SearchResult
	MatchedScore float64
	MatchDetails *matching.MatchResult
}

type SourceResult struct {
	Source   string
	Results  []provider.SearchResult
	Error    error
	Duration time.Duration
}

type EngineConfig struct {
	DefaultLimit       int
	MaxLimit           int
	Timeout            time.Duration
	EnableDeduplication bool
	EnableRanking      bool
	MinScore           float64
}

func DefaultEngineConfig() EngineConfig {
	return EngineConfig{
		DefaultLimit:        20,
		MaxLimit:            100,
		Timeout:             10 * time.Second,
		EnableDeduplication: true,
		EnableRanking:       true,
		MinScore:            0.3,
	}
}

type Engine struct {
	config      EngineConfig
	provider    *provider.ProviderChain
	matcher     *matching.Matcher
	mu          sync.RWMutex
	stats       EngineStats
}

type EngineStats struct {
	TotalQueries    int64
	SuccessfulQueries int64
	FailedQueries   int64
	TotalLatency    time.Duration
}

func NewEngine(config EngineConfig, provider *provider.ProviderChain, matcher *matching.Matcher) *Engine {
	if config.DefaultLimit == 0 {
		config = DefaultEngineConfig()
	}
	return &Engine{
		config:   config,
		provider: provider,
		matcher:  matcher,
	}
}

func (e *Engine) Search(ctx context.Context, query SearchQuery) ([]SearchResult, error) {
	start := time.Now()
	defer func() {
		e.mu.Lock()
		e.stats.TotalQueries++
		e.stats.TotalLatency += time.Since(start)
		e.mu.Unlock()
	}()

	if query.Query == "" {
		return nil, errors.New("empty query")
	}

	limit := query.Limit
	if limit <= 0 {
		limit = e.config.DefaultLimit
	}
	if limit > e.config.MaxLimit {
		limit = e.config.MaxLimit
	}

	providerQuery := provider.SearchQuery{
		Query:   query.Query,
		Limit:   limit,
		Offset:  query.Offset,
		Filters: query.Filters,
	}

	ctxWithTimeout, cancel := context.WithTimeout(ctx, e.config.Timeout)
	defer cancel()

	sourceResults := e.searchSources(ctxWithTimeout, providerQuery, query.Sources, query.ExcludeSources)

	allResults := e.aggregateResults(sourceResults)

	if e.config.EnableDeduplication {
		allResults = e.deduplicate(allResults)
	}

	if e.config.EnableRanking && e.matcher != nil {
		allResults = e.rankResults(allResults, query.Query)
	}

	if len(allResults) > limit {
		allResults = allResults[:limit]
	}

	e.mu.Lock()
	if len(allResults) > 0 {
		e.stats.SuccessfulQueries++
	} else {
		e.stats.FailedQueries++
	}
	e.mu.Unlock()

	if len(allResults) == 0 {
		return nil, ErrNoResults
	}

	return allResults, nil
}

func (e *Engine) searchSources(ctx context.Context, query provider.SearchQuery, include, exclude []string) []SourceResult {
	var providers []provider.Provider

	if len(include) > 0 {
		for _, id := range include {
			if prov := e.provider.GetProvider(id); prov != nil {
				providers = append(providers, prov)
			}
		}
	} else {
		providers = e.provider.GetByCapability(provider.CapabilitySearch)
	}

	excludeSet := make(map[string]bool)
	for _, id := range exclude {
		excludeSet[id] = true
	}

	var filtered []provider.Provider
	for _, p := range providers {
		if !excludeSet[p.ID()] {
			filtered = append(filtered, p)
		}
	}

	results := make([]SourceResult, len(filtered))
	var wg sync.WaitGroup

	for i, p := range filtered {
		wg.Add(1)
		go func(idx int, prov provider.Provider) {
			defer wg.Done()
			start := time.Now()
			res, err := prov.Search(ctx, query)
			results[idx] = SourceResult{
				Source:   prov.ID(),
				Results:  res,
				Error:    err,
				Duration: time.Since(start),
			}
		}(i, p)
	}

	wg.Wait()
	return results
}

func (e *Engine) aggregateResults(sourceResults []SourceResult) []SearchResult {
	var allResults []SearchResult

	for _, src := range sourceResults {
		if src.Error != nil {
			continue
		}
		for _, r := range src.Results {
			r.Source = src.Source
			allResults = append(allResults, SearchResult{
				SearchResult: r,
			})
		}
	}

	return allResults
}

func (e *Engine) deduplicate(results []SearchResult) []SearchResult {
	seen := make(map[string]bool)
	var unique []SearchResult

	for _, r := range results {
		key := e.dedupKey(r)
		if !seen[key] {
			seen[key] = true
			unique = append(unique, r)
		}
	}

	return unique
}

func (e *Engine) dedupKey(r SearchResult) string {
	title := strings.ToLower(strings.TrimSpace(r.Title))
	artist := strings.ToLower(strings.TrimSpace(r.Artist))
	album := strings.ToLower(strings.TrimSpace(r.Album))

	parts := []string{title, artist}
	if album != "" {
		parts = append(parts, album)
	}
	return strings.Join(parts, "|")
}

func (e *Engine) rankResults(results []SearchResult, query string) []SearchResult {
	if e.matcher == nil {
		return results
	}

	queryLower := strings.ToLower(query)

	for i := range results {
		titleScore := e.matcher.Similarity(queryLower, strings.ToLower(results[i].Title))
		artistScore := e.matcher.Similarity(queryLower, strings.ToLower(results[i].Artist))

		results[i].MatchedScore = (titleScore * 0.6) + (artistScore * 0.4)
	}

	sort.Slice(results, func(i, j int) bool {
		if results[i].MatchedScore != results[j].MatchedScore {
			return results[i].MatchedScore > results[j].MatchedScore
		}
		return results[i].Title < results[j].Title
	})

	return results
}

func (e *Engine) SearchWithContext(ctx context.Context, query string, limit int) ([]SearchResult, error) {
	return e.Search(ctx, SearchQuery{
		Query: query,
		Limit: limit,
	})
}

func (e *Engine) GetStats() EngineStats {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.stats
}

func (e *Engine) ResetStats() {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.stats = EngineStats{}
}

type MultiEngine struct {
	engines map[string]*Engine
	mu      sync.RWMutex
}

func NewMultiEngine() *MultiEngine {
	return &MultiEngine{
		engines: make(map[string]*Engine),
	}
}

func (m *MultiEngine) Register(name string, engine *Engine) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.engines[name] = engine
}

func (m *MultiEngine) Get(name string) (*Engine, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	e, ok := m.engines[name]
	return e, ok
}

func (m *MultiEngine) SearchAll(ctx context.Context, query SearchQuery) (map[string][]SearchResult, error) {
	m.mu.RLock()
	engines := make(map[string]*Engine, len(m.engines))
	for k, v := range m.engines {
		engines[k] = v
	}
	m.mu.RUnlock()

	results := make(map[string][]SearchResult)
	var mu sync.Mutex
	var wg sync.WaitGroup

	for name, engine := range engines {
		wg.Add(1)
		go func(n string, e *Engine) {
			defer wg.Done()
			res, err := e.Search(ctx, query)
			mu.Lock()
			if err == nil {
				results[n] = res
			}
			mu.Unlock()
		}(name, engine)
	}

	wg.Wait()
	return results, nil
}