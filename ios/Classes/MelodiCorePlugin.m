#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

extern int MelodiCore_Init(const char* storage_root);
extern const char* MelodiCore_Version();
extern const char* MelodiCore_APIVersion();
extern const char* MelodiCore_Ping();
extern void MelodiCore_Shutdown();
extern const char* MelodiCore_Search(const char* request_json);
extern const char* MelodiCore_Match(const char* request_json);
extern const char* MelodiCore_Resolve(const char* request_json);
extern const char* MelodiCore_Download(const char* request_json);
extern void MelodiCore_CancelDownload(const char* job_id);
extern const char* MelodiCore_GetDownloadStatus(const char* job_id);
extern const char* MelodiCore_ListDownloads();
extern const char* MelodiCore_InstallExtension(const char* request_json);
extern void MelodiCore_UninstallExtension(const char* id);
extern void MelodiCore_EnableExtension(const char* id, int enabled);
extern const char* MelodiCore_ListExtensions();
extern const char* MelodiCore_GetExtension(const char* id);
extern const char* MelodiCore_CheckExtensionHealth(const char* id);
extern const char* MelodiCore_UpdateExtension(const char* id);
extern const char* MelodiCore_UpdateAllExtensions();
extern void MelodiCore_AddRepository(const char* url);
extern void MelodiCore_RemoveRepository(const char* url);
extern const char* MelodiCore_ListRepositories();
extern const char* MelodiCore_ReadMetadata(const char* file_path);
extern void MelodiCore_WriteMetadata(const char* file_path, const char* tags_json);
extern void MelodiCore_EmbedCoverArt(const char* file_path, const char* image_data, int image_len, const char* mime_type);
extern void MelodiCore_EmbedLyrics(const char* file_path, const char* lyrics);
extern const char* MelodiCore_ExtractLyrics(const char* file_path);
extern const char* MelodiCore_GetStats();

@interface MelodiCorePlugin : NSObject <FlutterPlugin>
@end

@implementation MelodiCorePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"melodi/core"
            binaryMessenger:[registrar messenger]];
  MelodiCorePlugin* instance = [[MelodiCorePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"initialize" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* storageRoot = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"melodi"];
    const char* cStorageRoot = [storageRoot UTF8String];
    int initResult = MelodiCore_Init(cStorageRoot);
    if (initResult == 0) {
      result(@{
        @"version": [NSString stringWithUTF8String:MelodiCore_Version()],
        @"apiVersion": [NSString stringWithUTF8String:MelodiCore_APIVersion()],
      });
    } else {
      result(FlutterError(code: "INIT_FAILED", message: "Failed to initialize MelodiCore", details: nil));
    }
  } else if ([@"ping" isEqualToString:call.method]) {
    result([NSString stringWithUTF8String:MelodiCore_Ping()]);
  } else if ([@"search" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char* response = MelodiCore_Search([jsonString UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"match" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char* response = MelodiCore_Match([jsonString UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"resolve" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char* response = MelodiCore_Resolve([jsonString UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"download" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char* response = MelodiCore_Download([jsonString UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"cancelDownload" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* jobId = args[@"jobId"];
    MelodiCore_CancelDownload([jobId UTF8String]);
    result(nil);
  } else if ([@"getDownloadStatus" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* jobId = args[@"jobId"];
    const char* response = MelodiCore_GetDownloadStatus([jobId UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"listDownloads" isEqualToString:call.method]) {
    const char* response = MelodiCore_ListDownloads();
    result([NSString stringWithUTF8String:response]);
  } else if ([@"installExtension" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:args options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char* response = MelodiCore_InstallExtension([jsonString UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"uninstallExtension" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* id = args[@"id"];
    MelodiCore_UninstallExtension([id UTF8String]);
    result(nil);
  } else if ([@"enableExtension" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* id = args[@"id"];
    NSNumber* enabled = args[@"enabled"];
    MelodiCore_EnableExtension([id UTF8String], [enabled intValue]);
    result(nil);
  } else if ([@"listExtensions" isEqualToString:call.method]) {
    const char* response = MelodiCore_ListExtensions();
    result([NSString stringWithUTF8String:response]);
  } else if ([@"getExtension" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* id = args[@"id"];
    const char* response = MelodiCore_GetExtension([id UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"checkExtensionHealth" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* id = args[@"id"];
    const char* response = MelodiCore_CheckExtensionHealth([id UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"updateExtension" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* id = args[@"id"];
    const char* response = MelodiCore_UpdateExtension([id UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"updateAllExtensions" isEqualToString:call.method]) {
    const char* response = MelodiCore_UpdateAllExtensions();
    result([NSString stringWithUTF8String:response]);
  } else if ([@"addRepository" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* url = args[@"url"];
    MelodiCore_AddRepository([url UTF8String]);
    result(nil);
  } else if ([@"removeRepository" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* url = args[@"url"];
    MelodiCore_RemoveRepository([url UTF8String]);
    result(nil);
  } else if ([@"listRepositories" isEqualToString:call.method]) {
    const char* response = MelodiCore_ListRepositories();
    result([NSString stringWithUTF8String:response]);
  } else if ([@"readMetadata" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* filePath = args[@"filePath"];
    const char* response = MelodiCore_ReadMetadata([filePath UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"writeMetadata" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* filePath = args[@"filePath"];
    NSDictionary* tags = args[@"tags"];
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:tags options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    MelodiCore_WriteMetadata([filePath UTF8String], [jsonString UTF8String]);
    result(nil);
  } else if ([@"embedCoverArt" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* filePath = args[@"filePath"];
    NSData* imageData = args[@"imageData"];
    NSString* mimeType = args[@"mimeType"];
    MelodiCore_EmbedCoverArt([filePath UTF8String], [imageData bytes], (int)[imageData length], [mimeType UTF8String]);
    result(nil);
  } else if ([@"embedLyrics" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* filePath = args[@"filePath"];
    NSString* lyrics = args[@"lyrics"];
    MelodiCore_EmbedLyrics([filePath UTF8String], [lyrics UTF8String]);
    result(nil);
  } else if ([@"extractLyrics" isEqualToString:call.method]) {
    NSDictionary* args = call.arguments;
    NSString* filePath = args[@"filePath"];
    const char* response = MelodiCore_ExtractLyrics([filePath UTF8String]);
    result([NSString stringWithUTF8String:response]);
  } else if ([@"getStats" isEqualToString:call.method]) {
    const char* response = MelodiCore_GetStats();
    result([NSString stringWithUTF8String:response]);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end