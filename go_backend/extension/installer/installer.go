package installer

import (
	"archive/zip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"melodi/go_backend/extension/manifest"
	"melodi/go_backend/extension/storage"
	"melodi/go_backend/network"
)

var (
	ErrInvalidPackage      = errors.New("installer: invalid package")
	ErrChecksumMismatch    = errors.New("installer: checksum mismatch")
	ErrPathTraversal       = errors.New("installer: path traversal in package")
	ErrSymlinkInPackage    = errors.New("installer: symlink in package")
	ErrDuplicateEntry      = errors.New("installer: duplicate entry in package")
	ErrPackageTooLarge     = errors.New("installer: package exceeds max size")
	ErrManifestMissing     = errors.New("installer: manifest.json not found")
	ErrEntryPointMissing   = errors.New("installer: entry point not found")
	ErrVersionIncompatible = errors.New("installer: version incompatible")
	ErrDownloadFailed      = errors.New("installer: download failed")
)

type InstallOptions struct {
	PackageURL         string
	PackagePath        string
	ExpectedSHA256     string
	MaxPackageSize     int64
	StorageRoot        string
	StorageQuota       int64
	MaxFileSize        int64
	MinAppVersion      string
	CurrentAppVersion  string
	APIVersion         string
	Force              bool
}

type InstallResult struct {
	Manifest       *manifest.Manifest
	PackagePath    string
	ExtractedPath  string
	SHA256         string
	Size           int64
	InstalledAt    time.Time
}

type Installer struct {
	httpClient *network.HTTPClient
	storage    storage.Storage
	options    InstallOptions
}

func NewInstaller(httpClient *network.HTTPClient, storage storage.Storage, options InstallOptions) *Installer {
	return &Installer{
		httpClient: httpClient,
		storage:    storage,
		options:    options,
	}
}

func (i *Installer) Install(ctx context.Context, opts InstallOptions) (*InstallResult, error) {
	if opts.PackageURL != "" {
		return i.installFromURL(ctx, opts)
	}
	if opts.PackagePath != "" {
		return i.installFromPath(ctx, opts)
	}
	return nil, ErrInvalidPackage
}

func (i *Installer) installFromURL(ctx context.Context, opts InstallOptions) (*InstallResult, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", opts.PackageURL, nil)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDownloadFailed, err)
	}

	resp, err := i.httpClient.Do(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDownloadFailed, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%w: HTTP %d", ErrDownloadFailed, resp.StatusCode)
	}

	maxSize := opts.MaxPackageSize
	if maxSize == 0 {
		maxSize = 50 * 1024 * 1024
	}

	tmpDir, err := os.MkdirTemp("", "melodi-ext-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	tmpFile := filepath.Join(tmpDir, "package.sflx")
	out, err := os.Create(tmpFile)
	if err != nil {
		return nil, fmt.Errorf("failed to create temp file: %w", err)
	}

	written, err := io.Copy(out, io.LimitReader(resp.Body, maxSize+1))
	out.Close()
	if err != nil {
		return nil, fmt.Errorf("failed to write package: %w", err)
	}
	if written > maxSize {
		return nil, ErrPackageTooLarge
	}

	return i.installFromPath(ctx, InstallOptions{
		PackagePath:        tmpFile,
		ExpectedSHA256:     opts.ExpectedSHA256,
		MaxPackageSize:     maxSize,
		StorageRoot:        opts.StorageRoot,
		StorageQuota:       opts.StorageQuota,
		MaxFileSize:        opts.MaxFileSize,
		MinAppVersion:      opts.MinAppVersion,
		CurrentAppVersion:  opts.CurrentAppVersion,
		APIVersion:         opts.APIVersion,
		Force:              opts.Force,
	})
}

func (i *Installer) installFromPath(ctx context.Context, opts InstallOptions) (*InstallResult, error) {
	data, err := os.ReadFile(opts.PackagePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read package: %w", err)
	}

	if opts.ExpectedSHA256 != "" {
		actual := calculateSHA256(data)
		if !strings.EqualFold(actual, opts.ExpectedSHA256) {
			return nil, fmt.Errorf("%w: expected %s, got %s", ErrChecksumMismatch, opts.ExpectedSHA256, actual)
		}
	}

	maxSize := opts.MaxPackageSize
	if maxSize == 0 {
		maxSize = 50 * 1024 * 1024
	}
	if int64(len(data)) > maxSize {
		return nil, ErrPackageTooLarge
	}

	tmpDir, err := os.MkdirTemp("", "melodi-ext-extract-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create extract dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	if err := extractAndValidateZip(data, tmpDir, opts.MaxPackageSize); err != nil {
		return nil, err
	}

	manifestPath := filepath.Join(tmpDir, "manifest.json")
	manifestData, err := os.ReadFile(manifestPath)
	if err != nil {
		return nil, ErrManifestMissing
	}

	m, err := manifest.ParseManifest(manifestData)
	if err != nil {
		return nil, fmt.Errorf("invalid manifest: %w", err)
	}

	if opts.MinAppVersion != "" && opts.CurrentAppVersion != "" {
		if !isVersionCompatible(opts.CurrentAppVersion, opts.MinAppVersion) {
			return nil, fmt.Errorf("%w: requires app version %s, current %s", ErrVersionIncompatible, opts.MinAppVersion, opts.CurrentAppVersion)
		}
	}

	if opts.APIVersion != "" && m.APIVersion != "" {
		if m.APIVersion != opts.APIVersion {
			return nil, fmt.Errorf("%w: extension API version %s, core expects %s", ErrVersionIncompatible, m.APIVersion, opts.APIVersion)
		}
	}

	entryPoint := m.EntryPoint
	if entryPoint == "" {
		entryPoint = "index.js"
	}
	entryPath := filepath.Join(tmpDir, entryPoint)
	if _, err := os.Stat(entryPath); os.IsNotExist(err) {
		return nil, ErrEntryPointMissing
	}

	extStorageRoot := filepath.Join(opts.StorageRoot, "extensions", m.ID)
	extStorage, err := storage.NewStorage(extStorageRoot, opts.StorageQuota, opts.MaxFileSize)
	if err != nil {
		return nil, fmt.Errorf("failed to create extension storage: %w", err)
	}

	if err := copyExtractedFiles(tmpDir, extStorage); err != nil {
		return nil, fmt.Errorf("failed to copy extension files: %w", err)
	}

	manifestJSON, _ := json.Marshal(m)
	extStorage.WriteFile("manifest.json", manifestJSON)

	return &InstallResult{
		Manifest:       m,
		PackagePath:    opts.PackagePath,
		ExtractedPath:  extStorageRoot,
		SHA256:         calculateSHA256(data),
		Size:           int64(len(data)),
		InstalledAt:    time.Now(),
	}, nil
}

func extractAndValidateZip(data []byte, destDir string, maxSize int64) error {
	tmpZip := filepath.Join(destDir, "package.zip")
	if err := os.WriteFile(tmpZip, data, 0640); err != nil {
		return err
	}
	defer os.Remove(tmpZip)

	reader, err := zip.OpenReader(tmpZip)
	if err != nil {
		return fmt.Errorf("%w: not a valid zip file", ErrInvalidPackage)
	}
	defer reader.Close()

	var totalSize int64
	seen := make(map[string]bool)

	for _, f := range reader.File {
		if f.FileInfo().IsDir() {
			continue
		}

		if f.Name == "" || strings.Contains(f.Name, "..") || filepath.IsAbs(f.Name) {
			return ErrPathTraversal
		}

		if f.FileInfo().Mode()&os.ModeSymlink != 0 {
			return ErrSymlinkInPackage
		}

		cleanName := filepath.Clean(f.Name)
		if seen[cleanName] {
			return ErrDuplicateEntry
		}
		seen[cleanName] = true

		totalSize += f.FileInfo().Size()
		if totalSize > maxSize {
			return ErrPackageTooLarge
		}

		rc, err := f.Open()
		if err != nil {
			return fmt.Errorf("failed to open zip entry: %w", err)
		}

		destPath := filepath.Join(destDir, cleanName)
		if err := os.MkdirAll(filepath.Dir(destPath), 0750); err != nil {
			rc.Close()
			return err
		}

		out, err := os.OpenFile(destPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0640)
		if err != nil {
			rc.Close()
			return err
		}

		_, err = io.Copy(out, io.LimitReader(rc, maxSize-totalSize+f.FileInfo().Size()))
		rc.Close()
		out.Close()
		if err != nil {
			return fmt.Errorf("failed to extract file: %w", err)
		}
	}

	if !seen["manifest.json"] {
		return ErrManifestMissing
	}

	return nil
}

func copyExtractedFiles(srcDir string, dst storage.Storage) error {
	return filepath.WalkDir(srcDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		relPath, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}

		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}

		return dst.WriteFile(relPath, data)
	})
}

func calculateSHA256(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func isVersionCompatible(current, required string) bool {
	currentParts := parseVersion(current)
	requiredParts := parseVersion(required)

	for i := 0; i < 3; i++ {
		c := 0
		r := 0
		if i < len(currentParts) {
			c = currentParts[i]
		}
		if i < len(requiredParts) {
			r = requiredParts[i]
		}
		if c > r {
			return true
		}
		if c < r {
			return false
		}
	}
	return true
}

func parseVersion(v string) []int {
	v = strings.TrimPrefix(v, "v")
	parts := strings.Split(v, ".")
	result := make([]int, 0, 3)
	for _, p := range parts {
		var n int
		fmt.Sscanf(p, "%d", &n)
		result = append(result, n)
	}
	return result
}