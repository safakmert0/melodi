package filesystem

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

var (
	ErrPathTraversal     = errors.New("filesystem: path traversal attempt")
	ErrNotFound          = errors.New("filesystem: not found")
	ErrAlreadyExists     = errors.New("filesystem: already exists")
	ErrNotDirectory      = errors.New("filesystem: not a directory")
	ErrNotFile           = errors.New("filesystem: not a file")
	ErrPermissionDenied  = errors.New("filesystem: permission denied")
	ErrQuotaExceeded     = errors.New("filesystem: quota exceeded")
)

type FileInfo struct {
	Path    string
	Name    string
	Size    int64
	ModTime time.Time
	IsDir   bool
	Mode    fs.FileMode
}

type Filesystem interface {
	MkdirAll(path string, perm os.FileMode) error
	Stat(path string) (FileInfo, error)
	ReadFile(path string) ([]byte, error)
	WriteFile(path string, data []byte, perm os.FileMode) error
	Remove(path string) error
	RemoveAll(path string) error
	Rename(oldPath, newPath string) error
	ListDir(path string) ([]FileInfo, error)
	WalkDir(root string, fn func(path string, d fs.DirEntry, err error) error) error
	DiskUsage(path string) (int64, int64, int64, error)
	CreateTempDir(pattern string) (string, error)
	CreateTempFile(dir, pattern string) (*os.File, error)
}

type SandboxFilesystem struct {
	rootPath string
	quota    int64
	mu       sync.RWMutex
	usage    int64
}

func NewSandboxFilesystem(rootPath string, quota int64) (*SandboxFilesystem, error) {
	absRoot, err := filepath.Abs(rootPath)
	if err != nil {
		return nil, err
	}

	if err := os.MkdirAll(absRoot, 0750); err != nil {
		return nil, err
	}

	return &SandboxFilesystem{
		rootPath: absRoot,
		quota:    quota,
	}, nil
}

func (s *SandboxFilesystem) validatePath(path string) (string, error) {
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
	return !filepath.IsAbs(rel) && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func (s *SandboxFilesystem) checkQuota(additional int64) error {
	if s.quota <= 0 {
		return nil
	}
	if s.usage+additional > s.quota {
		return ErrQuotaExceeded
	}
	return nil
}

func (s *SandboxFilesystem) MkdirAll(path string, perm os.FileMode) error {
	absPath, err := s.validatePath(path)
	if err != nil {
		return err
	}
	return os.MkdirAll(absPath, perm)
}

func (s *SandboxFilesystem) Stat(path string) (FileInfo, error) {
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

	relPath, _ := filepath.Rel(s.rootPath, absPath)
	return FileInfo{
		Path:    relPath,
		Name:    info.Name(),
		Size:    info.Size(),
		ModTime: info.ModTime(),
		IsDir:   info.IsDir(),
		Mode:    info.Mode(),
	}, nil
}

func (s *SandboxFilesystem) ReadFile(path string) ([]byte, error) {
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

	return data, nil
}

func (s *SandboxFilesystem) WriteFile(path string, data []byte, perm os.FileMode) error {
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

	if err := os.WriteFile(absPath, data, perm); err != nil {
		return err
	}

	s.mu.Lock()
	s.usage += int64(len(data))
	s.mu.Unlock()

	return nil
}

func (s *SandboxFilesystem) Remove(path string) error {
	absPath, err := s.validatePath(path)
	if err != nil {
		return err
	}

	info, err := os.Stat(absPath)
	if err != nil {
		if os.IsNotExist(err) {
			return ErrNotFound
		}
		return err
	}

	if err := os.Remove(absPath); err != nil {
		return err
	}

	if !info.IsDir() {
		s.mu.Lock()
		s.usage -= info.Size()
		s.mu.Unlock()
	}

	return nil
}

func (s *SandboxFilesystem) RemoveAll(path string) error {
	absPath, err := s.validatePath(path)
	if err != nil {
		return err
	}

	if _, err := os.Stat(absPath); err != nil {
		if os.IsNotExist(err) {
			return ErrNotFound
		}
		return err
	}

	var removedSize int64
	filepath.WalkDir(absPath, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() {
			if i, err := d.Info(); err == nil {
				removedSize += i.Size()
			}
		}
		return nil
	})

	if err := os.RemoveAll(absPath); err != nil {
		return err
	}

	s.mu.Lock()
	s.usage -= removedSize
	s.mu.Unlock()

	return nil
}

func (s *SandboxFilesystem) Rename(oldPath, newPath string) error {
	absOld, err := s.validatePath(oldPath)
	if err != nil {
		return err
	}

	absNew, err := s.validatePath(newPath)
	if err != nil {
		return err
	}

	return os.Rename(absOld, absNew)
}

func (s *SandboxFilesystem) ListDir(path string) ([]FileInfo, error) {
	absPath, err := s.validatePath(path)
	if err != nil {
		return nil, err
	}

	entries, err := os.ReadDir(absPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	var files []FileInfo
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}
		relPath, _ := filepath.Rel(s.rootPath, filepath.Join(absPath, entry.Name()))
		files = append(files, FileInfo{
			Path:    relPath,
			Name:    entry.Name(),
			Size:    info.Size(),
			ModTime: info.ModTime(),
			IsDir:   entry.IsDir(),
			Mode:    info.Mode(),
		})
	}

	return files, nil
}

func (s *SandboxFilesystem) WalkDir(root string, fn func(path string, d fs.DirEntry, err error) error) error {
	absRoot, err := s.validatePath(root)
	if err != nil {
		return err
	}

	return filepath.WalkDir(absRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return fn(path, d, err)
		}
		relPath, _ := filepath.Rel(s.rootPath, path)
		return fn(relPath, d, err)
	})
}

func (s *SandboxFilesystem) DiskUsage(path string) (int64, int64, int64, error) {
	if _, err := s.validatePath(path); err != nil {
		return 0, 0, 0, err
	}

	var total, used, free int64
	// This is a simplified implementation
	// In production, use syscall.Statfs or similar
	return total, used, free, nil
}

func (s *SandboxFilesystem) CreateTempDir(pattern string) (string, error) {
	return os.MkdirTemp(s.rootPath, pattern)
}

func (s *SandboxFilesystem) CreateTempFile(dir, pattern string) (*os.File, error) {
	absDir, err := s.validatePath(dir)
	if err != nil {
		return nil, err
	}
	return os.CreateTemp(absDir, pattern)
}

func (s *SandboxFilesystem) RootPath() string {
	return s.rootPath
}

func (s *SandboxFilesystem) Quota() int64 {
	return s.quota
}

func (s *SandboxFilesystem) Usage() int64 {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.usage
}

type MemoryFilesystem struct {
	mu    sync.RWMutex
	files map[string][]byte
	dirs  map[string]bool
	quota int64
	usage int64
}

func NewMemoryFilesystem(quota int64) *MemoryFilesystem {
	return &MemoryFilesystem{
		files: make(map[string][]byte),
		dirs:  map[string]bool{"": true},
		quota: quota,
	}
}

func (m *MemoryFilesystem) MkdirAll(path string, perm os.FileMode) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	parts := strings.Split(strings.Trim(path, "/"), "/")
	current := ""
	for _, part := range parts {
		if part == "" {
			continue
		}
		if current == "" {
			current = part
		} else {
			current = current + "/" + part
		}
		m.dirs[current] = true
	}
	return nil
}

func (m *MemoryFilesystem) Stat(path string) (FileInfo, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	path = strings.Trim(path, "/")
	if data, ok := m.files[path]; ok {
		return FileInfo{
			Path:    path,
			Name:    filepath.Base(path),
			Size:    int64(len(data)),
			ModTime: time.Now(),
			IsDir:   false,
			Mode:    0640,
		}, nil
	}

	if m.dirs[path] || path == "" {
		return FileInfo{
			Path:    path,
			Name:    filepath.Base(path),
			Size:    0,
			ModTime: time.Now(),
			IsDir:   true,
			Mode:    0750,
		}, nil
	}

	return FileInfo{}, ErrNotFound
}

func (m *MemoryFilesystem) ReadFile(path string) ([]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	path = strings.Trim(path, "/")
	data, ok := m.files[path]
	if !ok {
		return nil, ErrNotFound
	}
	return data, nil
}

func (m *MemoryFilesystem) WriteFile(path string, data []byte, perm os.FileMode) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	path = strings.Trim(path, "/")
	if int64(len(data)) > m.quota-m.usage {
		return ErrQuotaExceeded
	}

	m.files[path] = data
	m.usage += int64(len(data))
	return nil
}

func (m *MemoryFilesystem) Remove(path string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	path = strings.Trim(path, "/")
	data, ok := m.files[path]
	if !ok {
		return ErrNotFound
	}

	delete(m.files, path)
	m.usage -= int64(len(data))
	return nil
}

func (m *MemoryFilesystem) RemoveAll(path string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	path = strings.Trim(path, "/")
	prefix := path + "/"
	var removed int64

	for p, data := range m.files {
		if p == path || strings.HasPrefix(p, prefix) {
			removed += int64(len(data))
			delete(m.files, p)
		}
	}

	for p := range m.dirs {
		if p == path || strings.HasPrefix(p, prefix) {
			delete(m.dirs, p)
		}
	}

	m.usage -= removed
	return nil
}

func (m *MemoryFilesystem) Rename(oldPath, newPath string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	oldPath = strings.Trim(oldPath, "/")
	newPath = strings.Trim(newPath, "/")

	data, ok := m.files[oldPath]
	if !ok {
		return ErrNotFound
	}

	delete(m.files, oldPath)
	m.files[newPath] = data
	return nil
}

func (m *MemoryFilesystem) ListDir(path string) ([]FileInfo, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	path = strings.Trim(path, "/")
	prefix := path + "/"
	if path == "" {
		prefix = ""
	}

	var files []FileInfo
	for p := range m.files {
		if path == "" || strings.HasPrefix(p, prefix) {
			rel := p
			if path != "" {
				rel = strings.TrimPrefix(p, prefix)
			}
			if !strings.Contains(rel, "/") {
				data := m.files[p]
				files = append(files, FileInfo{
					Path:    p,
					Name:    filepath.Base(p),
					Size:    int64(len(data)),
					ModTime: time.Now(),
					IsDir:   false,
					Mode:    0640,
				})
			}
		}
	}

	for p := range m.dirs {
		if p == path {
			continue
		}
		if path == "" || strings.HasPrefix(p, prefix) {
			rel := p
			if path != "" {
				rel = strings.TrimPrefix(p, prefix)
			}
			if !strings.Contains(rel, "/") {
				files = append(files, FileInfo{
					Path:    p,
					Name:    filepath.Base(p),
					Size:    0,
					ModTime: time.Now(),
					IsDir:   true,
					Mode:    0750,
				})
			}
		}
	}

	return files, nil
}

func (m *MemoryFilesystem) WalkDir(root string, fn func(path string, d fs.DirEntry, err error) error) error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	root = strings.Trim(root, "/")
	prefix := root + "/"
	if root == "" {
		prefix = ""
	}

	for p := range m.files {
		if root == "" || strings.HasPrefix(p, prefix) {
			rel := p
			if root != "" {
				rel = strings.TrimPrefix(p, prefix)
			}
			if !strings.Contains(rel, "/") {
				if err := fn(rel, &memoryDirEntry{name: rel, isDir: false, data: m.files[p]}, nil); err != nil {
					return err
				}
			}
		}
	}

	return nil
}

func (m *MemoryFilesystem) DiskUsage(path string) (int64, int64, int64, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return m.quota, m.usage, m.quota - m.usage, nil
}

func (m *MemoryFilesystem) CreateTempDir(pattern string) (string, error) {
	return "", errors.New("not supported")
}

func (m *MemoryFilesystem) CreateTempFile(dir, pattern string) (*os.File, error) {
	return nil, errors.New("not supported")
}

type memoryDirEntry struct {
	name   string
	isDir  bool
	data   []byte
}

func (m *memoryDirEntry) Name() string               { return m.name }
func (m *memoryDirEntry) IsDir() bool                { return m.isDir }
func (m *memoryDirEntry) Type() fs.FileMode          { return 0 }
func (m *memoryDirEntry) Info() (fs.FileInfo, error) { return nil, nil }

func NewFilesystem(rootPath string, quota int64) (Filesystem, error) {
	if rootPath == ":memory:" || rootPath == "" {
		return NewMemoryFilesystem(quota), nil
	}
	return NewSandboxFilesystem(rootPath, quota)
}

type DuplicateDetector struct {
	hashes map[string][]string
	mu     sync.RWMutex
}

func NewDuplicateDetector() *DuplicateDetector {
	return &DuplicateDetector{
		hashes: make(map[string][]string),
	}
}

func (d *DuplicateDetector) Add(path string, hash string) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.hashes[hash] = append(d.hashes[hash], path)
}

func (d *DuplicateDetector) FindDuplicates(hash string) []string {
	d.mu.RLock()
	defer d.mu.RUnlock()
	result := make([]string, len(d.hashes[hash]))
	copy(result, d.hashes[hash])
	return result
}

func (d *DuplicateDetector) FindAllDuplicates() map[string][]string {
	d.mu.RLock()
	defer d.mu.RUnlock()

	result := make(map[string][]string)
	for hash, paths := range d.hashes {
		if len(paths) > 1 {
			result[hash] = paths
		}
	}
	return result
}

func (d *DuplicateDetector) Remove(path string, hash string) {
	d.mu.Lock()
	defer d.mu.Unlock()

	paths := d.hashes[hash]
	for i, p := range paths {
		if p == path {
			d.hashes[hash] = append(paths[:i], paths[i+1:]...)
			break
		}
	}
	if len(d.hashes[hash]) == 0 {
		delete(d.hashes, hash)
	}
}

func (d *DuplicateDetector) Clear() {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.hashes = make(map[string][]string)
}