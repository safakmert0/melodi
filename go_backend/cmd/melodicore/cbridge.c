#include <stdlib.h>
#include <string.h>
#include "melodi_core.h"

static char* g_last_error = NULL;
static char* g_last_result = NULL;

void set_last_result(const char* result) {
    if (g_last_result) {
        free(g_last_result);
    }
    if (result) {
        g_last_result = strdup(result);
    } else {
        g_last_result = NULL;
    }
}

void set_last_error(const char* error) {
    if (g_last_error) {
        free(g_last_error);
    }
    if (error) {
        g_last_error = strdup(error);
    } else {
        g_last_error = NULL;
    }
}

int32_t MelodiCore_Initialize(const char* storage_root) {
    return Initialize(storage_root);
}

const char* MelodiCore_Version() {
    return Version();
}

const char* MelodiCore_APIVersion() {
    return APIVersion();
}

const char* MelodiCore_Ping() {
    return Ping();
}

void MelodiCore_Shutdown() {
    Shutdown();
}

const char* MelodiCore_Search(const char* request_json) {
    const char* result = Search(request_json);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_Match(const char* request_json) {
    const char* result = Match(request_json);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_Resolve(const char* request_json) {
    const char* result = Resolve(request_json);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_Download(const char* request_json) {
    const char* result = Download(request_json);
    set_last_result(result);
    return g_last_result;
}

void MelodiCore_CancelDownload(const char* job_id) {
    CancelDownload(job_id);
}

const char* MelodiCore_GetDownloadStatus(const char* job_id) {
    const char* result = GetDownloadStatus(job_id);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_ListDownloads() {
    const char* result = ListDownloads();
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_InstallExtension(const char* request_json) {
    const char* result = InstallExtension(request_json);
    set_last_result(result);
    return g_last_result;
}

void MelodiCore_UninstallExtension(const char* id) {
    UninstallExtension(id);
}

void MelodiCore_EnableExtension(const char* id, int enabled) {
    EnableExtension(id, enabled);
}

const char* MelodiCore_ListExtensions() {
    const char* result = ListExtensions();
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_GetExtension(const char* id) {
    const char* result = GetExtension(id);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_CheckExtensionHealth(const char* id) {
    const char* result = CheckExtensionHealth(id);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_UpdateExtension(const char* id) {
    const char* result = UpdateExtension(id);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_UpdateAllExtensions() {
    const char* result = UpdateAllExtensions();
    set_last_result(result);
    return g_last_result;
}

void MelodiCore_AddRepository(const char* url) {
    AddRepository(url);
}

void MelodiCore_RemoveRepository(const char* url) {
    RemoveRepository(url);
}

const char* MelodiCore_ListRepositories() {
    const char* result = ListRepositories();
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_ReadMetadata(const char* file_path) {
    const char* result = ReadMetadata(file_path);
    set_last_result(result);
    return g_last_result;
}

void MelodiCore_WriteMetadata(const char* file_path, const char* tags_json) {
    WriteMetadata(file_path, tags_json);
}

void MelodiCore_EmbedCoverArt(const char* file_path, const char* image_data, int image_len, const char* mime_type) {
    EmbedCoverArt(file_path, image_data, image_len, mime_type);
}

void MelodiCore_EmbedLyrics(const char* file_path, const char* lyrics) {
    EmbedLyrics(file_path, lyrics);
}

const char* MelodiCore_ExtractLyrics(const char* file_path) {
    const char* result = ExtractLyrics(file_path);
    set_last_result(result);
    return g_last_result;
}

const char* MelodiCore_GetStats() {
    const char* result = GetStats();
    set_last_result(result);
    return g_last_result;
}