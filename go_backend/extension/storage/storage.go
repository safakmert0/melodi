package storage

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	ErrStorageQuotaExceeded = errors.New("storage: quota exceeded")
	ErrPathTraversal        = errors.New("storage: path traversal attempt")
	ErrFileTooLarge         = errors.New("storage: file too large")
	ErrNotFound             = errors.New("storage: not found")
	ErrAlreadyExists        = errors.New("storage: already exists")
)

type Storage interface {
	Get(key string) (string, error)
	Set(key, value string) error
	Delete(key string) error
	Clear() error
	List(prefix string) ([]string, error)

	ReadFile(path string) ([]byte, error)
	WriteFile(path string, data []byte) error
	DeleteFile(path string) error
	StatFile(path string) (FileInfo, error)
	ListFiles(prefix string) ([]FileInfo, error)
	Usage() (int64, error)
	Quota() int64
}

type FileInfo struct {
	Path    string
	Size    int64
	ModTime time.Time
	IsDir   bool
}

type SandboxStorage struct {
	rootPath   string
	quota      int64
	maxFileSize int64
	mu         sync.RWMutex
	kvStore    map[string]string
}

func NewSandboxStorage(rootPath string, quota, maxFileSize int64) (*SandboxStorage, error) {
	if err := os.MkdirAll(rootPath, 0750); err != nil {
		return nil, fmt.Errorf("failed to create storage root: %w", err)
	}
	absRoot, err := filepath.Abs(rootPath)
	if err != nil {
		return nil, err
	}
	return &SandboxStorage{
		rootPath:     absRoot,
		quota:        quota,
		maxFileSize:  maxFileSize,
		kvStore:      make(map[string]string),
	}, nil
}

func (s *SandboxStorage) validatePath(path string) (string, error) {
	if path == "" {
		return "", ErrPathTraversal
	}

	cleanPath := filepath.Clean(path)
	if cleanPath == "." || cleanPath == ".." || filepath.IsAbs(cleanPath) {
		return "", ErrPathTraversal
	}

	absPath := filepath.Join(s.rootPath, cleanPath)
	absRoot := s.rootPath

	if absPath != absRoot && !isSubPath(absPath, absRoot) {
		return "", ErrPathTraversal
	}

	return absPath, nil
}

func isSubPath(path, root string) bool {
	rel, err := filepath.Rel(root, path)
	if err != nil {
		return false
	}
	return !filepath.IsAbs(rel) && rel != ".." && !filepath.HasPrefix(rel, ".."+string(filepath.Separator))
}

func (s *SandboxStorage) Get(key string) (string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.kvStore[key], nil
}

func (s *SandboxStorage) Set(key, value string) error {
	if len(value) > int(s.maxFileSize) {
		return ErrFileTooLarge
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.kvStore[key] = value
	return nil
}

func (s *SandboxStorage) Delete(key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.kvStore, key)
	return nil
}

func (s *SandboxStorage) Clear() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.kvStore = make(map[string]string)
	return nil
}

func (s *SandboxStorage) List(prefix string) ([]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var keys []string
	for k := range s.kvStore {
		if prefix == "" || len(k) >= len(prefix) && k[:len(prefix)] == prefix {
			keys = append(keys, k)
		}
	}
	return keys, nil
}

func (s *SandboxStorage) ReadFile(path string) ([]byte, error) {
	absPath, err := s.validatePath(path)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(absPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if int64(len(data)) > s.maxFileSize {
		return nil, ErrFileTooLarge
	}
	return data, nil
}

func (s *SandboxStorage) WriteFile(path string, data []byte) error {
	if int64(len(data)) > s.maxFileSize {
		return ErrFileTooLarge
	}

	absPath, err := s.validatePath(path)
	if err != nil {
		return err
	}

	if err := s.checkQuota(int64(len(data))); err != nil {
		return err
	}

	dir := filepath.Dir(absPath)
	if err := os.MkdirAll(dir, 0750); err != nil {
		return err
	}

	return os.WriteFile(absPath, data, 0640)
}

func (s *SandboxStorage) DeleteFile(path string) error {
	absPath, err := s.validatePath(path)
	if err != nil {
		return err
	}
	if err := os.Remove(absPath); err != nil {
		if os.IsNotExist(err) {
			return ErrNotFound
		}
		return err
	}
	return nil
}

func (s *SandboxStorage) StatFile(path string) (FileInfo, error) {
	absPath, err := s.validatePath(path)
	if err != nil {
		return FileInfo{}, err
	}
	info, err := os.Stat(absPath)
	if err != nil {
		if os.IsNotExist(err) {
			return FileInfo{}, ErrNotFound
		}
		return FileInfo{}, err
	}
	return FileInfo{
		Path:    path,
		Size:    info.Size(),
		ModTime: info.ModTime(),
		IsDir:   info.IsDir(),
	}, nil
}

func (s *SandboxStorage) ListFiles(prefix string) ([]FileInfo, error) {
	var files []FileInfo
	prefixPath, err := s.validatePath(prefix)
	if err != nil && prefix != "" {
		return nil, err
	}

	err = filepath.WalkDir(prefixPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		relPath, _ := filepath.Rel(s.rootPath, path)
		files = append(files, FileInfo{
			Path:    relPath,
			Size:    info.Size(),
			ModTime: info.ModTime(),
			IsDir:   d.IsDir(),
		})
		return nil
	})
	return files, err
}

func (s *SandboxStorage) Usage() (int64, error) {
	var total int64
	err := filepath.WalkDir(s.rootPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() {
			info, _ := d.Info()
			total += info.Size()
		}
		return nil
	})
	return total, err
}

func (s *SandboxStorage) Quota() int64 {
	return s.quota
}

func (s *SandboxStorage) checkQuota(additional int64) error {
	usage, err := s.Usage()
	if err != nil {
		return err
	}
	if usage+additional > s.quota {
		return ErrStorageQuotaExceeded
	}
	return nil
}

type MemoryStorage struct {
	mu      sync.RWMutex
	kvStore map[string]string
	files   map[string][]byte
	quota   int64
	maxFile int64
	usage   int64
}

func NewMemoryStorage(quota, maxFileSize int64) *MemoryStorage {
	return &MemoryStorage{
		kvStore:  make(map[string]string),
		files:    make(map[string][]byte),
		quota:    quota,
		maxFile:  maxFileSize,
		usage:    0,
	}
}

func (m *MemoryStorage) Get(key string) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.kvStore[key], nil
}

func (m *MemoryStorage) Set(key, value string) error {
	if int64(len(value)) > m.maxFile {
		return ErrFileTooLarge
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	oldLen := int64(len(m.kvStore[key]))
	m.kvStore[key] = value
	m.usage += int64(len(value)) - oldLen
	return nil
}

func (m *MemoryStorage) Delete(key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	oldLen := int64(len(m.kvStore[key]))
	delete(m.kvStore, key)
	m.usage -= oldLen
	return nil
}

func (m *MemoryStorage) Clear() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.kvStore = make(map[string]string)
	m.usage = 0
	return nil
}

func (m *MemoryStorage) List(prefix string) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var keys []string
	for k := range m.kvStore {
		if prefix == "" || len(k) >= len(prefix) && k[:len(prefix)] == prefix {
			keys = append(keys, k)
		}
	}
	return keys, nil
}

func (m *MemoryStorage) ReadFile(path string) ([]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	data, ok := m.files[path]
	if !ok {
		return nil, ErrNotFound
	}
	return data, nil
}

func (m *MemoryStorage) WriteFile(path string, data []byte) error {
	if int64(len(data)) > m.maxFile {
		return ErrFileTooLarge
	}
	if err := m.checkQuota(int64(len(data))); err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	oldLen := int64(0)
	if old, ok := m.files[path]; ok {
		oldLen = int64(len(old))
	}
	m.files[path] = data
	m.usage += int64(len(data)) - oldLen
	return nil
}

func (m *MemoryStorage) DeleteFile(path string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, ok := m.files[path]
	if !ok {
		return ErrNotFound
	}
	delete(m.files, path)
	m.usage -= int64(len(data))
	return nil
}

func (m *MemoryStorage) StatFile(path string) (FileInfo, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	data, ok := m.files[path]
	if !ok {
		return FileInfo{}, ErrNotFound
	}
	return FileInfo{
		Path:    path,
		Size:    int64(len(data)),
		ModTime: time.Now(),
		IsDir:   false,
	}, nil
}

func (m *MemoryStorage) ListFiles(prefix string) ([]FileInfo, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var files []FileInfo
	for path, data := range m.files {
		if prefix == "" || len(path) >= len(prefix) && path[:len(prefix)] == prefix {
			files = append(files, FileInfo{
				Path:    path,
				Size:    int64(len(data)),
				ModTime: time.Now(),
				IsDir:   false,
			})
		}
	}
	return files, nil
}

func (m *MemoryStorage) Usage() (int64, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.usage, nil
}

func (m *MemoryStorage) Quota() int64 {
	return m.quota
}

func (m *MemoryStorage) checkQuota(additional int64) error {
	if m.usage+additional > m.quota {
		return ErrStorageQuotaExceeded
	}
	return nil
}

func NewStorage(rootPath string, quota, maxFileSize int64) (Storage, error) {
	if rootPath == ":memory:" || rootPath == "" {
		return NewMemoryStorage(quota, maxFileSize), nil
	}
	return NewSandboxStorage(rootPath, quota, maxFileSize)
}

type ExtensionStorage struct {
	Storage
	extID string
}

func (e *ExtensionStorage) WithPrefix(prefix string) *ExtensionStorage {
	return &ExtensionStorage{
		Storage: e.Storage,
		extID:   e.extID + "/" + prefix,
	}
}

func (e *ExtensionStorage) prefixKey(key string) string {
	return e.extID + "/" + key
}

func (e *ExtensionStorage) Get(key string) (string, error) {
	return e.Storage.Get(e.prefixKey(key))
}

func (e *ExtensionStorage) Set(key, value string) error {
	return e.Storage.Set(e.prefixKey(key), value)
}

func (e *ExtensionStorage) Delete(key string) error {
	return e.Storage.Delete(e.prefixKey(key))
}

func (e *ExtensionStorage) Clear() error {
	keys, _ := e.Storage.List(e.extID + "/")
	for _, k := range keys {
		e.Storage.Delete(k)
	}
	return nil
}

func (e *ExtensionStorage) List(prefix string) ([]string, error) {
	return e.Storage.List(e.prefixKey(prefix))
}

func (e *ExtensionStorage) ReadFile(path string) ([]byte, error) {
	return e.Storage.ReadFile(e.prefixKey(path))
}

func (e *ExtensionStorage) WriteFile(path string, data []byte) error {
	return e.Storage.WriteFile(e.prefixKey(path), data)
}

func (e *ExtensionStorage) DeleteFile(path string) error {
	return e.Storage.DeleteFile(e.prefixKey(path))
}

func (e *ExtensionStorage) StatFile(path string) (FileInfo, error) {
	return e.Storage.StatFile(e.prefixKey(path))
}

func (e *ExtensionStorage) ListFiles(prefix string) ([]FileInfo, error) {
	return e.Storage.ListFiles(e.prefixKey(prefix))
}