package permissions

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"sync"
)

var (
	ErrPermissionDenied = errors.New("permissions: access denied")
	ErrInvalidPermission = errors.New("permissions: invalid permission")
)

type Permission string

const (
	PermNetwork      Permission = "network"
	PermStorage      Permission = "storage"
	PermFileRead     Permission = "file:read"
	PermFileWrite    Permission = "file:write"
	PermFileDelete   Permission = "file:delete"
	PermHTTPRequest  Permission = "http:request"
	PermHTTPResponse Permission = "http:response"
)

type PermissionSet struct {
	mu           sync.RWMutex
	allowed      map[Permission]bool
	networkDomains []string
	allowAllNetwork bool
}

func NewPermissionSet(permissions []string, networkDomains []string) *PermissionSet {
	p := &PermissionSet{
		allowed:        make(map[Permission]bool),
		networkDomains: networkDomains,
		allowAllNetwork: len(networkDomains) == 0,
	}
	for _, perm := range permissions {
		p.allowed[Permission(perm)] = true
	}
	return p
}

func (p *PermissionSet) Has(perm Permission) bool {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.allowed[perm]
}

func (p *PermissionSet) Grant(perm Permission) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.allowed[perm] = true
}

func (p *PermissionSet) Revoke(perm Permission) {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.allowed, perm)
}

func (p *PermissionSet) CheckNetwork(ctx context.Context, rawURL string) error {
	p.mu.RLock()
	defer p.mu.RUnlock()

	if !p.allowed[PermNetwork] && !p.allowed[PermHTTPRequest] {
		return fmt.Errorf("%w: network permission not granted", ErrPermissionDenied)
	}

	if p.allowAllNetwork {
		return nil
	}

	u, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("%w: invalid URL", ErrPermissionDenied)
	}

	host := strings.ToLower(u.Host)
	for _, allowed := range p.networkDomains {
		allowed = strings.ToLower(allowed)
		if host == allowed || strings.HasSuffix(host, "."+allowed) {
			return nil
		}
	}
	return fmt.Errorf("%w: domain %s not in allowlist", ErrPermissionDenied, host)
}

func (p *PermissionSet) CheckStorage(ctx context.Context, operation string) error {
	p.mu.RLock()
	defer p.mu.RUnlock()

	switch operation {
	case "read":
		if !p.allowed[PermStorage] && !p.allowed[PermFileRead] {
			return fmt.Errorf("%w: storage read permission not granted", ErrPermissionDenied)
		}
	case "write":
		if !p.allowed[PermStorage] && !p.allowed[PermFileWrite] {
			return fmt.Errorf("%w: storage write permission not granted", ErrPermissionDenied)
		}
	case "delete":
		if !p.allowed[PermStorage] && !p.allowed[PermFileDelete] {
			return fmt.Errorf("%w: storage delete permission not granted", ErrPermissionDenied)
		}
	}
	return nil
}

func (p *PermissionSet) GetNetworkDomains() []string {
	p.mu.RLock()
	defer p.mu.RUnlock()
	result := make([]string, len(p.networkDomains))
	copy(result, p.networkDomains)
	return result
}

func (p *PermissionSet) AddNetworkDomain(domain string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.networkDomains = append(p.networkDomains, strings.ToLower(domain))
	p.allowAllNetwork = false
}

type ExtensionPermissions struct {
	extID string
	perms *PermissionSet
}

func NewExtensionPermissions(extID string, permissions []string, networkDomains []string) *ExtensionPermissions {
	return &ExtensionPermissions{
		extID: extID,
		perms: NewPermissionSet(permissions, networkDomains),
	}
}

func (e *ExtensionPermissions) CheckNetwork(ctx context.Context, rawURL string) error {
	return e.perms.CheckNetwork(ctx, rawURL)
}

func (e *ExtensionPermissions) CheckStorage(ctx context.Context, operation string) error {
	return e.perms.CheckStorage(ctx, operation)
}

func (e *ExtensionPermissions) Has(perm Permission) bool {
	return e.perms.Has(perm)
}

func (e *ExtensionPermissions) ExtensionID() string {
	return e.extID
}

type PermissionManager struct {
	mu           sync.RWMutex
	extensions   map[string]*ExtensionPermissions
	defaultPerms *PermissionSet
}

func NewPermissionManager(defaultPermissions []string, defaultNetworkDomains []string) *PermissionManager {
	return &PermissionManager{
		extensions:   make(map[string]*ExtensionPermissions),
		defaultPerms: NewPermissionSet(defaultPermissions, defaultNetworkDomains),
	}
}

func (m *PermissionManager) Register(extID string, permissions []string, networkDomains []string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.extensions[extID] = NewExtensionPermissions(extID, permissions, networkDomains)
}

func (m *PermissionManager) Unregister(extID string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.extensions, extID)
}

func (m *PermissionManager) Get(extID string) (*ExtensionPermissions, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	perms, ok := m.extensions[extID]
	return perms, ok
}

func (m *PermissionManager) CheckNetwork(ctx context.Context, extID, rawURL string) error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if perms, ok := m.extensions[extID]; ok {
		return perms.CheckNetwork(ctx, rawURL)
	}
	return m.defaultPerms.CheckNetwork(ctx, rawURL)
}

func (m *PermissionManager) CheckStorage(ctx context.Context, extID, operation string) error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if perms, ok := m.extensions[extID]; ok {
		return perms.CheckStorage(ctx, operation)
	}
	return m.defaultPerms.CheckStorage(ctx, operation)
}