#ifndef MELODI_CORE_H
#define MELODI_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

int32_t MelodiCore_Initialize(const char* storage_root);
const char* MelodiCore_Version();
const char* MelodiCore_APIVersion();
const char* MelodiCore_Ping();
void MelodiCore_Shutdown();

const char* MelodiCore_Search(const char* request_json);
const char* MelodiCore_Match(const char* request_json);
const char* MelodiCore_Resolve(const char* request_json);
const char* MelodiCore_Download(const char* request_json);
void MelodiCore_CancelDownload(const char* job_id);
const char* MelodiCore_GetDownloadStatus(const char* job_id);
const char* MelodiCore_ListDownloads();

const char* MelodiCore_InstallExtension(const char* request_json);
void MelodiCore_UninstallExtension(const char* id);
void MelodiCore_EnableExtension(const char* id, int enabled);
const char* MelodiCore_ListExtensions();
const char* MelodiCore_GetExtension(const char* id);
const char* MelodiCore_CheckExtensionHealth(const char* id);
const char* MelodiCore_UpdateExtension(const char* id);
const char* MelodiCore_UpdateAllExtensions();

void MelodiCore_AddRepository(const char* url);
void MelodiCore_RemoveRepository(const char* url);
const char* MelodiCore_ListRepositories();

const char* MelodiCore_ReadMetadata(const char* file_path);
void MelodiCore_WriteMetadata(const char* file_path, const char* tags_json);
void MelodiCore_EmbedCoverArt(const char* file_path, const char* image_data, int image_len, const char* mime_type);
void MelodiCore_EmbedLyrics(const char* file_path, const char* lyrics);
const char* MelodiCore_ExtractLyrics(const char* file_path);
const char* MelodiCore_GetStats();

#ifdef __cplusplus
}
#endif

#endif