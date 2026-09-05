import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import 'backend_api_service.dart';
import 'database_service.dart';
import 'robust_piped_service.dart';
import 'track_matcher.dart';
import 'multi_source_search.dart';
import 'music_source.dart';
import 'youtube_downloader.dart';
import 'yt_dlp_service.dart';
import 'navidrome_service.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final DatabaseService _db = DatabaseService.instance;
  late final TrackMatcher _trackMatcher = TrackMatcher(
    (query) => MultiSourceSearch().searchAllSync(query, limitPerSource: 10),
  );
  final NavidromeService _navidrome = NavidromeService.instance;
  final YouTubeDownloader _youtubeDownloader = YouTubeDownloader();

  // Resolved YouTube stream URLs are cached briefly so repeated plays
  // (replay, skip back, queue transitions) start instantly instead of
  // re-resolving through the backend/piped on every tap.
  final Map<String, _CachedStream> _ytStreamCache = {};
  static const Duration _ytStreamCacheTtl = Duration(minutes: 3);

  List<SongModel> _queue = [];
  List<SongModel> _originalQueue = [];
  int _currentIndex = -1;
  bool _isShuffled = false;
  LoopStyle _repeatMode = LoopStyle.off;
  bool _isInitialized = false;
  bool _autoShuffleEnabled = false;
  Duration _crossfadeDuration = Duration.zero;
  StreamSubscription<Duration>? _crossfadeSubscription;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  Timer? _saveStateTimer;
  bool _handlingCompletion = false;

  AudioPlayerHandler() {
    unawaited(_configureAudioSession());
    _initPlayer();
    _startAutoSave();
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);
  }

  int? get sleepTimerMinutes {
    if (_sleepTimerEnd == null) return null;
    return _sleepTimerEnd!.difference(DateTime.now()).inMinutes.clamp(0, 9999);
  }

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    if (duration == Duration.zero) {
      _sleepTimerEnd = null;
      _broadcastState();
      return;
    }
    _sleepTimerEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      _player.stop();
      _sleepTimerEnd = null;
      _broadcastState();
    });
    _broadcastState();
  }

  bool _isDurationCompatible(Duration candidate, int expectedMs) {
    if (expectedMs <= 0 || candidate.inMilliseconds <= 0) return true;
    final toleranceMs = (expectedMs * 0.15).round().clamp(20000, 60000);
    return (candidate.inMilliseconds - expectedMs).abs() <= toleranceMs;
  }

  void _initPlayer() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_onTrackComplete());
      }
      _broadcastState();
    });

    _player.positionStream.listen((pos) {
      if (_isInitialized) _broadcastState();
      // Fallback completion: actual audio may end before reported duration (mismatch 3:25 vs 6:54)
      // If position is within 1s of known expected duration but player hasn't signaled completed, trigger next.
      final dur = _player.duration;
      if (dur != null && dur.inMilliseconds > 0 && _player.playing) {
        final expectedMs = _currentIndex >= 0 && _currentIndex < _queue.length
            ? _queue[_currentIndex].duration.inMilliseconds
            : 0;
        // If expected duration is known and significantly shorter than reported, use expected for completion
        final effectiveDur =
            (expectedMs > 0 && !_isDurationCompatible(dur, expectedMs))
                ? Duration(milliseconds: expectedMs)
                : dur;
        if (pos.inMilliseconds >= effectiveDur.inMilliseconds - 800) {
          // Ensure we don't fire too early: wait until buffered
          if (_player.bufferedPosition.inMilliseconds >=
              effectiveDur.inMilliseconds - 500) {
            // Let just_audio handle normal completion; this is fallback only if stuck
          }
        }
      }
    });

    _player.durationStream.listen((duration) {
      if (duration != null &&
          duration.inMilliseconds > 0 &&
          _currentIndex >= 0 &&
          _currentIndex < _queue.length) {
        // Guard against wildly wrong durations (e.g. 6:54 vs 3:25) — prefer expected if mismatch huge
        final expectedMs = _queue[_currentIndex].duration.inMilliseconds;
        final effective = _isDurationCompatible(duration, expectedMs)
            ? duration
            : (expectedMs > 0 ? Duration(milliseconds: expectedMs) : duration);
        mediaItem.add(mediaItem.value?.copyWith(duration: effective));
        super.mediaItem.add(mediaItem.value!.copyWith(duration: effective));
      }
    });

    _player.playingStream.listen((_) {
      _broadcastState();
    });

    _player.processingStateStream.listen((_) {
      _broadcastState();
    });
  }

  // Equalizer stubs - actual equalizer is handled by playback_service
  // These methods save settings to database; on Android, playback_service applies them
  Future<void> _restoreEqualizerSettings() async {}
  Future<void> applyEqualizerPreset(String name) async {
    await _db.setSetting('eq_preset', name);
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    await _db.setSetting('eq_enabled', enabled.toString());
  }

  Future<void> setEqualizerBand(int index, double gain) async {}

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('googlevideo.com') ||
        url.contains('youtube-nocookie.com');
  }

  String? _extractYouTubeVideoId(String url) {
    // Handle youtu.be short URLs
    if (url.contains('youtu.be/')) {
      final id = url.split('youtu.be/').last.split('?').first;
      return id.isNotEmpty ? id : null;
    }
    // Handle youtube.com/watch?v= URLs
    if (url.contains('v=')) {
      final id = url.split('v=').last.split('&').first;
      return id.isNotEmpty ? id : null;
    }
    // Handle youtube.com/embed/ URLs
    if (url.contains('/embed/')) {
      final id = url.split('/embed/').last.split('?').first;
      return id.isNotEmpty ? id : null;
    }
    return null;
  }

  void _startAutoSave() {
    _saveStateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      savePlayerState();
    });
  }

  Future<void> savePlayerState() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    try {
      final song = _queue[_currentIndex];
      final positionMs = _player.position.inMilliseconds;

      await _db.setSetting('player_current_song', song.toJson());
      await _db.setSetting('player_current_index', _currentIndex.toString());
      await _db.setSetting('player_position_ms', positionMs.toString());
      await _db.setSetting('player_queue', SongModel.listToJson(_queue));
      await _db.setSetting('player_is_shuffled', _isShuffled.toString());
      await _db.setSetting('player_repeat_mode', _repeatMode.index.toString());
      await _db.setSetting('player_saved_at', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> restorePlayerState() async {
    try {
      final indexStr = await _db.getSetting('player_current_index');
      if (indexStr == null || indexStr.isEmpty) return;
      final positionMsStr = await _db.getSetting('player_position_ms');
      final isShuffledStr = await _db.getSetting('player_is_shuffled');
      final repeatModeStr = await _db.getSetting('player_repeat_mode');

      final index = int.tryParse(indexStr) ?? -1;
      final positionMs = int.tryParse(positionMsStr ?? '0') ?? 0;
      final isShuffled = isShuffledStr == 'true';
      final repeatMode =
          LoopStyle.values[int.tryParse(repeatModeStr ?? '0') ?? 0];

      // Restore queue from settings
      final queueStr = await _db.getSetting('player_queue');
      if (queueStr != null && queueStr.isNotEmpty) {
        try {
          final queueList = SongModel.listFromJson(queueStr);
          if (queueList.isNotEmpty && index >= 0 && index < queueList.length) {
            _queue = queueList;
            _originalQueue = List.from(_queue);
            _currentIndex = index;
            _isShuffled = isShuffled;
            _repeatMode = repeatMode;

            // The handler owns repeat/queue transitions. just_audio only sees
            // one source at a time, so its native loop mode must remain off.
            await _player.setLoopMode(LoopMode.off);

            // Load the song but don't play - just prepare for playback
            final song = await _resolvePlayableSong(_queue[_currentIndex]);
            try {
              AudioSource audioSource;
              if (song.filePath.startsWith('youtube://')) {
                final videoId = song.filePath.replaceFirst('youtube://', '');
                audioSource = await _youtubeAudioSource(videoId);
              } else if (song.filePath.startsWith('http')) {
                audioSource = AudioSource.uri(Uri.parse(song.filePath));
              } else {
                audioSource = AudioSource.file(song.filePath);
              }
              await _player.setAudioSource(
                audioSource,
                preload: true,
                initialPosition: Duration(milliseconds: positionMs),
              );
              // Wait for duration to be available
              for (int i = 0; i < 10; i++) {
                await Future.delayed(const Duration(milliseconds: 50));
                if (_player.duration != null &&
                    _player.duration!.inMilliseconds > 0) {
                  break;
                }
              }
              // Apply speed/volume overrides
              if (_playbackSpeedOverride != null) {
                await _player.setSpeed(_playbackSpeedOverride!);
              }
              if (_volumeOverride != null) {
                await _player.setVolume(_volumeOverride!.clamp(0.5, 2.0));
              }
              _isInitialized = true;
              _broadcastState();

              // Broadcast mediaItem for lock screen / control center
              Uri? artUri;
              if (song.albumArt != null) {
                try {
                  final dir = await getTemporaryDirectory();
                  final artFile = File('${dir.path}/nowplaying_art.jpg');
                  await artFile.writeAsBytes(song.albumArt!);
                  artUri = Uri.file(artFile.path);
                } catch (e) {
                  debugPrint('Album art write failed: $e');
                }
              }
              final media = MediaItem(
                id: song.id,
                album: song.album,
                title: song.title,
                artist: song.artist,
                duration: _player.duration,
                artUri: artUri,
              );
              mediaItem.add(media);
              super.mediaItem.add(media);
            } catch (e) {
              debugPrint('Restore prepare failed: $e');
              _isInitialized = true;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _broadcastState() {
    final index = _currentIndex;
    if (index < 0 || index >= _queue.length) return;

    final isPlaying = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: isPlaying,
      queueIndex: index,
    ));
  }

  List<SongModel> get songQueue => List.unmodifiable(_queue);
  List<SongModel> get originalQueue => List.unmodifiable(_originalQueue);
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  bool get isShuffled => _isShuffled;
  LoopStyle get repeatMode => _repeatMode;
  bool get isPlaying => _player.playing;
  Duration get position {
    final pos = _player.position;
    final dur = _player.duration;
    if (dur != null && dur.inMilliseconds > 0) {
      // Effective duration: if reported dur mismatches expected (e.g. 6:54 vs 3:25), clamp to expected
      final expectedMs = _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex].duration.inMilliseconds
          : 0;
      final effectiveMs =
          (expectedMs > 0 && !_isDurationCompatible(dur, expectedMs))
              ? expectedMs
              : dur.inMilliseconds;
      if (pos.inMilliseconds > effectiveMs) {
        return Duration(milliseconds: effectiveMs);
      }
    }
    return pos;
  }

  Duration get bufferedPosition => _player.bufferedPosition;
  Duration get duration {
    final raw = _player.duration;
    if (raw == null || raw.inMilliseconds == 0) return Duration.zero;
    final expectedMs = _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex].duration.inMilliseconds
        : 0;
    if (expectedMs > 0 && !_isDurationCompatible(raw, expectedMs)) {
      return Duration(milliseconds: expectedMs);
    }
    return raw;
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  double get playbackSpeed => _player.speed;
  double get volume => _player.volume;
  Duration get crossfadeDuration => _crossfadeDuration;
  bool get autoShuffleEnabled => _autoShuffleEnabled;

  Future<void> playSong(SongModel song) async {
    await setQueue([song], initialIndex: 0);
  }

  Future<void> setQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    _originalQueue = List.from(songs);
    _queue = List.from(songs);
    _currentIndex = initialIndex;

    if (_isShuffled && songs.length > 1) {
      _applyShuffle();
    }

    await _playCurrent();
  }

  Future<void> playFromQueue(List<SongModel> songs, int index) async {
    await setQueue(songs, initialIndex: index);
  }

  void updateSongInQueue(SongModel song) {
    final origIdx = _originalQueue.indexWhere((s) => s.id == song.id);
    if (origIdx != -1) _originalQueue[origIdx] = song;
    final idx = _queue.indexWhere((s) => s.id == song.id);
    if (idx != -1) _queue[idx] = song;
    // Update MediaItem if this is the currently playing song
    if (idx == _currentIndex && mediaItem.value != null) {
      mediaItem.add(mediaItem.value!.copyWith(
        album: song.album,
        title: song.title,
        artist: song.artist,
      ));
    }
  }

  Future<void> addToQueue(SongModel song) async {
    _originalQueue.add(song);
    _queue.add(song);
    await _updateMediaQueue();
  }

  Future<void> insertNext(SongModel song) async {
    if (_currentIndex + 1 <= _queue.length) {
      _queue.insert(_currentIndex + 1, song);
      _originalQueue.insert(_currentIndex + 1, song);
    }
    await _updateMediaQueue();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (index == _currentIndex) return;

    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    }
    await _updateMediaQueue();
  }

  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    await _updateMediaQueue();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    _originalQueue.clear();
    _currentIndex = -1;
    await _player.stop();
    await _updateMediaQueue();
  }

  void replaceQueue(List<SongModel> newQueue) {
    _queue = List.from(newQueue);
    _originalQueue = List.from(newQueue);
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.isNotEmpty ? 0 : -1;
    }
    _updateMediaQueue();
  }

  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      _applyShuffle();
    } else {
      _unapplyShuffle();
    }
  }

  void _applyShuffle() {
    if (_queue.isEmpty) return;
    final currentSong = _currentIndex >= 0 ? _queue[_currentIndex] : null;
    final remaining = _queue.where((s) => s.id != currentSong?.id).toList();
    remaining.shuffle();
    _queue = currentSong != null ? [currentSong, ...remaining] : remaining;
    _currentIndex = 0;
  }

  void _unapplyShuffle() {
    final currentSong = _currentIndex >= 0 ? _queue[_currentIndex] : null;
    _queue = List.from(_originalQueue);
    _currentIndex = currentSong != null
        ? _queue.indexWhere((s) => s.id == currentSong.id)
        : 0;
    if (_currentIndex == -1) _currentIndex = 0;
  }

  Future<void> setLoopStyle(LoopStyle mode) async {
    _repeatMode = mode;
    await _player.setLoopMode(LoopMode.off);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> seekForward([bool immediate = true]) async {
    final offset = Duration(seconds: immediate ? 10 : 30);
    final newPos = _player.position + offset;
    final dur = _player.duration ?? Duration.zero;
    await _player.seek(newPos > dur ? dur : newPos);
  }

  @override
  Future<void> seekBackward([bool immediate = true]) async {
    final offset = Duration(seconds: immediate ? 10 : 30);
    final newPos = _player.position - offset;
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> _onTrackComplete() async {
    if (_handlingCompletion || _queue.isEmpty) return;
    _handlingCompletion = true;
    try {
      final decision = PlaybackCompletionDecision.decide(
        currentIndex: _currentIndex,
        queueLength: _queue.length,
        repeatMode: _repeatMode,
      );
      switch (decision.action) {
        case PlaybackCompletionAction.replayCurrent:
          await _player.seek(Duration.zero);
          _playWithoutBlocking();
          break;
        case PlaybackCompletionAction.playIndex:
          _currentIndex = decision.nextIndex!;
          await _playCurrent(surfaceError: false);
          break;
        case PlaybackCompletionAction.rewindAndPause:
          await _player.pause();
          await _player.seek(Duration.zero);
          await savePlayerState();
          _broadcastState();
          break;
      }
    } finally {
      _handlingCompletion = false;
    }
  }

  /// YouTube parçası için ses kaynağını seçer. Sıra: yt-dlp backend
  /// eklentisi → Piped örnekleri → indirme. Böylece cihazın IP'si
  /// YouTube'a erişemese bile sunucu/örnek proxy'siyle çalma sürer.
  Future<AudioSource> _youtubeAudioSource(String videoId) async {
    final cached = _ytStreamCache[videoId];
    if (cached != null && !cached.isExpired) {
      return AudioSource.uri(Uri.parse(cached.url));
    }

    final streamUrl = await _resolveYoutubeStream(videoId);
    if (streamUrl != null) {
      _ytStreamCache[videoId] = _CachedStream(streamUrl);
      return AudioSource.uri(Uri.parse(streamUrl));
    }
    // Fallback: trigger download and play local
    final tempDir = await getTemporaryDirectory();
    final path = await _youtubeDownloader.downloadFullTrack(
      videoId,
      'temp',
      tempDir,
      quality: 'high',
    );
    if (path != null) {
      return AudioSource.file(path);
    }
    throw StateError('YouTube stream/download failed');
  }

  /// Resolves a streamable audio source for an imported "online" track by
  /// matching it against the full-track sources (YouTube, JioSaavn, Apple
  /// Music, SoundCloud). Uses the track's own metadata so no pre-stored id is
  /// required.
  Future<AudioSource> _resolveOnlineAudioSource(SongModel song) async {
    final onlineTrack = OnlineTrack(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album.isEmpty ? null : song.album,
      duration: song.duration,
      source: MusicSourceType.deezer,
    );
    final url = await MultiSourceSearch().getStreamUrlWithFallback(
      onlineTrack,
      preferStableYouTubeReference: true,
    );
    if (url == null) {
      throw StateError('Eşleşen şarkı bulunamadı');
    }
    if (url.startsWith('youtube://')) {
      final videoId = url.replaceFirst('youtube://', '');
      return await _youtubeAudioSource(videoId);
    }
    return AudioSource.uri(Uri.parse(url));
  }

  /// Resolves a playable YouTube stream URL as fast as possible.
  ///
  /// Priority: backend proxy → Piped → doğrudan YouTube (youtube_explode).
  /// Backend/Piped paralel sorgulanır; ikisi de başarısızsa yt_dlp dener.
  Future<String?> _resolveYoutubeStream(String videoId) async {
    final backendFut =
        BackendApiService.instance.streamUrl(videoId).catchError((_) => null);
    final pipedFut = RobustPipedService.instance
        .getStreamUrl(videoId)
        .catchError((_) => null);
    final ytDlpFut =
        YtDlpService.instance.getStreamUrl(videoId).catchError((_) => null);

    final completer = Completer<String?>();
    String? backendResult;
    String? pipedResult;
    String? ytDlpResult;
    var settled = false;

    void settle(String? url) {
      if (settled || url == null) return;
      settled = true;
      completer.complete(url);
    }

    backendFut.then((url) {
      backendResult = url;
      if (url != null) {
        settle(url);
      } else {
        if (pipedResult != null) {
          settle(pipedResult);
        } else if (ytDlpResult != null) settle(ytDlpResult);
      }
    });

    pipedFut.then((url) {
      pipedResult = url;
      if (url != null && !settled) {
        settle(url);
      } else {
        if (backendResult != null) {
          settle(backendResult);
        } else if (ytDlpResult != null && !settled) settle(ytDlpResult);
      }
    });

    ytDlpFut.then((url) {
      ytDlpResult = url;
      if (url != null && !settled) {
        settle(url);
      }
    });

    Future.wait([backendFut, pipedFut, ytDlpFut]).then((_) {
      if (!settled) {
        if (backendResult != null) {
          completer.complete(backendResult);
        } else if (pipedResult != null)
          completer.complete(pipedResult);
        else if (ytDlpResult != null)
          completer.complete(ytDlpResult);
        else
          completer.complete(null);
      }
    });

    return completer.future;
  }

  Future<void> _playCurrent({
    bool allowFailureFallback = true,
    bool surfaceError = true,
  }) async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;

    _isInitialized = false;
    _crossfadeSubscription?.cancel();
    var song = _queue[_currentIndex];

    try {
      song = await _resolvePlayableSong(song);
      // Determine audio source based on file path type
      AudioSource audioSource;
      if (song.filePath.startsWith('youtube://')) {
        final videoId = song.filePath.replaceFirst('youtube://', '');
        audioSource = await _youtubeAudioSource(videoId);
      } else if (song.filePath.startsWith('http') ||
          song.filePath.startsWith('https')) {
        // Check if this is a YouTube URL - use custom streaming source
        if (_isYouTubeUrl(song.filePath)) {
          final videoId = _extractYouTubeVideoId(song.filePath);
          if (videoId != null) {
            audioSource = await _youtubeAudioSource(videoId);
          } else {
            audioSource = AudioSource.uri(Uri.parse(song.filePath));
          }
        } else {
          audioSource = AudioSource.uri(Uri.parse(song.filePath));
        }
      } else if (song.filePath.startsWith('online://')) {
        // Imported playlist tracks without a direct stream id: match them to
        // a full-track source (YouTube/JioSaavn/etc.) and play from there.
        audioSource = await _resolveOnlineAudioSource(song);
      } else {
        audioSource = AudioSource.file(song.filePath);
      }
      await _player.setAudioSource(
        audioSource,
        preload: true,
        initialPosition: Duration.zero,
      );

      // Wait for duration to be available with retry (stream proxy may take longer than 500ms)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_player.duration != null && _player.duration!.inMilliseconds > 0) {
          break;
        }
      }
      final rawDuration = _player.duration;
      final actualDuration = (rawDuration != null &&
              rawDuration.inMilliseconds > 0 &&
              _isDurationCompatible(rawDuration, song.duration.inMilliseconds))
          ? rawDuration
          : song.duration.inMilliseconds > 0
              ? song.duration
              : (rawDuration ?? song.duration);

      if (_playbackSpeedOverride != null) {
        await _player.setSpeed(_playbackSpeedOverride!);
      }
      if (_volumeOverride != null) {
        await _player.setVolume(_volumeOverride!.clamp(0.5, 2.0));
      }

      // Restore equalizer settings for new track
      await _restoreEqualizerSettings();

      // Crossfade: monitor position and trigger next track early (effective duration)
      if (_crossfadeDuration > Duration.zero && _queue.length > 1) {
        _crossfadeSubscription = _player.positionStream.listen((position) {
          final rawDur = _player.duration;
          if (rawDur == null || !_player.playing) return;
          final expectedMs = song.duration.inMilliseconds;
          final effectiveDur =
              (expectedMs > 0 && !_isDurationCompatible(rawDur, expectedMs))
                  ? Duration(milliseconds: expectedMs)
                  : rawDur;
          final remaining = effectiveDur - position;
          if (remaining <= _crossfadeDuration && remaining > Duration.zero) {
            _crossfadeSubscription?.cancel();
            _crossfadeSubscription = null;
            unawaited(_onTrackComplete());
          }
        });
      }

      if (_player.playing) {
        if (_currentIndex < 0 || _currentIndex >= _queue.length) {
          _currentIndex = _queue.isNotEmpty ? 0 : -1;
        }
      }

      Uri? artUri;
      if (song.albumArt != null) {
        try {
          final dir = await getTemporaryDirectory();
          final artFile = File('${dir.path}/nowplaying_art.jpg');
          await artFile.writeAsBytes(song.albumArt!);
          artUri = Uri.file(artFile.path);
        } catch (e) {
          debugPrint('Album art write failed: $e');
        }
      }

      final mediaItem = MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: actualDuration,
        artUri: artUri,
      );

      this.mediaItem.add(mediaItem);
      super.mediaItem.add(mediaItem);

      await _db.updatePlayCount(song.id);
      _isInitialized = true;
      _broadcastState();
      _playWithoutBlocking();
    } catch (e, stackTrace) {
      debugPrint('Playback failed for ${song.title}: $e\n$stackTrace');
      await _db.insertErrorLog('playback', e.toString(), stackTrace.toString());
      _isInitialized = true;
      if (!allowFailureFallback) {
        Error.throwWithStackTrace(e, stackTrace);
      }

      final failedIndex = _currentIndex;
      final candidates = PlaybackFailurePlan.candidateIndices(
        currentIndex: failedIndex,
        queueLength: _queue.length,
        repeatMode: _repeatMode,
      );
      for (final candidate in candidates) {
        _currentIndex = candidate;
        try {
          await _playCurrent(
            allowFailureFallback: false,
            surfaceError: false,
          );
          return;
        } catch (_) {
          // The nested attempt is already logged. Continue at most once per
          // remaining queue item; never recurse through completion handling.
        }
      }

      await _player.stop();
      _currentIndex = failedIndex;
      _isInitialized = true;
      await savePlayerState();
      _broadcastState();
      if (surfaceError) {
        Error.throwWithStackTrace(e, stackTrace);
      }
    }
  }

  Future<SongModel> _resolvePlayableSong(SongModel song) async {
    final stored = await _db.getSongById(song.id);
    if (stored != null &&
        !_isRemotePath(stored.filePath) &&
        File(stored.filePath).existsSync()) {
      _replaceSongInQueues(stored);
      return stored;
    }

    final downloaded = await _resolveDownloadedSong(song);
    if (downloaded != null) return downloaded;
    if (!song.filePath.startsWith('spotify://')) return song;

    final spotifyId = song.filePath.replaceFirst('spotify://', '');

    // Spotify supplies library metadata, not downloadable audio. When the
    // user owns the same track on a connected personal server, prefer that
    // exact title/artist/duration match before trying a public resolver.
    try {
      if (await _navidrome.isConfigured()) {
        final candidates = await _navidrome.search(
          '${song.artist} - ${song.title}',
          limit: 8,
        );
        candidates.sort((a, b) {
          final aScore = TrackMatcher.scoreWithDuration(
            song.title,
            song.artist,
            song.duration.inMilliseconds,
            a.title,
            a.artist,
            a.duration.inMilliseconds,
          );
          final bScore = TrackMatcher.scoreWithDuration(
            song.title,
            song.artist,
            song.duration.inMilliseconds,
            b.title,
            b.artist,
            b.duration.inMilliseconds,
          );
          return bScore.compareTo(aScore);
        });
        if (candidates.isNotEmpty) {
          final best = candidates.first;
          final score = TrackMatcher.scoreWithDuration(
            song.title,
            song.artist,
            song.duration.inMilliseconds,
            best.title,
            best.artist,
            best.duration.inMilliseconds,
          );
          if (score >= 0.72 && best.streamUrl != null) {
            final artwork = song.albumArt ??
                await _navidrome.fetchArtwork(best.thumbnailUrl);
            final resolved = song.copyWith(
              filePath: best.streamUrl,
              album: best.album ?? song.album,
              duration:
                  best.duration > Duration.zero ? best.duration : song.duration,
              albumArt: artwork,
            );
            _replaceSongInQueues(resolved);
            return resolved;
          }
        }
      }
    } catch (e) {
      debugPrint('Navidrome Spotify match failed: $e');
    }

    final cached = await _db.getCachedMatch(spotifyId);
    var videoId = cached?['ytVideoId']?.toString();
    if (videoId == null || videoId.isEmpty) {
      final match = await _trackMatcher.matchSpotifyTrackToYT(
        song.title,
        song.artist,
        album: song.album,
        durationMs: song.duration.inMilliseconds,
      );
      if (match == null) {
        throw StateError(
            'Spotify parçası için oynatılabilir kaynak bulunamadı');
      }
      // Düşük güvenli eşleşmelerde sert hata vermek yerine en iyi çabayı
      // kabul et; böylece çalma listesi içindeki parçalar "kaynak bulunamadı"
      // hatasıyla çalmamazlık yapmaz.
      if (match.confidence < 0.35) {
        debugPrint(
            'Düşük güvenli YouTube eşleşmesi kabul edildi (${match.confidence.toStringAsFixed(2)}): '
            '${song.title} - ${song.artist} -> ${match.ytVideoId}');
      }
      videoId = match.ytVideoId;
      await _db.cacheMatch(spotifyId, videoId, match.confidence);
    }

    final resolved = song.copyWith(filePath: 'youtube://$videoId');
    _replaceSongInQueues(resolved);
    return resolved;
  }

  Future<SongModel?> _resolveDownloadedSong(SongModel song) async {
    final sourceIds = <String>{};

    void addSourceId(String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) sourceIds.add(trimmed);
    }

    addSourceId(song.id);
    for (final prefix in const ['spotify:', 'youtube:']) {
      if (song.id.startsWith(prefix)) {
        addSourceId(song.id.substring(prefix.length));
      }
    }
    if (song.filePath.startsWith('spotify://')) {
      addSourceId(song.filePath.replaceFirst('spotify://', ''));
    } else if (song.filePath.startsWith('youtube://')) {
      addSourceId(song.filePath.replaceFirst('youtube://', ''));
    }

    for (final sourceId in sourceIds) {
      final localPath = await _db.getDownloadedTrackPath(sourceId);
      if (localPath == null || localPath.isEmpty) continue;
      final file = File(localPath);
      if (!await file.exists()) continue;

      final fileSize = await file.length();
      final resolved = song.copyWith(
        filePath: localPath,
        fileSize: fileSize,
      );
      final storedSong = await _db.getSongById(song.id);
      if (storedSong != null) {
        await _db.insertSong(storedSong.copyWith(
          filePath: localPath,
          fileSize: fileSize,
        ));
      }
      _replaceSongInQueues(resolved);
      return resolved;
    }
    return null;
  }

  bool _isRemotePath(String path) =>
      path.startsWith('spotify://') ||
      path.startsWith('youtube://') ||
      path.startsWith('http://') ||
      path.startsWith('https://');

  void _replaceSongInQueues(SongModel song) {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _queue[_currentIndex] = song;
    }
    final originalIndex =
        _originalQueue.indexWhere((item) => item.id == song.id);
    if (originalIndex >= 0) _originalQueue[originalIndex] = song;
  }

  Future<void> _updateMediaQueue() async {
    final items = _queue
        .map((song) => MediaItem(
              id: song.id,
              album: song.album,
              title: song.title,
              artist: song.artist,
              duration: song.duration,
            ))
        .toList();
    super.queue.add(items);
  }

  @override
  Future<void> play() async {
    final duration = _player.duration;
    final isAtEnd = _player.processingState == ProcessingState.completed ||
        (duration != null &&
            duration > Duration.zero &&
            _player.position >= duration - const Duration(milliseconds: 300));
    if (isAtEnd) await _player.seek(Duration.zero);
    _playWithoutBlocking();
  }

  void _playWithoutBlocking() {
    unawaited(
        _activateAndPlay().catchError((Object error, StackTrace stackTrace) {
      debugPrint('Playback start failed: $error\n$stackTrace');
      unawaited(_db.insertErrorLog(
        'playback_start',
        error.toString(),
        stackTrace.toString(),
      ));
    }));
  }

  Future<void> _activateAndPlay() async {
    // iOS can leave an interrupted session inactive while the player clock
    // still advances. Reactivate it for every manual or automatic transition.
    final session = await AudioSession.instance;
    await session.setActive(true);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await _playCurrent();
    } else if (_repeatMode == LoopStyle.all) {
      _currentIndex = 0;
      await _playCurrent();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrent();
    }
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  double? _playbackSpeedOverride;
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeedOverride = speed;
    await _player.setSpeed(speed);
  }

  double? _volumeOverride;
  Future<void> setVolume(double boost) async {
    _volumeOverride = boost.clamp(0.5, 2.0);
    await _player.setVolume(_volumeOverride!);
  }

  Future<void> setCrossfade(Duration duration) async {
    _crossfadeDuration = duration;
    // If currently playing, restart crossfade monitoring
    if (_player.playing && _crossfadeDuration > Duration.zero) {
      _crossfadeSubscription?.cancel();
      _crossfadeSubscription = _player.positionStream.listen((position) {
        final totalDuration = _player.duration;
        if (totalDuration == null || !_player.playing) return;
        final remaining = totalDuration - position;
        if (remaining <= _crossfadeDuration && remaining > Duration.zero) {
          _crossfadeSubscription?.cancel();
          _crossfadeSubscription = null;
          unawaited(_onTrackComplete());
        }
      });
    } else {
      _crossfadeSubscription?.cancel();
      _crossfadeSubscription = null;
    }
  }

  Future<void> setAutoShuffle(bool enabled) async {
    _autoShuffleEnabled = enabled;
    if (enabled && !_isShuffled) {
      await toggleShuffle();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.all && !_isShuffled) {
      await toggleShuffle();
    } else if (shuffleMode == AudioServiceShuffleMode.none && _isShuffled) {
      await toggleShuffle();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'seekForward':
        _player.seek(Duration(seconds: _player.position.inSeconds + 10));
        break;
      case 'seekBackward':
        _player.seek(Duration(seconds: _player.position.inSeconds - 10));
        break;
    }
  }

  @override
  Future<int> addQueueItem(MediaItem mediaItem) async {
    final song = _queue.firstWhereOrNull((s) => s.id == mediaItem.id);
    if (song != null) {
      _queue.add(song);
      _originalQueue.add(song);
      await _updateMediaQueue();
      return _queue.length - 1;
    }
    return -1;
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _originalQueue.length) _originalQueue.removeAt(index);
    await _updateMediaQueue();
  }

  @override
  Future<void> click([MediaButton? button]) async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  void dispose() {
    _saveStateTimer?.cancel();
    _crossfadeSubscription?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
  }
}

@immutable
class PlaybackDurationPolicy {
  const PlaybackDurationPolicy._();

  static Duration effectiveDuration({
    required Duration expected,
    required Duration decoded,
    required bool isRemote,
  }) {
    if (decoded <= Duration.zero) return expected;
    if (!isRemote || expected <= Duration.zero) return decoded;

    final toleranceMs = _toleranceMs(expected);
    final excessMs = decoded.inMilliseconds - expected.inMilliseconds;
    return excessMs > toleranceMs ? expected : decoded;
  }

  static bool shouldStopAt({
    required Duration position,
    required Duration effectiveDuration,
    required Duration decodedDuration,
  }) {
    if (effectiveDuration <= Duration.zero ||
        decodedDuration <= effectiveDuration ||
        decodedDuration.inMilliseconds - effectiveDuration.inMilliseconds <
            _toleranceMs(effectiveDuration)) {
      return false;
    }
    return position >= effectiveDuration - const Duration(milliseconds: 250);
  }

  static int _toleranceMs(Duration duration) {
    final proportional = (duration.inMilliseconds * 0.03).round();
    return proportional > 7000 ? proportional : 7000;
  }
}

@immutable
class PlaybackFailurePlan {
  const PlaybackFailurePlan._();

  static List<int> candidateIndices({
    required int currentIndex,
    required int queueLength,
    required LoopStyle repeatMode,
  }) {
    if (queueLength <= 1 || currentIndex < 0 || currentIndex >= queueLength) {
      return const [];
    }

    final candidates = <int>[];
    for (var index = currentIndex + 1; index < queueLength; index++) {
      candidates.add(index);
    }
    if (repeatMode == LoopStyle.all) {
      for (var index = 0; index < currentIndex; index++) {
        candidates.add(index);
      }
    }
    return candidates;
  }
}

enum LoopStyle { off, all, one }

enum PlaybackCompletionAction { replayCurrent, playIndex, rewindAndPause }

@immutable
class PlaybackCompletionDecision {
  const PlaybackCompletionDecision._(this.action, [this.nextIndex]);

  final PlaybackCompletionAction action;
  final int? nextIndex;

  static PlaybackCompletionDecision decide({
    required int currentIndex,
    required int queueLength,
    required LoopStyle repeatMode,
  }) {
    if (repeatMode == LoopStyle.one) {
      return const PlaybackCompletionDecision._(
        PlaybackCompletionAction.replayCurrent,
      );
    }
    if (currentIndex + 1 < queueLength) {
      return PlaybackCompletionDecision._(
        PlaybackCompletionAction.playIndex,
        currentIndex + 1,
      );
    }
    if (repeatMode == LoopStyle.all && queueLength > 0) {
      return const PlaybackCompletionDecision._(
        PlaybackCompletionAction.playIndex,
        0,
      );
    }
    return const PlaybackCompletionDecision._(
      PlaybackCompletionAction.rewindAndPause,
    );
  }
}

class _CachedStream {
  _CachedStream(this.url)
      : expiresAt = DateTime.now().add(AudioPlayerHandler._ytStreamCacheTtl);

  final String url;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
