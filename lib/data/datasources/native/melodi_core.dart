import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors.dart';

class MelodiCore {
  static final MelodiCore _instance = MelodiCore._internal();
  factory MelodiCore() => _instance;
  MelodiCore._internal();

  DynamicLibrary? _lib;
  bool _initialized = false;

  // Function pointers
  late final int Function(Pointer<Utf8>) _initialize;
  late final Pointer<Utf8> Function() _version;
  late final Pointer<Utf8> Function() _apiVersion;
  late final Pointer<Utf8> Function() _ping;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _search;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _match;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _resolve;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _resolveStream;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _download;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _startIOSDownload;
  late final void Function(Pointer<Utf8>) _cancelDownload;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _getDownloadStatus;
  late final Pointer<Utf8> Function() _listDownloads;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _installExtension;
  late final void Function(Pointer<Utf8>) _uninstallExtension;
  late final void Function(Pointer<Utf8>, int) _enableExtension;
  late final Pointer<Utf8> Function() _listExtensions;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _getExtension;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _checkExtensionHealth;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _updateExtension;
  late final Pointer<Utf8> Function() _updateAllExtensions;
  late final void Function(Pointer<Utf8>) _addRepository;
  late final void Function(Pointer<Utf8>) _removeRepository;
  late final Pointer<Utf8> Function() _listRepositories;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _readMetadata;
  late final void Function(Pointer<Utf8>, Pointer<Utf8>) _writeMetadata;
  late final void Function(Pointer<Utf8>, Pointer<Uint8>, int, Pointer<Utf8>) _embedCoverArt;
  late final void Function(Pointer<Utf8>, Pointer<Utf8>) _embedLyrics;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _extractLyrics;
  late final Pointer<Utf8> Function() _getStats;
  late final void Function() _shutdown;

  Future<Result<void>> initialize() async {
    if (_initialized) return const Result.success(null);

    try {
      final storageDir = await getApplicationDocumentsDirectory();
      final storageRoot = storageDir.path;

      _loadLibrary();
      _bindFunctions();

      final result = _initialize(storageRoot.toNativeUtf8());
      if (result != 0) {
        return Result.failure(Failure.unknown('Failed to initialize MelodiCore: $result'));
      }

      _initialized = true;
      debugPrint('MelodiCore initialized: ${version()}');
      return const Result.success(null);
    } catch (e, st) {
      return Result.failure(Failure.unknown('MelodiCore initialization failed: $e', st));
    }
  }

  void _loadLibrary() {
    if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libmelodicore.so');
    } else {
      _lib = DynamicLibrary.process();
    }
  }

  void _bindFunctions() {
    final lib = _lib!;
    _initialize = lib.lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('Initialize').asFunction();
    _version = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('Version').asFunction();
    _apiVersion = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('APIVersion').asFunction();
    _ping = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('Ping').asFunction();
    _search = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('Search').asFunction();
    _match = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('Match').asFunction();
    _resolve = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('Resolve').asFunction();
    _resolveStream = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('ResolveStream').asFunction();
    _download = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('Download').asFunction();
    _startIOSDownload = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('StartIOSDownload').asFunction();
    _cancelDownload = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('CancelDownload').asFunction();
    _getDownloadStatus = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('GetDownloadStatus').asFunction();
    _listDownloads = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('ListDownloads').asFunction();
    _installExtension = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('InstallExtension').asFunction();
    _uninstallExtension = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('UninstallExtension').asFunction();
    _enableExtension = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>, Int32)>>('EnableExtension').asFunction();
    _listExtensions = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('ListExtensions').asFunction();
    _getExtension = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('GetExtension').asFunction();
    _checkExtensionHealth = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('CheckExtensionHealth').asFunction();
    _updateExtension = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('UpdateExtension').asFunction();
    _updateAllExtensions = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('UpdateAllExtensions').asFunction();
    _addRepository = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('AddRepository').asFunction();
    _removeRepository = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('RemoveRepository').asFunction();
    _listRepositories = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('ListRepositories').asFunction();
    _readMetadata = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('ReadMetadata').asFunction();
    _writeMetadata = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Utf8>)>>('WriteMetadata').asFunction();
    _embedCoverArt = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Uint8>, Int32, Pointer<Utf8>)>>('EmbedCoverArt').asFunction();
    _embedLyrics = lib.lookup<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Utf8>)>>('EmbedLyrics').asFunction();
    _extractLyrics = lib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>('ExtractLyrics').asFunction();
    _getStats = lib.lookup<NativeFunction<Pointer<Utf8> Function()>>('GetStats').asFunction();
    _shutdown = lib.lookup<NativeFunction<Void Function()>>('Shutdown').asFunction();
  }

  String _call(Pointer<Utf8> Function() fn) {
    final ptr = fn();
    final result = ptr.toDartString();
    calloc.free(ptr);
    return result;
  }

  String _callWithArg(Pointer<Utf8> Function(Pointer<Utf8>) fn, String arg) {
    final argPtr = arg.toNativeUtf8();
    final ptr = fn(argPtr);
    calloc.free(argPtr);
    final result = ptr.toDartString();
    calloc.free(ptr);
    return result;
  }

  // Core
  String version() => _call(_version);
  String apiVersion() => _call(_apiVersion);
  String ping() => _call(_ping);

  // Search
  Result<String> search(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_search, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('Search failed: $e'));
    }
  }

  Result<String> match(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_match, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('Match failed: $e'));
    }
  }

  Result<String> resolve(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_resolve, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('Resolve failed: $e'));
    }
  }

  Result<String> resolveStream(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_resolveStream, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('ResolveStream failed: $e'));
    }
  }

  // Downloads
  Result<String> download(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_download, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('Download failed: $e'));
    }
  }

  Result<String> startIOSDownload(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_startIOSDownload, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('StartIOSDownload failed: $e'));
    }
  }

  void cancelDownload(String jobId) {
    if (!_initialized) return;
    _cancelDownload(jobId.toNativeUtf8());
  }

  Result<String> getDownloadStatus(String jobId) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_getDownloadStatus, jobId));
    } catch (e) {
      return Result.failure(Failure.unknown('GetDownloadStatus failed: $e'));
    }
  }

  Result<String> listDownloads() {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_call(_listDownloads));
    } catch (e) {
      return Result.failure(Failure.unknown('ListDownloads failed: $e'));
    }
  }

  // Extensions
  Result<String> installExtension(String requestJson) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_installExtension, requestJson));
    } catch (e) {
      return Result.failure(Failure.unknown('InstallExtension failed: $e'));
    }
  }

  void uninstallExtension(String id) {
    if (!_initialized) return;
    _uninstallExtension(id.toNativeUtf8());
  }

  void enableExtension(String id, bool enabled) {
    if (!_initialized) return;
    _enableExtension(id.toNativeUtf8(), enabled ? 1 : 0);
  }

  Result<String> listExtensions() {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_call(_listExtensions));
    } catch (e) {
      return Result.failure(Failure.unknown('ListExtensions failed: $e'));
    }
  }

  Result<String> getExtension(String id) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_getExtension, id));
    } catch (e) {
      return Result.failure(Failure.unknown('GetExtension failed: $e'));
    }
  }

  Result<String> checkExtensionHealth(String id) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_checkExtensionHealth, id));
    } catch (e) {
      return Result.failure(Failure.unknown('CheckExtensionHealth failed: $e'));
    }
  }

  Result<String> updateExtension(String id) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_updateExtension, id));
    } catch (e) {
      return Result.failure(Failure.unknown('UpdateExtension failed: $e'));
    }
  }

  Result<String> updateAllExtensions() {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_call(_updateAllExtensions));
    } catch (e) {
      return Result.failure(Failure.unknown('UpdateAllExtensions failed: $e'));
    }
  }

  // Repositories
  void addRepository(String url) {
    if (!_initialized) return;
    _addRepository(url.toNativeUtf8());
  }

  void removeRepository(String url) {
    if (!_initialized) return;
    _removeRepository(url.toNativeUtf8());
  }

  Result<String> listRepositories() {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_call(_listRepositories));
    } catch (e) {
      return Result.failure(Failure.unknown('ListRepositories failed: $e'));
    }
  }

  // Metadata
  Result<String> readMetadata(String filePath) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_readMetadata, filePath));
    } catch (e) {
      return Result.failure(Failure.unknown('ReadMetadata failed: $e'));
    }
  }

  void writeMetadata(String filePath, String tagsJson) {
    if (!_initialized) return;
    _writeMetadata(filePath.toNativeUtf8(), tagsJson.toNativeUtf8());
  }

  void embedCoverArt(String filePath, Uint8List imageData, String mimeType) {
    if (!_initialized) return;
    final imagePtr = calloc<Uint8>(imageData.length);
    imagePtr.asTypedList(imageData.length).setAll(0, imageData);
    _embedCoverArt(filePath.toNativeUtf8(), imagePtr, imageData.length, mimeType.toNativeUtf8());
    calloc.free(imagePtr);
  }

  void embedLyrics(String filePath, String lyrics) {
    if (!_initialized) return;
    _embedLyrics(filePath.toNativeUtf8(), lyrics.toNativeUtf8());
  }

  Result<String> extractLyrics(String filePath) {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_callWithArg(_extractLyrics, filePath));
    } catch (e) {
      return Result.failure(Failure.unknown('ExtractLyrics failed: $e'));
    }
  }

  // Stats
  Result<String> getStats() {
    if (!_initialized) return Result.failure(Failure.notInitialized('MelodiCore'));
    try {
      return Result.success(_call(_getStats));
    } catch (e) {
      return Result.failure(Failure.unknown('GetStats failed: $e'));
    }
  }

  void shutdown() {
    if (!_initialized) return;
    _shutdown();
    _initialized = false;
  }

  bool get isInitialized => _initialized;
}