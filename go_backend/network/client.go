package network

import (
	"bytes"
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
	"sync"
	"time"
)

var (
	ErrPermissionDenied = errors.New("network: permission denied")
	ErrTimeout          = errors.New("network: request timeout")
	ErrInvalidURL       = errors.New("network: invalid URL")
)

type PermissionChecker interface {
	CheckURL(ctx context.Context, url string) error
	CheckDomain(ctx context.Context, domain string) error
}

type noopPermissionChecker struct{}

func (noopPermissionChecker) CheckURL(ctx context.Context, url string) error  { return nil }
func (noopPermissionChecker) CheckDomain(ctx context.Context, domain string) error { return nil }

type ClientConfig struct {
	Timeout         time.Duration
	MaxIdleConns    int
	IdleConnTimeout time.Duration
	UserAgent       string
	PermissionChecker
	EnableHTTP2     bool
	InsecureSkipVerify bool
	CookieJar       http.CookieJar
}

func DefaultClientConfig() ClientConfig {
	return ClientConfig{
		Timeout:         30 * time.Second,
		MaxIdleConns:    100,
		IdleConnTimeout: 90 * time.Second,
		UserAgent:       "Melodi/1.0",
		PermissionChecker: noopPermissionChecker{},
		EnableHTTP2:     true,
		InsecureSkipVerify: false,
	}
}

type HTTPClient struct {
	client           *http.Client
	config           ClientConfig
	permissionChecker PermissionChecker
	mu               sync.RWMutex
	cache            *ResponseCache
}

func NewHTTPClient(config ClientConfig) (*HTTPClient, error) {
	jar, _ := cookiejar.New(nil)
	var cookieJar http.CookieJar = jar
	if config.CookieJar != nil {
		cookieJar = config.CookieJar
	}

	if config.PermissionChecker == nil {
		config.PermissionChecker = noopPermissionChecker{}
	}

	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   10 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		MaxIdleConns:          config.MaxIdleConns,
		MaxIdleConnsPerHost:   config.MaxIdleConns,
		IdleConnTimeout:       config.IdleConnTimeout,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		ForceAttemptHTTP2:     config.EnableHTTP2,
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: config.InsecureSkipVerify,
		},
	}

	client := &http.Client{
		Transport: transport,
		Timeout:   config.Timeout,
		Jar:       cookieJar,
	}

	return &HTTPClient{
		client:            client,
		config:            config,
		permissionChecker: config.PermissionChecker,
		cache:             NewResponseCache(1000, 10*time.Minute),
	}, nil
}

func (c *HTTPClient) Do(ctx context.Context, req *http.Request) (*http.Response, error) {
	if req.URL == nil {
		return nil, ErrInvalidURL
	}

	if err := c.permissionChecker.CheckURL(ctx, req.URL.String()); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrPermissionDenied, err)
	}

	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", c.config.UserAgent)
	}

	if cached, ok := c.cache.Get(req.Method, req.URL.String()); ok {
		return cached, nil
	}

	resp, err := c.client.Do(req.WithContext(ctx))
	if err != nil {
		return nil, err
	}

	if resp.StatusCode == http.StatusOK && (req.Method == "GET" || req.Method == "HEAD") {
		c.cache.Set(req.Method, req.URL.String(), resp)
	}

	return resp, nil
}

func (c *HTTPClient) Get(ctx context.Context, url string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}
	return c.Do(ctx, req)
}

func (c *HTTPClient) Head(ctx context.Context, url string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "HEAD", url, nil)
	if err != nil {
		return nil, err
	}
	return c.Do(ctx, req)
}

func (c *HTTPClient) Post(ctx context.Context, url, contentType string, body io.Reader) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "POST", url, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", contentType)
	return c.Do(ctx, req)
}

func (c *HTTPClient) SetPermissionChecker(checker PermissionChecker) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.permissionChecker = checker
}

func (c *HTTPClient) Close() {
	c.client.CloseIdleConnections()
	c.cache.Clear()
}

type ResponseCache struct {
	mu       sync.RWMutex
	entries  map[string]*cacheEntry
	maxSize  int
	ttl      time.Duration
}

type cacheEntry struct {
	resp     *http.Response
	expiresAt time.Time
	body     []byte
}

func NewResponseCache(maxSize int, ttl time.Duration) *ResponseCache {
	rc := &ResponseCache{
		entries: make(map[string]*cacheEntry),
		maxSize: maxSize,
		ttl:     ttl,
	}
	go rc.cleanupLoop()
	return rc
}

func (rc *ResponseCache) key(method, url string) string {
	return method + ":" + url
}

func (rc *ResponseCache) Get(method, url string) (*http.Response, bool) {
	rc.mu.RLock()
	defer rc.mu.RUnlock()

	key := rc.key(method, url)
	entry, ok := rc.entries[key]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil, false
	}

	return entry.resp, true
}

func (rc *ResponseCache) Set(method, url string, resp *http.Response) {
	rc.mu.Lock()
	defer rc.mu.Unlock()

	if len(rc.entries) >= rc.maxSize {
		rc.evictOldest()
	}

	body, _ := io.ReadAll(resp.Body)
	resp.Body = io.NopCloser(bytes.NewReader(body))

	rc.entries[rc.key(method, url)] = &cacheEntry{
		resp:      resp,
		expiresAt: time.Now().Add(rc.ttl),
		body:      body,
	}
}

func (rc *ResponseCache) Clear() {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	rc.entries = make(map[string]*cacheEntry)
}

func (rc *ResponseCache) evictOldest() {
	var oldestKey string
	var oldestTime time.Time
	for k, v := range rc.entries {
		if oldestKey == "" || v.expiresAt.Before(oldestTime) {
			oldestKey = k
			oldestTime = v.expiresAt
		}
	}
	if oldestKey != "" {
		delete(rc.entries, oldestKey)
	}
}

func (rc *ResponseCache) cleanupLoop() {
	ticker := time.NewTicker(rc.ttl)
	defer ticker.Stop()
	for range ticker.C {
		rc.mu.Lock()
		now := time.Now()
		for k, v := range rc.entries {
			if now.After(v.expiresAt) {
				delete(rc.entries, k)
			}
		}
		rc.mu.Unlock()
	}
}

type DomainPermissionChecker struct {
	allowedDomains map[string]bool
	allowAll       bool
	mu             sync.RWMutex
}

func NewDomainPermissionChecker(domains []string) *DomainPermissionChecker {
	d := &DomainPermissionChecker{
		allowedDomains: make(map[string]bool),
		allowAll:       len(domains) == 0,
	}
	for _, domain := range domains {
		d.allowedDomains[domain] = true
	}
	return d
}

func (d *DomainPermissionChecker) CheckURL(ctx context.Context, urlStr string) error {
	u, err := url.Parse(urlStr)
	if err != nil {
		return err
	}
	return d.CheckDomain(ctx, u.Host)
}

func (d *DomainPermissionChecker) CheckDomain(ctx context.Context, domain string) error {
	d.mu.RLock()
	defer d.mu.RUnlock()

	if d.allowAll {
		return nil
	}

	domain = strings.ToLower(domain)
	for allowed := range d.allowedDomains {
		allowed = strings.ToLower(allowed)
		if domain == allowed || strings.HasSuffix(domain, "."+allowed) {
			return nil
		}
	}
	return fmt.Errorf("%w: domain %s not in allowlist", ErrPermissionDenied, domain)
}

func (d *DomainPermissionChecker) AddDomain(domain string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.allowedDomains[strings.ToLower(domain)] = true
}

func (d *DomainPermissionChecker) RemoveDomain(domain string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	delete(d.allowedDomains, strings.ToLower(domain))
}