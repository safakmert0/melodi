package runtime

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
	"melodi/go_backend/extension/manifest"
	"melodi/go_backend/extension/storage"
	"melodi/go_backend/network"
)

var (
	ErrRuntimeNotInitialized = errors.New("extension: runtime not initialized")
	ErrScriptExecutionFailed = errors.New("extension: script execution failed")
	ErrPermissionDenied      = errors.New("extension: permission denied")
	ErrTimeout               = errors.New("extension: execution timeout")
)

type Capability string

const (
	CapabilitySearch      Capability = "search"
	CapabilityMetadata    Capability = "metadata"
	CapabilityStream      Capability = "stream"
	CapabilityDownload    Capability = "download"
	CapabilityLyrics      Capability = "lyrics"
	CapabilityHealth      Capability = "health"
	CapabilityStorage     Capability = "storage"
	CapabilityNetwork     Capability = "network"
)

type ExtensionAPI interface {
	Search(ctx context.Context, query string, limit int) ([]SearchResult, error)
	Metadata(ctx context.Context, id string) (*TrackMetadata, error)
	Stream(ctx context.Context, id string, quality string) (*StreamInfo, error)
	Download(ctx context.Context, id string, quality string) (*DownloadInfo, error)
	Lyrics(ctx context.Context, id string) (*LyricsResult, error)
	Health(ctx context.Context) error
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

type Runtime struct {
	vm              *goja.Runtime
	manifest        *manifest.Manifest
	permissionCheck *network.DomainPermissionChecker
	httpClient      *network.HTTPClient
	storage         storage.Storage
	mu              sync.RWMutex
	initialized     bool
	startTime       time.Time
	executionCount  int64
}

func NewRuntime(m *manifest.Manifest, httpClient *network.HTTPClient, storage storage.Storage) (*Runtime, error) {
	if m == nil {
		return nil, fmt.Errorf("manifest is required")
	}
	if httpClient == nil {
		return nil, fmt.Errorf("httpClient is required")
	}
	if storage == nil {
		return nil, fmt.Errorf("storage is required")
	}

	vm := goja.New()
	vm.SetFieldNameMapper(goja.TagFieldNameMapper("json", true))

	permissionCheck := network.NewDomainPermissionChecker(m.NetworkDomains)
	httpClient.SetPermissionChecker(permissionCheck)

	r := &Runtime{
		vm:              vm,
		manifest:        m,
		permissionCheck: permissionCheck,
		httpClient:      httpClient,
		storage:         storage,
		startTime:       time.Now(),
	}

	if err := r.setupGlobals(); err != nil {
		return nil, err
	}

	if err := r.loadScript(m.EntryPoint); err != nil {
		return nil, err
	}

	r.initialized = true
	return r, nil
}

func (r *Runtime) setupGlobals() error {
	console := r.vm.NewObject()
	console.Set("log", r.vm.ToValue(func(call goja.FunctionCall) goja.Value {
		for i, arg := range call.Arguments {
			if i > 0 {
				fmt.Print(" ")
			}
			fmt.Print(arg.String())
		}
		fmt.Println()
		return goja.Undefined()
	}))
	console.Set("error", r.vm.ToValue(func(call goja.FunctionCall) goja.Value {
		for i, arg := range call.Arguments {
			if i > 0 {
				fmt.Print(" ")
			}
			fmt.Print("[ERROR] ", arg.String())
		}
		fmt.Println()
		return goja.Undefined()
	}))
	console.Set("warn", r.vm.ToValue(func(call goja.FunctionCall) goja.Value {
		for i, arg := range call.Arguments {
			if i > 0 {
				fmt.Print(" ")
			}
			fmt.Print("[WARN] ", arg.String())
		}
		fmt.Println()
		return goja.Undefined()
	}))
	r.vm.Set("console", console)

	r.vm.Set("setTimeout", r.vm.ToValue(func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 2 {
			return goja.Undefined()
		}
		fn, ok := goja.AssertFunction(call.Arguments[0])
		if !ok {
			return goja.Undefined()
		}
		delay := call.Arguments[1].ToInteger()
		go func() {
			time.Sleep(time.Duration(delay) * time.Millisecond)
			fn(goja.Undefined(), nil)
		}()
		return goja.Undefined()
	}))

	r.vm.Set("setInterval", r.vm.ToValue(func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) < 2 {
			return goja.Undefined()
		}
		fn, ok := goja.AssertFunction(call.Arguments[0])
		if !ok {
			return goja.Undefined()
		}
		interval := call.Arguments[1].ToInteger()
		ticker := time.NewTicker(time.Duration(interval) * time.Millisecond)
		go func() {
			for range ticker.C {
				fn(goja.Undefined(), nil)
			}
		}()
		return r.vm.ToValue(map[string]interface{}{"clear": func() { ticker.Stop() }})
	}))

	r.vm.Set("clearInterval", r.vm.ToValue(func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) > 0 {
			if obj, ok := call.Arguments[0].Export().(map[string]interface{}); ok {
				if clearFn, ok := obj["clear"].(func()); ok {
					clearFn()
				}
			}
		}
		return goja.Undefined()
	}))

	r.vm.Set("fetch", r.vm.ToValue(r.jsFetch))
	r.vm.Set("storage", r.vm.ToValue(r.storageJS()))
	r.vm.Set("crypto", r.vm.ToValue(r.cryptoJS()))
	r.vm.Set("manifest", r.vm.ToValue(r.manifest))
	r.vm.Set("melodi", r.vm.ToValue(map[string]interface{}{
		"version":   "1.0.0",
		"apiVersion": r.manifest.APIVersion,
		"capabilities": r.manifest.Capabilities,
	}))

	return nil
}

func (r *Runtime) loadScript(entryPoint string) error {
	script, err := r.storage.ReadFile(entryPoint)
	if err != nil {
		return fmt.Errorf("failed to read entry script %s: %w", entryPoint, err)
	}
	_, err = r.vm.RunString(string(script))
	return err
}

func (r *Runtime) jsFetch(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		return r.vm.ToValue(map[string]interface{}{"error": "fetch requires at least 1 argument"})
	}

	url := call.Arguments[0].String()
	opts := map[string]interface{}{}
	if len(call.Arguments) > 1 {
		if exported := call.Arguments[1].Export(); exported != nil {
			if m, ok := exported.(map[string]interface{}); ok {
				opts = m
			}
		}
	}

	ctx := context.Background()
	method := "GET"
	if m, ok := opts["method"].(string); ok {
		method = m
	}

	var body io.Reader
	if b, ok := opts["body"]; ok {
		switch v := b.(type) {
		case string:
			body = strings.NewReader(v)
		case []byte:
			body = bytes.NewReader(v)
		}
	}

	req, err := http.NewRequestWithContext(ctx, method, url, body)
	if err != nil {
		return r.vm.ToValue(map[string]interface{}{"error": err.Error()})
	}

	if headers, ok := opts["headers"].(map[string]interface{}); ok {
		for k, v := range headers {
			req.Header.Set(k, fmt.Sprintf("%v", v))
		}
	}

	resp, err := r.httpClient.Do(ctx, req)
	if err != nil {
		return r.vm.ToValue(map[string]interface{}{"error": err.Error()})
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	headersObj := r.vm.NewObject()
	for k, v := range resp.Header {
		if len(v) > 0 {
			headersObj.Set(k, v[0])
		}
	}

	return r.vm.ToValue(map[string]interface{}{
		"ok":        resp.StatusCode >= 200 && resp.StatusCode < 300,
		"status":    resp.StatusCode,
		"statusText": http.StatusText(resp.StatusCode),
		"headers":   headersObj,
		"body":      string(respBody),
		"json":      func() goja.Value { return r.vm.ToValue(string(respBody)) },
		"text":      func() goja.Value { return r.vm.ToValue(string(respBody)) },
	})
}

func (r *Runtime) storageJS() map[string]interface{} {
	return map[string]interface{}{
		"get": func(key string) (string, error) {
			return r.storage.Get(key)
		},
		"set": func(key, value string) error {
			return r.storage.Set(key, value)
		},
		"delete": func(key string) error {
			return r.storage.Delete(key)
		},
		"clear": func() error {
			return r.storage.Clear()
		},
		"list": func(prefix string) ([]string, error) {
			return r.storage.List(prefix)
		},
	}
}

func (r *Runtime) cryptoJS() map[string]interface{} {
	return map[string]interface{}{
		"sha256": func(data string) string {
			h := sha256.Sum256([]byte(data))
			return hex.EncodeToString(h[:])
		},
		"hmacSHA256": func(key, data string) string {
			h := hmac.New(sha256.New, []byte(key))
			h.Write([]byte(data))
			return hex.EncodeToString(h.Sum(nil))
		},
		"randomBytes": func(n int) ([]byte, error) {
			b := make([]byte, n)
			if _, err := rand.Read(b); err != nil {
				return nil, err
			}
			return b, nil
		},
	}
}

func (r *Runtime) CallFunction(name string, args ...interface{}) (interface{}, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if !r.initialized {
		return nil, ErrRuntimeNotInitialized
	}

	fn, ok := goja.AssertFunction(r.vm.Get(name))
	if !ok {
		return nil, fmt.Errorf("function %s not found", name)
	}

	jsArgs := make([]goja.Value, len(args))
	for i, arg := range args {
		jsArgs[i] = r.vm.ToValue(arg)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	done := make(chan struct{})
	var result goja.Value
	var err error

	go func() {
		result, err = fn(goja.Undefined(), jsArgs...)
		close(done)
	}()

	select {
	case <-done:
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrScriptExecutionFailed, err)
		}
		r.executionCount++
		return result.Export(), nil
	case <-ctx.Done():
		return nil, ErrTimeout
	}
}

func (r *Runtime) Search(ctx context.Context, query string, limit int) ([]SearchResult, error) {
	result, err := r.CallFunction("search", query, limit)
	if err != nil {
		return nil, err
	}
	arr, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("search returned invalid type")
	}
	var results []SearchResult
	for _, item := range arr {
		if m, ok := item.(map[string]interface{}); ok {
			results = append(results, SearchResult{
				ID:       getString(m, "id"),
				Title:    getString(m, "title"),
				Artist:   getString(m, "artist"),
				Album:    getString(m, "album"),
				Duration: getInt64(m, "durationMs"),
				Source:   getString(m, "source"),
				Thumbnail: getString(m, "thumbnail"),
				Quality:  getString(m, "quality"),
			})
		}
	}
	return results, nil
}

func (r *Runtime) Metadata(ctx context.Context, id string) (*TrackMetadata, error) {
	result, err := r.CallFunction("metadata", id)
	if err != nil {
		return nil, err
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("metadata returned invalid type")
	}
	return &TrackMetadata{
		ID:          getString(m, "id"),
		Title:       getString(m, "title"),
		Artist:      getString(m, "artist"),
		Album:       getString(m, "album"),
		Duration:    getInt64(m, "durationMs"),
		ISRC:        getString(m, "isrc"),
		TrackNumber: getInt(m, "trackNumber"),
		DiscNumber:  getInt(m, "discNumber"),
		Year:        getInt(m, "year"),
		Genre:       getString(m, "genre"),
		CoverURL:    getString(m, "coverUrl"),
	}, nil
}

func (r *Runtime) Stream(ctx context.Context, id string, quality string) (*StreamInfo, error) {
	result, err := r.CallFunction("stream", id, quality)
	if err != nil {
		return nil, err
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("stream returned invalid type")
	}
	return &StreamInfo{
		URL:      getString(m, "url"),
		MimeType: getString(m, "mimeType"),
		Bitrate:  getInt(m, "bitrate"),
		Quality:  getString(m, "quality"),
	}, nil
}

func (r *Runtime) Download(ctx context.Context, id string, quality string) (*DownloadInfo, error) {
	result, err := r.CallFunction("download", id, quality)
	if err != nil {
		return nil, err
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("download returned invalid type")
	}
	return &DownloadInfo{
		URL:      getString(m, "url"),
		MimeType: getString(m, "mimeType"),
		Size:     getInt64(m, "size"),
		Filename: getString(m, "filename"),
		Checksum: getString(m, "checksum"),
	}, nil
}

func (r *Runtime) Lyrics(ctx context.Context, id string) (*LyricsResult, error) {
	result, err := r.CallFunction("lyrics", id)
	if err != nil {
		return nil, err
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("lyrics returned invalid type")
	}
	return &LyricsResult{
		SyncedLRC: getString(m, "syncedLrc"),
		PlainText: getString(m, "plainText"),
		Language:  getString(m, "language"),
		Source:    getString(m, "source"),
	}, nil
}

func (r *Runtime) Health(ctx context.Context) error {
	_, err := r.CallFunction("health")
	return err
}

func (r *Runtime) GetManifest() *manifest.Manifest {
	return r.manifest
}

func (r *Runtime) IsInitialized() bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.initialized
}

func (r *Runtime) Uptime() time.Duration {
	return time.Since(r.startTime)
}

func (r *Runtime) ExecutionCount() int64 {
	return r.executionCount
}

func (r *Runtime) Close() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.initialized = false
	r.vm = nil
	return nil
}

func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key].(string); ok {
		return v
	}
	return ""
}

func getInt(m map[string]interface{}, key string) int {
	if v, ok := m[key].(int64); ok {
		return int(v)
	}
	if v, ok := m[key].(float64); ok {
		return int(v)
	}
	return 0
}

func getInt64(m map[string]interface{}, key string) int64 {
	if v, ok := m[key].(int64); ok {
		return v
	}
	if v, ok := m[key].(float64); ok {
		return int64(v)
	}
	return 0
}