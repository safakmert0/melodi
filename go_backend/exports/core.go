package exports

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"melodi/go_backend/download/manager"
	"melodi/go_backend/extension/manager"
	"melodi/go_backend/filesystem"
	"melodi/go_backend/matching"
	"melodi/go_backend/metadata"
	"melodi/go_backend/network"
	"melodi/go_backend/provider"
	"melodi/go_backend/resolver"
	"melodi/go_backend/search"
)

var (
	ErrNotInitialized = errors.New("exports: core not initialized")
	ErrInvalidInput   = errors.New("exports: invalid input")
)

type Core struct {
	extManager      *manager.Manager
	downloadManager *manager.DownloadManager
	searchEngine    *search.Engine
	matcher         *matching.Matcher
	resolver        *resolver.Resolver
	metadataService *metadata.Service
	httpClient      *network.HTTPClient
	providerChain   *provider.ProviderChain
	fs              filesystem.Filesystem

	config CoreConfig

	initialized bool
	version     string
	apiVersion  string
	startTime   time.Time
}

type CoreConfig struct {
	StorageRoot            string
	ExtensionStorageQuota  int64
	ExtensionMaxFileSize   int64
	DownloadStorageRoot    string
	MaxConcurrentDownloads int
	CurrentAppVersion      string
	APIVersion             string
}

func DefaultCoreConfig() CoreConfig {
	return CoreConfig{
		StorageRoot:            "",
		ExtensionStorageQuota:  100 * 1024 * 1024,
		ExtensionMaxFileSize:   10 * 1024 * 1024,
		DownloadStorageRoot:    "",
		MaxConcurrentDownloads: 3,
		CurrentAppVersion:      "1.0.0",
		APIVersion:             "1",
	}
}

func NewCore(config CoreConfig) (*Core, error) {
	if config.StorageRoot == "" {
		return nil, fmt.Errorf("storage root is required")
	}
	if config.DownloadStorageRoot == "" {
		config.DownloadStorageRoot = config.StorageRoot
	}

	c := &Core{
		config:     config,
		version:    config.CurrentAppVersion,
		apiVersion: config.APIVersion,
		startTime:  time.Now(),
	}

	return c, nil
}

func (c *Core) Initialize(ctx context.Context) error {
	if c.initialized {
		return nil
	}

	// Initialize HTTP client
	c.httpClient = network.NewHTTPClient(network.DefaultClientConfig())

	// Initialize filesystem
	fs, err := filesystem.NewFilesystem(c.config.StorageRoot, 0)
	if err != nil {
		return fmt.Errorf("failed to create filesystem: %w", err)
	}
	c.fs = fs

	// Initialize extension manager
	extConfig := manager.DefaultManagerConfig()
	extConfig.StorageRoot = c.config.StorageRoot
	extConfig.StorageQuota = c.config.ExtensionStorageQuota
	extConfig.MaxFileSize = c.config.ExtensionMaxFileSize
	extConfig.CurrentAppVersion = c.config.CurrentAppVersion
	extConfig.APIVersion = c.config.APIVersion

	extManager, err := manager.NewManager(c.httpClient, extConfig)
	if err != nil {
		return fmt.Errorf("failed to create extension manager: %w", err)
	}
	c.extManager = extManager

	if err := c.extManager.Initialize(ctx); err != nil {
		return fmt.Errorf("failed to initialize extension manager: %w", err)
	}

	// Initialize provider registry and chain
	registry := provider.NewRegistry()
	c.providerChain = provider.NewProviderChain(registry, provider.DefaultFallbackConfig())

	// Initialize matcher
	c.matcher = matching.NewMatcher(matching.DefaultMatcherConfig())

	// Initialize search engine
	searchConfig := search.DefaultEngineConfig()
	c.searchEngine = search.NewEngine(searchConfig, c.providerChain, c.matcher)

	// Initialize resolver
	resolverConfig := resolver.DefaultResolverConfig()
	c.resolver = resolver.NewResolver(resolverConfig, c.providerChain)

	// Initialize download manager
	dlConfig := manager.DefaultDownloadManagerConfig()
	dlConfig.StorageRoot = c.config.DownloadStorageRoot
	dlConfig.DownloaderConfig.MaxConcurrentDownloads = c.config.MaxConcurrentDownloads

	dlManager, err := manager.NewDownloadManager(dlConfig, c.fs)
	if err != nil {
		return fmt.Errorf("failed to create download manager: %w", err)
	}
	c.downloadManager = dlManager

	// Initialize metadata service
	c.metadataService = metadata.NewService()
	c.metadataService.RegisterDefaults()

	c.initialized = true
	return nil
}

func (c *Core) Ping() string {
	return "pong"
}

func (c *Core) Version() string {
	return c.version
}

func (c *Core) APIVersion() string {
	return c.apiVersion
}

func (c *Core) Uptime() time.Duration {
	return time.Since(c.startTime)
}

func (c *Core) IsInitialized() bool {
	return c.initialized
}

type SearchRequest struct {
	Query          string   `json:"query"`
	Limit          int      `json:"limit,omitempty"`
	Offset         int      `json:"offset,omitempty"`
	Sources        []string `json:"sources,omitempty"`
	ExcludeSources []string `json:"exclude_sources,omitempty"`
}

type SearchResponse struct {
	Results []SearchResult `json:"results"`
	Total   int            `json:"total"`
	Took    int64          `json:"took_ms"`
}

type SearchResult struct {
	ID          string            `json:"id"`
	Title       string            `json:"title"`
	Artist      string            `json:"artist"`
	Album       string            `json:"album,omitempty"`
	DurationMs  int64             `json:"duration_ms,omitempty"`
	Source      string            `json:"source"`
	Thumbnail   string            `json:"thumbnail,omitempty"`
	Quality     string            `json:"quality,omitempty"`
	Score       float64           `json:"score,omitempty"`
	Extras      map[string]string `json:"extras,omitempty"`
}

func (c *Core) Search(ctx context.Context, req SearchRequest) (*SearchResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}
	if req.Query == "" {
		return nil, ErrInvalidInput
	}

	start := time.Now()

	searchReq := search.SearchQuery{
		Query:       req.Query,
		Limit:       req.Limit,
		Offset:      req.Offset,
		Sources:     req.Sources,
		ExcludeSources: req.ExcludeSources,
	}

	results, err := c.searchEngine.Search(ctx, searchReq)
	if err != nil {
		return nil, err
	}

	searchResults := make([]SearchResult, len(results))
	for i, r := range results {
		searchResults[i] = SearchResult{
			ID:         r.ID,
			Title:      r.Title,
			Artist:     r.Artist,
			Album:      r.Album,
			DurationMs: r.Duration,
			Source:     r.Source,
			Thumbnail:  r.Thumbnail,
			Quality:    r.Quality,
			Score:      r.MatchedScore,
			Extras:     r.Extras,
		}
	}

	return &SearchResponse{
		Results: searchResults,
		Total:   len(searchResults),
		Took:    time.Since(start).Milliseconds(),
	}, nil
}

type MatchRequest struct {
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	Album    string `json:"album,omitempty"`
	Duration int64  `json:"duration_ms,omitempty"`
	ISRC     string `json:"isrc,omitempty"`
}

type MatchResponse struct {
	Match      *MatchResult   `json:"match,omitempty"`
	Candidates []MatchCandidate `json:"candidates,omitempty"`
}

type MatchResult struct {
	ID             string        `json:"id"`
	Title          string        `json:"title"`
	Artist         string        `json:"artist"`
	Album          string        `json:"album,omitempty"`
	DurationMs     int64         `json:"duration_ms,omitempty"`
	ISRC           string        `json:"isrc,omitempty"`
	Confidence     float64       `json:"confidence"`
	ScoreBreakdown ScoreBreakdown `json:"score_breakdown"`
	MatchReasons   []string      `json:"match_reasons"`
}

type ScoreBreakdown struct {
	TitleScore     float64 `json:"title_score"`
	ArtistScore    float64 `json:"artist_score"`
	AlbumScore     float64 `json:"album_score"`
	DurationScore  float64 `json:"duration_score"`
	ISRCScore      float64 `json:"isrc_score"`
	TotalScore     float64 `json:"total_score"`
}

type MatchCandidate struct {
	ID       string  `json:"id"`
	Title    string  `json:"title"`
	Artist   string  `json:"artist"`
	Album    string  `json:"album,omitempty"`
	Duration int64   `json:"duration_ms,omitempty"`
	Source   string  `json:"source"`
	Score    float64 `json:"score"`
}

func (c *Core) Match(ctx context.Context, req MatchRequest) (*MatchResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	query := matching.TrackQuery{
		Title:    req.Title,
		Artist:   req.Artist,
		Album:    req.Album,
		Duration: req.Duration,
		ISRC:     req.ISRC,
	}

	// Get candidates from search
	searchReq := search.SearchQuery{
		Query: fmt.Sprintf("%s %s", req.Title, req.Artist),
		Limit: 50,
	}
	searchResults, err := c.searchEngine.Search(ctx, searchReq)
	if err != nil {
		return nil, err
	}

	candidates := make([]matching.TrackCandidate, len(searchResults))
	for i, r := range searchResults {
		candidates[i] = matching.TrackCandidate{
			ID:       r.ID,
			Title:    r.Title,
			Artist:   r.Artist,
			Album:    r.Album,
			Duration: r.Duration,
			Source:   r.Source,
		}
	}

	match, err := c.matcher.Match(query, candidates)
	if err != nil {
		return &MatchResponse{}, nil // No match found
	}

	matchCandidates := make([]MatchCandidate, len(candidates))
	for i, cand := range candidates {
		matchCandidates[i] = MatchCandidate{
			ID:       cand.ID,
			Title:    cand.Title,
			Artist:   cand.Artist,
			Album:    cand.Album,
			Duration: cand.Duration,
			Source:   cand.Source,
			Score:    c.matcher.Similarity(query.Title, cand.Title) * 0.6 + c.matcher.Similarity(query.Artist, cand.Artist) * 0.4,
		}
	}

	return &MatchResponse{
		Match: &MatchResult{
			ID:             match.ID,
			Title:          match.Title,
			Artist:         match.Artist,
			Album:          match.Album,
			DurationMs:     match.Duration,
			ISRC:           match.ISRC,
			Confidence:     match.Confidence,
			ScoreBreakdown: ScoreBreakdown{
				TitleScore:    match.ScoreBreakdown.TitleScore,
				ArtistScore:   match.ScoreBreakdown.ArtistScore,
				AlbumScore:    match.ScoreBreakdown.AlbumScore,
				DurationScore: match.ScoreBreakdown.DurationScore,
				ISRCScore:     match.ScoreBreakdown.ISRCScore,
				TotalScore:    match.ScoreBreakdown.TotalScore,
			},
			MatchReasons: match.MatchReasons,
		},
		Candidates: matchCandidates,
	}, nil
}

type ResolveRequest struct {
	Title       string   `json:"title"`
	Artist      string   `json:"artist"`
	Album       string   `json:"album,omitempty"`
	DurationMs  int64    `json:"duration_ms,omitempty"`
	ISRC        string   `json:"isrc,omitempty"`
	Quality     string   `json:"quality,omitempty"`
	Providers   []string `json:"providers,omitempty"`
	Exclude     []string `json:"exclude,omitempty"`
	RequireISRC bool     `json:"require_isrc,omitempty"`
}

type ResolveResponse struct {
	Source       AudioSource   `json:"source"`
	Match        *MatchResult  `json:"match,omitempty"`
	Candidates   []SearchResult `json:"candidates,omitempty"`
	Provider     string        `json:"provider"`
	ResolvedAt   string        `json:"resolved_at"`
}

type AudioSource struct {
	URL        string            `json:"url"`
	MimeType   string            `json:"mime_type"`
	Bitrate    int               `json:"bitrate,omitempty"`
	Quality    string            `json:"quality"`
	Provider   string            `json:"provider"`
	TrackID    string            `json:"track_id"`
	Headers    map[string]string `json:"headers,omitempty"`
	ExpiresAt  int64             `json:"expires_at,omitempty"`
	Checksum   string            `json:"checksum,omitempty"`
	Size       int64             `json:"size,omitempty"`
}

func (c *Core) Resolve(ctx context.Context, req ResolveRequest) (*ResolveResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	query := matching.TrackQuery{
		Title:    req.Title,
		Artist:   req.Artist,
		Album:    req.Album,
		Duration: req.DurationMs,
		ISRC:     req.ISRC,
	}

	quality := resolver.QualityAuto
	if req.Quality != "" {
		quality = resolver.Quality(req.Quality)
	}

	resolveReq := resolver.ResolveRequest{
		TrackQuery:  query,
		Quality:     quality,
		Providers:   req.Providers,
		Exclude:     req.Exclude,
		RequireISRC: req.RequireISRC,
	}

	result, err := c.resolver.Resolve(ctx, resolveReq)
	if err != nil {
		return nil, err
	}

	// Convert candidates
	searchResults := make([]SearchResult, len(result.Candidates))
	for i, r := range result.Candidates {
		searchResults[i] = SearchResult{
			ID:         r.ID,
			Title:      r.Title,
			Artist:     r.Artist,
			Album:      r.Album,
			DurationMs: r.Duration,
			Source:     r.Source,
			Thumbnail:  r.Thumbnail,
			Quality:    r.Quality,
		}
	}

	return &ResolveResponse{
		Source: AudioSource{
			URL:       result.Source.URL,
			MimeType:  result.Source.MimeType,
			Bitrate:   result.Source.Bitrate,
			Quality:   string(result.Source.Quality),
			Provider:  result.SelectedProvider,
			TrackID:   result.Source.TrackID,
			Headers:   result.Source.Headers,
			ExpiresAt: result.Source.ExpiresAt.Unix(),
			Checksum:  result.Source.Checksum,
			Size:      result.Source.Size,
		},
		Match: &MatchResult{
			ID:             result.Match.ID,
			Title:          result.Match.Title,
			Artist:         result.Match.Artist,
			Album:          result.Match.Album,
			DurationMs:     result.Match.Duration,
			ISRC:           result.Match.ISRC,
			Confidence:     result.Match.Confidence,
			ScoreBreakdown: ScoreBreakdown{
				TitleScore:    result.Match.ScoreBreakdown.TitleScore,
				ArtistScore:   result.Match.ScoreBreakdown.ArtistScore,
				AlbumScore:    result.Match.ScoreBreakdown.AlbumScore,
				DurationScore: result.Match.ScoreBreakdown.DurationScore,
				ISRCScore:     result.Match.ScoreBreakdown.ISRCScore,
				TotalScore:    result.Match.ScoreBreakdown.TotalScore,
			},
			MatchReasons: result.Match.MatchReasons,
		},
		Candidates:   searchResults,
		Provider:     result.SelectedProvider,
		ResolvedAt:   result.ResolvedAt.Format(time.RFC3339),
	}, nil
}

type DownloadRequest struct {
	URL               string `json:"url"`
	Title             string `json:"title"`
	Artist            string `json:"artist"`
	Album             string `json:"album,omitempty"`
	CoverURL          string `json:"cover_url,omitempty"`
	Quality           string `json:"quality,omitempty"`
	ExpectedSize      int64  `json:"expected_size,omitempty"`
	ExpectedChecksum  string `json:"expected_checksum,omitempty"`
}

type DownloadResponse struct {
	JobID string `json:"job_id"`
}

type JobStatus struct {
	JobID           string  `json:"job_id"`
	State           string  `json:"state"`
	Progress        float64 `json:"progress"`
	BytesDownloaded int64   `json:"bytes_downloaded"`
	TotalBytes      int64   `json:"total_bytes"`
	Speed           int64   `json:"speed"`
	Error           string  `json:"error,omitempty"`
	OutputPath      string  `json:"output_path,omitempty"`
}

func (c *Core) Download(ctx context.Context, req DownloadRequest) (*DownloadResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	quality := download.QualityAuto
	if req.Quality != "" {
		quality = download.Quality(req.Quality)
	}

	dlReq := manager.DownloadRequest{
		URL:               req.URL,
		Title:             req.Title,
		Artist:            req.Artist,
		Album:             req.Album,
		CoverURL:          req.CoverURL,
		Quality:           quality,
		ExpectedSize:      req.ExpectedSize,
		ExpectedChecksum:  req.ExpectedChecksum,
	}

	job, err := c.downloadManager.Download(ctx, dlReq)
	if err != nil {
		return nil, err
	}

	return &DownloadResponse{JobID: job.ID}, nil
}

func (c *Core) CancelDownload(ctx context.Context, jobID string) error {
	if !c.initialized {
		return ErrNotInitialized
	}
	return c.downloadManager.CancelJob(jobID)
}

func (c *Core) GetDownloadStatus(ctx context.Context, jobID string) (*JobStatus, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	job, ok := c.downloadManager.GetJob(jobID)
	if !ok {
		return nil, nil
	}

	progress, downloaded, total, speed := job.GetProgress()

	return &JobStatus{
		JobID:           job.ID,
		State:           string(job.GetState()),
		Progress:        progress,
		BytesDownloaded: downloaded,
		TotalBytes:      total,
		Speed:           speed,
		Error:           job.Error,
		OutputPath:      job.OutputFilename,
	}, nil
}

func (c *Core) ListDownloads(ctx context.Context) ([]*JobStatus, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	jobs := c.downloadManager.ListJobs()
	statuses := make([]*JobStatus, len(jobs))
	for i, job := range jobs {
		progress, downloaded, total, speed := job.GetProgress()
		statuses[i] = &JobStatus{
			JobID:           job.ID,
			State:           string(job.GetState()),
			Progress:        progress,
			BytesDownloaded: downloaded,
			TotalBytes:      total,
			Speed:           speed,
			Error:           job.Error,
			OutputPath:      job.OutputFilename,
		}
	}
	return statuses, nil
}

type ExtensionInfo struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	Description   string   `json:"description"`
	Version       string   `json:"version"`
	Author        string   `json:"author"`
	Kind          string   `json:"kind"`
	Enabled       bool     `json:"enabled"`
	Capabilities  []string `json:"capabilities"`
	InstalledAt   string   `json:"installed_at"`
	Health        string   `json:"health"`
}

type InstallExtensionRequest struct {
	PackageURL     string `json:"package_url,omitempty"`
	PackagePath    string `json:"package_path,omitempty"`
	ExpectedSHA256 string `json:"expected_sha256,omitempty"`
	Force          bool   `json:"force,omitempty"`
}

type ExtensionResponse struct {
	Extension *ExtensionInfo `json:"extension,omitempty"`
	Error     string         `json:"error,omitempty"`
}

func (c *Core) InstallExtension(ctx context.Context, req InstallExtensionRequest) (*ExtensionResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	opts := installer.InstallOptions{
		PackageURL:      req.PackageURL,
		PackagePath:     req.PackagePath,
		ExpectedSHA256:  req.ExpectedSHA256,
		Force:           req.Force,
	}

	ext, err := c.extManager.Install(ctx, opts)
	if err != nil {
		return &ExtensionResponse{Error: err.Error()}, nil
	}

	return &ExtensionResponse{
		Extension: &ExtensionInfo{
			ID:           ext.Manifest.ID,
			Name:         ext.Manifest.Name,
			Description:  ext.Manifest.Description,
			Version:      ext.Manifest.Version,
			Author:       ext.Manifest.Author,
			Kind:         string(ext.Manifest.Kind),
			Enabled:      ext.Enabled,
			Capabilities: ext.Manifest.Capabilities,
			InstalledAt:  ext.InstalledAt.Format(time.RFC3339),
		},
	}, nil
}

func (c *Core) UninstallExtension(ctx context.Context, id string) error {
	if !c.initialized {
		return ErrNotInitialized
	}
	return c.extManager.Uninstall(ctx, id)
}

func (c *Core) EnableExtension(ctx context.Context, id string, enabled bool) error {
	if !c.initialized {
		return ErrNotInitialized
	}
	return c.extManager.Enable(ctx, id, enabled)
}

func (c *Core) ListExtensions(ctx context.Context) ([]*ExtensionInfo, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	exts := c.extManager.List()
	result := make([]*ExtensionInfo, len(exts))
	for i, ext := range exts {
		result[i] = &ExtensionInfo{
			ID:           ext.Manifest.ID,
			Name:         ext.Manifest.Name,
			Description:  ext.Manifest.Description,
			Version:      ext.Manifest.Version,
			Author:       ext.Manifest.Author,
			Kind:         string(ext.Manifest.Kind),
			Enabled:      ext.Enabled,
			Capabilities: ext.Manifest.Capabilities,
			InstalledAt:  ext.InstalledAt.Format(time.RFC3339),
		}
	}
	return result, nil
}

func (c *Core) GetExtension(ctx context.Context, id string) (*ExtensionInfo, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	ext, ok := c.extManager.Get(id)
	if !ok {
		return nil, nil
	}

	return &ExtensionInfo{
		ID:           ext.Manifest.ID,
		Name:         ext.Manifest.Name,
		Description:  ext.Manifest.Description,
		Version:      ext.Manifest.Version,
		Author:       ext.Manifest.Author,
		Kind:         string(ext.Manifest.Kind),
		Enabled:      ext.Enabled,
		Capabilities: ext.Manifest.Capabilities,
		InstalledAt:  ext.InstalledAt.Format(time.RFC3339),
	}, nil
}

func (c *Core) CheckExtensionHealth(ctx context.Context, id string) (string, error) {
	if !c.initialized {
		return "", ErrNotInitialized
	}

	result, ok := c.extManager.CheckHealth(ctx, id)
	if !ok {
		return "unknown", nil
	}
	return string(result.Status), nil
}

func (c *Core) UpdateExtension(ctx context.Context, id string) (*ExtensionResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	ext, err := c.extManager.Update(ctx, id)
	if err != nil {
		return &ExtensionResponse{Error: err.Error()}, nil
	}

	return &ExtensionResponse{
		Extension: &ExtensionInfo{
			ID:           ext.Manifest.ID,
			Name:         ext.Manifest.Name,
			Description:  ext.Manifest.Description,
			Version:      ext.Manifest.Version,
			Author:       ext.Manifest.Author,
			Kind:         string(ext.Manifest.Kind),
			Enabled:      ext.Enabled,
			Capabilities: ext.Manifest.Capabilities,
			InstalledAt:  ext.InstalledAt.Format(time.RFC3339),
		},
	}, nil
}

func (c *Core) UpdateAllExtensions(ctx context.Context) ([]*ExtensionResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	exts, err := c.extManager.UpdateAll(ctx)
	if err != nil {
		return nil, err
	}

	result := make([]*ExtensionResponse, len(exts))
	for i, ext := range exts {
		result[i] = &ExtensionResponse{
			Extension: &ExtensionInfo{
				ID:           ext.Manifest.ID,
				Name:         ext.Manifest.Name,
				Description:  ext.Manifest.Description,
				Version:      ext.Manifest.Version,
				Author:       ext.Manifest.Author,
				Kind:         string(ext.Manifest.Kind),
				Enabled:      ext.Enabled,
				Capabilities: ext.Manifest.Capabilities,
				InstalledAt:  ext.InstalledAt.Format(time.RFC3339),
			},
		}
	}
	return result, nil
}

func (c *Core) AddRepository(ctx context.Context, url string) error {
	if !c.initialized {
		return ErrNotInitialized
	}
	return c.extManager.AddRepository(ctx, url)
}

func (c *Core) RemoveRepository(ctx context.Context, url string) error {
	if !c.initialized {
		return ErrNotInitialized
	}
	return c.extManager.RemoveRepository(ctx, url)
}

func (c *Core) ListRepositories(ctx context.Context) ([]RepositoryInfo, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	repos := c.extManager.GetRepositories()
	result := make([]RepositoryInfo, len(repos))
	for i, repo := range repos {
		result[i] = RepositoryInfo{
			URL:         repo.URL,
			Name:        repo.Name,
			Enabled:     repo.Enabled,
			LastFetched: repo.LastFetched.Format(time.RFC3339),
			Error:       repo.LastError,
		}
	}
	return result, nil
}

type RepositoryInfo struct {
	URL         string `json:"url"`
	Name        string `json:"name"`
	Enabled     bool   `json:"enabled"`
	LastFetched string `json:"last_fetched,omitempty"`
	Error       string `json:"error,omitempty"`
}

type MetadataRequest struct {
	FilePath string `json:"file_path"`
}

type MetadataResponse struct {
	Format    string            `json:"format"`
	FilePath  string            `json:"file_path"`
	FileSize  int64             `json:"file_size"`
	Tags      map[string]string `json:"tags"`
	Technical TechnicalInfo     `json:"technical"`
}

type TechnicalInfo struct {
	SampleRate int    `json:"sample_rate"`
	BitDepth   int    `json:"bit_depth"`
	Channels   int    `json:"channels"`
	Bitrate    int    `json:"bitrate"`
	Codec      string `json:"codec"`
	DurationMs int64  `json:"duration_ms"`
}

func (c *Core) ReadMetadata(ctx context.Context, req MetadataRequest) (*MetadataResponse, error) {
	if !c.initialized {
		return nil, ErrNotInitialized
	}

	meta, err := c.metadataService.Read(ctx, req.FilePath)
	if err != nil {
		return nil, err
	}

	tags := map[string]string{
		"title":        meta.Tags.Title,
		"artist":       meta.Tags.Artist,
		"album":        meta.Tags.Album,
		"album_artist": meta.Tags.AlbumArtist,
		"composer":     meta.Tags.Composer,
		"genre":        meta.Tags.Genre,
		"year":         fmt.Sprintf("%d", meta.Tags.Year),
		"track":        fmt.Sprintf("%d", meta.Tags.TrackNumber),
		"disc":         fmt.Sprintf("%d", meta.Tags.DiscNumber),
		"isrc":         meta.Tags.ISRC,
		"lyrics":       meta.Tags.Lyrics,
	}

	return &MetadataResponse{
		Format:    string(meta.Format),
		FilePath:  meta.FilePath,
		FileSize:  meta.FileSize,
		Tags:      tags,
		Technical: TechnicalInfo{
			SampleRate: meta.Technical.SampleRate,
			BitDepth:   meta.Technical.BitDepth,
			Channels:   meta.Technical.Channels,
			Bitrate:    meta.Technical.Bitrate,
			Codec:      meta.Technical.Codec,
			DurationMs: meta.Technical.Duration.Milliseconds(),
		},
	}, nil
}

type WriteMetadataRequest struct {
	FilePath string            `json:"file_path"`
	Tags     map[string]string `json:"tags"`
}

func (c *Core) WriteMetadata(ctx context.Context, req WriteMetadataRequest) error {
	if !c.initialized {
		return ErrNotInitialized
	}

	tags := metadata.Tag{}
	if v, ok := req.Tags["title"]; ok {
		tags.Title = v
	}
	if v, ok := req.Tags["artist"]; ok {
		tags.Artist = v
	}
	if v, ok := req.Tags["album"]; ok {
		tags.Album = v
	}
	if v, ok := req.Tags["album_artist"]; ok {
		tags.AlbumArtist = v
	}
	if v, ok := req.Tags["composer"]; ok {
		tags.Composer = v
	}
	if v, ok := req.Tags["genre"]; ok {
		tags.Genre = v
	}
	if v, ok := req.Tags["year"]; ok {
		fmt.Sscanf(v, "%d", &tags.Year)
	}
	if v, ok := req.Tags["track"]; ok {
		fmt.Sscanf(v, "%d", &tags.TrackNumber)
	}
	if v, ok := req.Tags["disc"]; ok {
		fmt.Sscanf(v, "%d", &tags.DiscNumber)
	}
	if v, ok := req.Tags["isrc"]; ok {
		tags.ISRC = v
	}
	if v, ok := req.Tags["lyrics"]; ok {
		tags.Lyrics = v
	}

	return c.metadataService.Write(ctx, req.FilePath, tags)
}

type CoverArtRequest struct {
	FilePath  string `json:"file_path"`
	ImageData []byte `json:"image_data"`
	MimeType  string `json:"mime_type"`
}

func (c *Core) EmbedCoverArt(ctx context.Context, req CoverArtRequest) error {
	if !c.initialized {
		return ErrNotInitialized
	}

	cover := metadata.CoverArt{
		Data:     req.ImageData,
		MimeType: req.MimeType,
		IsFront:  true,
	}

	return c.metadataService.EmbedCoverArt(ctx, req.FilePath, cover)
}

type LyricsRequest struct {
	FilePath string `json:"file_path"`
	Lyrics   string `json:"lyrics"`
}

func (c *Core) EmbedLyrics(ctx context.Context, req LyricsRequest) error {
	if !c.initialized {
		return ErrNotInitialized
	}
	return c.metadataService.EmbedLyrics(ctx, req.FilePath, req.Lyrics)
}

func (c *Core) ExtractLyrics(ctx context.Context, filePath string) (string, error) {
	if !c.initialized {
		return "", ErrNotInitialized
	}
	return c.metadataService.ExtractLyrics(ctx, filePath)
}

func (c *Core) GetStats() Stats {
	return Stats{
		Version:     c.version,
		APIVersion:  c.apiVersion,
		UptimeMs:    time.Since(c.startTime).Milliseconds(),
		Initialized: c.initialized,
	}
}

type Stats struct {
	Version     string `json:"version"`
	APIVersion  string `json:"api_version"`
	UptimeMs    int64  `json:"uptime_ms"`
	Initialized bool   `json:"initialized"`
}

func (c *Core) Shutdown() error {
	if !c.initialized {
		return nil
	}

	if c.extManager != nil {
		c.extManager.Close()
	}
	if c.downloadManager != nil {
		c.downloadManager.Stop()
	}

	c.initialized = false
	return nil
}

func (c *Core) ToJSON() (string, error) {
	data, err := json.Marshal(c.GetStats())
	if err != nil {
		return "", err
	}
	return string(data), nil
}