package main

import (
	"context"
	"encoding/json"
	"fmt"
	"melodi/go_backend/exports"
	"runtime"
	"sync"
	"time"
	"unsafe"

	"C"
)

var (
	core       *exports.Core
	coreMu     sync.RWMutex
	initialized bool
)

func main() {}

func init() {
	runtime.LockOSThread()
}

func Initialize(storageRoot string) int32 {
	coreMu.Lock()
	defer coreMu.Unlock()

	if initialized {
		return 0
	}

	config := exports.DefaultCoreConfig()
	config.StorageRoot = storageRoot
	config.DownloadStorageRoot = storageRoot

	var err error
	core, err = exports.NewCore(config)
	if err != nil {
		fmt.Printf("Failed to create core: %v\n", err)
		return -1
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := core.Initialize(ctx); err != nil {
		fmt.Printf("Failed to initialize core: %v\n", err)
		return -1
	}

	initialized = true
	return 0
}

func Version() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString("")
	}
	return C.CString(core.Version())
}

func APIVersion() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString("")
	}
	return C.CString(core.APIVersion())
}

func Ping() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString("")
	}
	return C.CString(core.Ping())
}

func Search(requestJSON *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	var req exports.SearchRequest
	if err := json.Unmarshal([]byte(C.GoString(requestJSON)), &req); err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	resp, err := core.Search(ctx, req)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func Match(requestJSON *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	var req exports.MatchRequest
	if err := json.Unmarshal([]byte(C.GoString(requestJSON)), &req); err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	resp, err := core.Match(ctx, req)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func Resolve(requestJSON *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	var req exports.ResolveRequest
	if err := json.Unmarshal([]byte(C.GoString(requestJSON)), &req); err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	resp, err := core.Resolve(ctx, req)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func Download(requestJSON *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	var req exports.DownloadRequest
	if err := json.Unmarshal([]byte(C.GoString(requestJSON)), &req); err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	resp, err := core.Download(ctx, req)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func CancelDownload(jobID *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}
	ctx := context.Background()
	core.CancelDownload(ctx, C.GoString(jobID))
}

func GetDownloadStatus(jobID *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	status, err := core.GetDownloadStatus(ctx, C.GoString(jobID))
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}
	if status == nil {
		return C.CString(`{"error":"not found"}`)
	}

	data, _ := json.Marshal(status)
	return C.CString(string(data))
}

func ListDownloads() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	statuses, err := core.ListDownloads(ctx)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(statuses)
	return C.CString(string(data))
}

func InstallExtension(requestJSON *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	var req exports.InstallExtensionRequest
	if err := json.Unmarshal([]byte(C.GoString(requestJSON)), &req); err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	resp, err := core.InstallExtension(ctx, req)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func UninstallExtension(id *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}
	ctx := context.Background()
	core.UninstallExtension(ctx, C.GoString(id))
}

func EnableExtension(id *C.char, enabled C.int) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}
	ctx := context.Background()
	core.EnableExtension(ctx, C.GoString(id), bool(enabled))
}

func ListExtensions() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	exts, err := core.ListExtensions(ctx)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(exts)
	return C.CString(string(data))
}

func GetExtension(id *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	ext, err := core.GetExtension(ctx, C.GoString(id))
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}
	if ext == nil {
		return C.CString(`{"error":"not found"}`)
	}

	data, _ := json.Marshal(ext)
	return C.CString(string(data))
}

func CheckExtensionHealth(id *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	health, err := core.CheckExtensionHealth(ctx, C.GoString(id))
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(map[string]string{"health": health})
	return C.CString(string(data))
}

func UpdateExtension(id *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	resp, err := core.UpdateExtension(ctx, C.GoString(id))
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func UpdateAllExtensions() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	resps, err := core.UpdateAllExtensions(ctx)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resps)
	return C.CString(string(data))
}

func AddRepository(url *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}
	ctx := context.Background()
	core.AddRepository(ctx, C.GoString(url))
}

func RemoveRepository(url *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}
	ctx := context.Background()
	core.RemoveRepository(ctx, C.GoString(url))
}

func ListRepositories() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	repos, err := core.ListRepositories(ctx)
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(repos)
	return C.CString(string(data))
}

func ReadMetadata(filePath *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	resp, err := core.ReadMetadata(ctx, exports.MetadataRequest{FilePath: C.GoString(filePath)})
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(resp)
	return C.CString(string(data))
}

func WriteMetadata(filePath *C.char, tagsJSON *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}

	ctx := context.Background()
	var tags map[string]string
	if err := json.Unmarshal([]byte(C.GoString(tagsJSON)), &tags); err != nil {
		return
	}

	core.WriteMetadata(ctx, exports.WriteMetadataRequest{FilePath: C.GoString(filePath), Tags: tags})
}

func EmbedCoverArt(filePath *C.char, imageData *C.uchar, imageLen C.int, mimeType *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}

	ctx := context.Background()
	data := C.GoBytes(unsafe.Pointer(imageData), imageLen)
	core.EmbedCoverArt(ctx, exports.CoverArtRequest{
		FilePath:  C.GoString(filePath),
		ImageData: data,
		MimeType:  C.GoString(mimeType),
	})
}

func EmbedLyrics(filePath *C.char, lyrics *C.char) {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return
	}

	ctx := context.Background()
	core.EmbedLyrics(ctx, exports.LyricsRequest{FilePath: C.GoString(filePath), Lyrics: C.GoString(lyrics)})
}

func ExtractLyrics(filePath *C.char) *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	lyrics, err := core.ExtractLyrics(ctx, C.GoString(filePath))
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(map[string]string{"lyrics": lyrics})
	return C.CString(string(data))
}

func GetStats() *C.char {
	coreMu.RLock()
	defer coreMu.RUnlock()
	if core == nil {
		return C.CString(`{"error":"not initialized"}`)
	}

	ctx := context.Background()
	stats, err := core.GetStats()
	if err != nil {
		return C.CString(fmt.Sprintf(`{"error":"%s"}`, err.Error()))
	}

	data, _ := json.Marshal(stats)
	return C.CString(string(data))
}

func Shutdown() {
	coreMu.Lock()
	defer coreMu.Unlock()
	if core != nil {
		core.Shutdown()
		core = nil
		initialized = false
	}
}