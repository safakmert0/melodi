package manifest

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"time"
)

var (
	ErrInvalidManifest = errors.New("extension: invalid manifest")
	ErrInvalidID       = errors.New("extension: invalid id")
	ErrInvalidName     = errors.New("extension: invalid name")
	ErrInvalidBaseURL  = errors.New("extension: invalid base URL")
	ErrInvalidProtocol = errors.New("extension: invalid protocol")
	ErrInvalidVersion  = errors.New("extension: invalid version")
)

type Kind string

const (
	KindBackend Kind = "backend"
	KindHifi    Kind = "hifi"
	KindMetadata Kind = "metadata"
	KindLyrics   Kind = "lyrics"
	KindStream   Kind = "stream"
	KindDownload Kind = "download"
)

func (k Kind) String() string {
	return string(k)
}

func ParseKind(s string) (Kind, error) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "backend":
		return KindBackend, nil
	case "hifi", "lossless":
		return KindHifi, nil
	case "metadata":
		return KindMetadata, nil
	case "lyrics":
		return KindLyrics, nil
	case "stream":
		return KindStream, nil
	case "download":
		return KindDownload, nil
	default:
		return "", fmt.Errorf("%w: %s", ErrInvalidProtocol, s)
	}
}

type Protocol string

const (
	ProtocolYTDLPBackend Protocol = "yt-dlp-backend"
	ProtocolPiped        Protocol = "piped"
	ProtocolCustom       Protocol = "custom"
)

func (p Protocol) String() string {
	return string(p)
}

func ParseProtocol(s string) (Protocol, error) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "yt-dlp-backend", "ytdlp-backend", "ytdlp_backend":
		return ProtocolYTDLPBackend, nil
	case "piped":
		return ProtocolPiped, nil
	case "custom", "":
		return ProtocolCustom, nil
	default:
		return "", fmt.Errorf("%w: %s", ErrInvalidProtocol, s)
	}
}

type Manifest struct {
	ID              string            `json:"id"`
	Name            string            `json:"name"`
	Description     string            `json:"description"`
	Version         string            `json:"version"`
	Author          string            `json:"author"`
	Kind            Kind              `json:"kind"`
	BaseURL         string            `json:"baseUrl"`
	Protocol        Protocol          `json:"protocol"`
	Homepage        string            `json:"homepage,omitempty"`
	MinAppVersion   string            `json:"minAppVersion,omitempty"`
	APIVersion      string            `json:"apiVersion,omitempty"`
	Capabilities    []string          `json:"capabilities"`
	Permissions     []string          `json:"permissions"`
	NetworkDomains  []string          `json:"networkDomains"`
	HealthPath      string            `json:"healthPath,omitempty"`
	HealthMethod    string            `json:"healthMethod,omitempty"`
	StorageQuota    int64             `json:"storageQuota,omitempty"`
	MaxPackageSize  int64             `json:"maxPackageSize,omitempty"`
	EntryPoint      string            `json:"entryPoint,omitempty"`
	Scripts         map[string]string `json:"scripts,omitempty"`
	Dependencies    map[string]string `json:"dependencies,omitempty"`
}

func (m *Manifest) UnmarshalJSON(data []byte) error {
	type Alias Manifest
	aux := &struct {
		*Alias
		Kind     string `json:"kind"`
		Protocol string `json:"protocol"`
	}{
		Alias: (*Alias)(m),
	}
	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}

	kind, err := ParseKind(aux.Kind)
	if err != nil {
		return err
	}
	m.Kind = kind

	protocol, err := ParseProtocol(aux.Protocol)
	if err != nil {
		return err
	}
	m.Protocol = protocol

	if m.HealthMethod == "" {
		m.HealthMethod = "GET"
	}
	if m.HealthPath == "" {
		m.HealthPath = "/"
	}
	if m.APIVersion == "" {
		m.APIVersion = "1"
	}

	return m.validate()
}

func (m *Manifest) validate() error {
	if err := validateID(m.ID); err != nil {
		return err
	}
	if strings.TrimSpace(m.Name) == "" {
		return ErrInvalidName
	}
	if err := validateBaseURL(m.BaseURL); err != nil {
		return err
	}
	if err := validateVersion(m.Version); err != nil {
		return err
	}
	if m.Kind == "" {
		return fmt.Errorf("%w: kind is required", ErrInvalidManifest)
	}
	if m.Protocol == "" {
		m.Protocol = ProtocolCustom
	}
	if len(m.Capabilities) == 0 {
		m.Capabilities = inferCapabilities(m.Kind)
	}
	if m.MaxPackageSize == 0 {
		m.MaxPackageSize = 50 * 1024 * 1024
	}
	if m.StorageQuota == 0 {
		m.StorageQuota = 100 * 1024 * 1024
	}
	if m.EntryPoint == "" {
		m.EntryPoint = "index.js"
	}
	return nil
}

func validateID(id string) error {
	id = strings.TrimSpace(strings.ToLower(id))
	if id == "" {
		return ErrInvalidID
	}
	matched, _ := regexp.MatchString(`^[a-z0-9._-]+$`, id)
	if !matched {
		return fmt.Errorf("%w: %s (only lowercase alphanumeric, ., _, - allowed)", ErrInvalidID, id)
	}
	return nil
}

func validateBaseURL(baseURL string) error {
	baseURL = strings.TrimSpace(baseURL)
	if baseURL == "" {
		return ErrInvalidBaseURL
	}
	u, err := url.Parse(baseURL)
	if err != nil || u.Scheme == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return fmt.Errorf("%w: %s", ErrInvalidBaseURL, baseURL)
	}
	if u.Host == "" {
		return fmt.Errorf("%w: missing host", ErrInvalidBaseURL)
	}
	return nil
}

func validateVersion(version string) error {
	version = strings.TrimSpace(version)
	if version == "" {
		return ErrInvalidVersion
	}
	return nil
}

func inferCapabilities(kind Kind) []string {
	switch kind {
	case KindBackend:
		return []string{"search", "metadata", "stream", "download"}
	case KindHifi:
		return []string{"search", "metadata", "stream", "download", "lossless"}
	case KindMetadata:
		return []string{"metadata"}
	case KindLyrics:
		return []string{"lyrics"}
	case KindStream:
		return []string{"stream"}
	case KindDownload:
		return []string{"download"}
	default:
		return []string{}
	}
}

func (m *Manifest) HasCapability(cap string) bool {
	for _, c := range m.Capabilities {
		if c == cap {
			return true
		}
	}
	return false
}

func (m *Manifest) IsURLAllowed(rawURL string) bool {
	if len(m.NetworkDomains) == 0 {
		return true
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	host := strings.ToLower(u.Host)
	for _, allowed := range m.NetworkDomains {
		allowed = strings.ToLower(allowed)
		if host == allowed || strings.HasSuffix(host, "."+allowed) {
			return true
		}
	}
	return false
}

func (m *Manifest) HealthURL() string {
	base := strings.TrimRight(m.BaseURL, "/")
	path := m.HealthPath
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	return base + path
}

func ParseManifest(data []byte) (*Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return &m, nil
}

type RegistryEntry struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	URL         string    `json:"url"`
	Version     string    `json:"version,omitempty"`
	Description string    `json:"description,omitempty"`
	Kind        Kind      `json:"kind,omitempty"`
	Author      string    `json:"author,omitempty"`
	UpdatedAt   time.Time `json:"updatedAt,omitempty"`
}

type Registry struct {
	Name      string           `json:"name"`
	Entries   []RegistryEntry  `json:"extensions"`
	UpdatedAt time.Time        `json:"updatedAt,omitempty"`
}

func ParseRegistry(data []byte, baseURL string) (*Registry, error) {
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("invalid registry json: %w", err)
	}

	name, _ := raw["name"].(string)
	if name == "" {
		name = baseURL
	}

	var entries []RegistryEntry
	if rawExts, ok := raw["extensions"].([]interface{}); ok {
		for _, item := range rawExts {
			if m, ok := item.(map[string]interface{}); ok {
				entry := parseRegistryEntry(m, baseURL)
				if entry != nil {
					entries = append(entries, *entry)
				}
			}
		}
	}

	updatedAt := time.Time{}
	if ts, ok := raw["updatedAt"].(string); ok {
		if t, err := time.Parse(time.RFC3339, ts); err == nil {
			updatedAt = t
		}
	}

	return &Registry{
		Name:      name,
		Entries:   entries,
		UpdatedAt: updatedAt,
	}, nil
}

func parseRegistryEntry(m map[string]interface{}, baseURL string) *RegistryEntry {
	rawURL := getString(m, "url", "manifest_url", "file")
	if rawURL == "" {
		return nil
	}

	resolvedURL := resolveURL(rawURL, baseURL)
	if resolvedURL == "" {
		return nil
	}

	u, err := url.Parse(resolvedURL)
	if err != nil {
		return nil
	}

	id := strings.TrimSpace(strings.ToLower(getString(m, "id")))
	if id == "" {
		for _, seg := range strings.Split(u.Path, "/") {
			if strings.HasSuffix(seg, ".json") {
				id = strings.TrimSuffix(seg, ".json")
				break
			}
		}
	}
	if id == "" {
		return nil
	}
	id = regexp.MustCompile(`[^a-z0-9._-]`).ReplaceAllString(id, "")

	name := getString(m, "name")
	if name == "" {
		name = id
	}

	kindStr := getString(m, "kind")
	kind, _ := ParseKind(kindStr)

	return &RegistryEntry{
		ID:          id,
		Name:        name,
		URL:         resolvedURL,
		Version:     getString(m, "version"),
		Description: getString(m, "description"),
		Kind:        kind,
		Author:      getString(m, "author"),
	}
}

func getString(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k].(string); ok && v != "" {
			return v
		}
	}
	return ""
}

func resolveURL(raw, baseURL string) string {
	u, err := url.Parse(raw)
	if err == nil && u.Scheme != "" && (u.Scheme == "http" || u.Scheme == "https") {
		return raw
	}
	if baseURL == "" {
		return ""
	}
	base, err := url.Parse(baseURL)
	if err != nil {
		return ""
	}
	return base.ResolveReference(u).String()
}