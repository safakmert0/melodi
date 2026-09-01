package health

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"melodi/go_backend/network"
)

var (
	ErrHealthCheckFailed = errors.New("health: check failed")
	ErrUnhealthy         = errors.New("health: unhealthy")
	ErrTimeout           = errors.New("health: timeout")
)

type HealthStatus string

const (
	HealthHealthy   HealthStatus = "healthy"
	HealthUnhealthy HealthStatus = "unhealthy"
	HealthUnknown   HealthStatus = "unknown"
	HealthChecking  HealthStatus = "checking"
)

type HealthCheckResult struct {
	Status      HealthStatus
	Latency     time.Duration
	StatusCode  int
	CheckedAt   time.Time
	Error       string
	Details     map[string]string
}

type HealthChecker interface {
	Check(ctx context.Context) HealthCheckResult
	Start(ctx context.Context)
	Stop()
	Status() HealthStatus
	LastResult() HealthCheckResult
}

type HTTPEndpointChecker struct {
	client      *network.HTTPClient
	url         string
	method      string
	interval    time.Duration
	timeout     time.Duration
	expectedCodes []int

	mu         sync.RWMutex
	status     HealthStatus
	lastResult HealthCheckResult
	stopCh     chan struct{}
	wg         sync.WaitGroup
}

func NewHTTPEndpointChecker(client *network.HTTPClient, url, method string, interval, timeout time.Duration, expectedCodes []int) *HTTPEndpointChecker {
	if len(expectedCodes) == 0 {
		expectedCodes = []int{200, 201, 202, 204}
	}
	return &HTTPEndpointChecker{
		client:         client,
		url:            url,
		method:         method,
		interval:       interval,
		timeout:        timeout,
		expectedCodes:  expectedCodes,
		status:         HealthUnknown,
		lastResult:     HealthCheckResult{Status: HealthUnknown, CheckedAt: time.Time{}},
		stopCh:         make(chan struct{}),
	}
}

func (c *HTTPEndpointChecker) Check(ctx context.Context) HealthCheckResult {
	start := time.Now()
	var resp *http.Response
	var err error

	checkCtx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()

	switch strings.ToUpper(c.method) {
	case "HEAD":
		resp, err = c.client.Head(checkCtx, c.url)
	case "GET", "":
		resp, err = c.client.Get(checkCtx, c.url)
	default:
		req, _ := http.NewRequestWithContext(checkCtx, c.method, c.url, nil)
		resp, err = c.client.Do(checkCtx, req)
	}

	latency := time.Since(start)

	if err != nil {
		result := HealthCheckResult{
			Status:     HealthUnhealthy,
			Latency:    latency,
			CheckedAt:  time.Now(),
			Error:      err.Error(),
			Details:    map[string]string{"error": err.Error()},
		}
		c.setResult(result)
		return result
	}
	defer resp.Body.Close()

	isExpected := false
	for _, code := range c.expectedCodes {
		if resp.StatusCode == code {
			isExpected = true
			break
		}
	}

	status := HealthHealthy
	if !isExpected {
		status = HealthUnhealthy
	}

	result := HealthCheckResult{
		Status:      status,
		Latency:     latency,
		StatusCode:  resp.StatusCode,
		CheckedAt:   time.Now(),
		Details:     map[string]string{"url": c.url, "method": c.method},
	}
	if !isExpected {
		result.Error = fmt.Sprintf("unexpected status code: %d", resp.StatusCode)
	}

	c.setResult(result)
	return result
}

func (c *HTTPEndpointChecker) setResult(result HealthCheckResult) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.lastResult = result
	c.status = result.Status
}

func (c *HTTPEndpointChecker) Start(ctx context.Context) {
	c.wg.Add(1)
	go func() {
		defer c.wg.Done()
		ticker := time.NewTicker(c.interval)
		defer ticker.Stop()

		c.Check(ctx)

		for {
			select {
			case <-c.stopCh:
				return
			case <-ticker.C:
				c.Check(ctx)
			case <-ctx.Done():
				return
			}
		}
	}()
}

func (c *HTTPEndpointChecker) Stop() {
	close(c.stopCh)
	c.wg.Wait()
}

func (c *HTTPEndpointChecker) Status() HealthStatus {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.status
}

func (c *HTTPEndpointChecker) LastResult() HealthCheckResult {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.lastResult
}

type CompositeChecker struct {
	checkers []HealthChecker
	mu       sync.RWMutex
}

func NewCompositeChecker(checkers ...HealthChecker) *CompositeChecker {
	return &CompositeChecker{checkers: checkers}
}

func (c *CompositeChecker) Add(checker HealthChecker) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.checkers = append(c.checkers, checker)
}

func (c *CompositeChecker) Check(ctx context.Context) HealthCheckResult {
	c.mu.RLock()
	checkers := make([]HealthChecker, len(c.checkers))
	copy(checkers, c.checkers)
	c.mu.RUnlock()

	var allHealthy = true
	details := make(map[string]string)

	for _, checker := range checkers {
		result := checker.Check(ctx)
		details[fmt.Sprintf("%p", checker)] = string(result.Status)
		if result.Status != HealthHealthy {
			allHealthy = false
		}
	}

	status := HealthHealthy
	if !allHealthy {
		status = HealthUnhealthy
	}

	return HealthCheckResult{
		Status:     status,
		CheckedAt:  time.Now(),
		Error:      "",
		Details:    details,
	}
}

func (c *CompositeChecker) Start(ctx context.Context) {
	c.mu.RLock()
	checkers := make([]HealthChecker, len(c.checkers))
	copy(checkers, c.checkers)
	c.mu.RUnlock()

	for _, checker := range checkers {
		checker.Start(ctx)
	}
}

func (c *CompositeChecker) Stop() {
	c.mu.RLock()
	checkers := make([]HealthChecker, len(c.checkers))
	copy(checkers, c.checkers)
	c.mu.RUnlock()

	for _, checker := range checkers {
		checker.Stop()
	}
}

func (c *CompositeChecker) Status() HealthStatus {
	c.mu.RLock()
	defer c.mu.RUnlock()

	for _, checker := range c.checkers {
		if checker.Status() == HealthUnhealthy {
			return HealthUnhealthy
		}
		if checker.Status() == HealthUnknown {
			return HealthUnknown
		}
	}
	return HealthHealthy
}

func (c *CompositeChecker) LastResult() HealthCheckResult {
	return c.Check(context.Background())
}

type Manager struct {
	mu       sync.RWMutex
	checkers map[string]HealthChecker
}

func NewManager() *Manager {
	return &Manager{
		checkers: make(map[string]HealthChecker),
	}
}

func (m *Manager) Register(id string, checker HealthChecker) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.checkers[id] = checker
}

func (m *Manager) Unregister(id string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if checker, ok := m.checkers[id]; ok {
		checker.Stop()
		delete(m.checkers, id)
	}
}

func (m *Manager) Get(id string) (HealthChecker, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	checker, ok := m.checkers[id]
	return checker, ok
}

func (m *Manager) Check(ctx context.Context, id string) (HealthCheckResult, bool) {
	m.mu.RLock()
	checker, ok := m.checkers[id]
	m.mu.RUnlock()

	if !ok {
		return HealthCheckResult{Status: HealthUnknown}, false
	}
	return checker.Check(ctx), true
}

func (m *Manager) CheckAll(ctx context.Context) map[string]HealthCheckResult {
	m.mu.RLock()
	checkers := make(map[string]HealthChecker, len(m.checkers))
	for k, v := range m.checkers {
		checkers[k] = v
	}
	m.mu.RUnlock()

	results := make(map[string]HealthCheckResult)
	for id, checker := range checkers {
		results[id] = checker.Check(ctx)
	}
	return results
}

func (m *Manager) StartAll(ctx context.Context) {
	m.mu.RLock()
	checkers := make(map[string]HealthChecker, len(m.checkers))
	for k, v := range m.checkers {
		checkers[k] = v
	}
	m.mu.RUnlock()

	for _, checker := range checkers {
		checker.Start(ctx)
	}
}

func (m *Manager) StopAll() {
	m.mu.RLock()
	checkers := make(map[string]HealthChecker, len(m.checkers))
	for k, v := range m.checkers {
		checkers[k] = v
	}
	m.mu.RUnlock()

	for _, checker := range checkers {
		checker.Stop()
	}
}

func (m *Manager) List() []string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	ids := make([]string, 0, len(m.checkers))
	for id := range m.checkers {
		ids = append(ids, id)
	}
	return ids
}