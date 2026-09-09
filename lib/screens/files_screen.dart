import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_scanner_service.dart';
import '../services/storage_manager.dart';
import '../widgets/song_tile.dart';
import '../models/song_model.dart';

/// LA_Player FilesTab birebir: Imported Files klasörü + pull-to-refresh
/// + Import Files / Import Folder + dosya listesi + çalma
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;
  String _currentPath = '';
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final base = await StorageManager.instance.getStorageLocation();
      final dir = Directory(base);
      if (!await dir.exists()) await dir.create(recursive: true);
      // LA_Player gibi Imported Files klasörünü garanti et
      final imported = Directory('${dir.path}/Imported Files');
      if (!await imported.exists()) await imported.create(recursive: true);
      final path = _currentPath.isEmpty ? dir.path : _currentPath;
      final entities = Directory(path).listSync();
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      if (mounted) {
        setState(() {
          _files = entities;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    // LA_Player: pull to refresh → yeniden tara + kütüphaneyi yenile
    await context.read<LibraryProvider>().scanMusic();
    await _load();
  }

  /// Bulunulan klasörü yerinde yeniden tarar (kopyasız) + listeyi yeniler.
  Future<void> _rescan() async {
    final messenger = ScaffoldMessenger.of(context);
    final library = context.read<LibraryProvider>();
    setState(() => _loading = true);
    try {
      final base = await StorageManager.instance.getStorageLocation();
      final dir = _currentPath.isEmpty ? base : _currentPath;
      final added = await MusicScannerService().scanDirectoryAndSync(dir);
      if (mounted) {
        await library.refresh();
        await _load();
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(added.isEmpty
                ? 'Yeni dosya yok'
                : '${added.length} yeni parça eklendi'),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enterDir(String path) async {
    setState(() => _currentPath = path);
    await _load();
  }

  Future<void> _goUp() async {
    if (_currentPath.isEmpty) return;
    final base = await StorageManager.instance.getStorageLocation();
    if (_currentPath == base) {
      setState(() => _currentPath = '');
      await _load();
      return;
    }
    final parent = Directory(_currentPath).parent.path;
    final basePath = Directory(base).path;
    if (!parent.startsWith(basePath)) {
      setState(() => _currentPath = '');
    } else {
      setState(() => _currentPath = parent == basePath ? '' : parent);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseFuture = StorageManager.instance.getStorageLocation();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Files'),
        centerTitle: true,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            tooltip: 'Import Files',
            icon: const Icon(Icons.audio_file_rounded),
            onPressed: () async {
              await context.read<LibraryProvider>().importFromFiles();
              await _load();
            },
          ),
          IconButton(
            tooltip: 'Import Folder',
            icon: const Icon(Icons.folder_copy_rounded),
            onPressed: () async {
              await context.read<LibraryProvider>().importFromDirectory();
              await _load();
            },
          ),
          IconButton(
            tooltip: 'Tekrar tara',
            icon: const Icon(Icons.sync_rounded),
            onPressed: _rescan,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: baseFuture,
        builder: (context, snap) {
          final base = snap.data ?? '';
          final displayPath = _currentPath.isEmpty
              ? 'Imported Files'
              : _currentPath.replaceFirst(base, '').replaceFirst(RegExp(r'^/'), '');
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: cs.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    if (_currentPath.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        onPressed: _goUp,
                      ),
                    Expanded(
                      child: Text(
                        displayPath.isEmpty ? 'Files' : displayPath,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _onRefresh,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Yenile', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: cs.surfaceContainer.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Please do not delete the Imported Files folder. Save audio files or folders inside this folder. Then pull to refresh to import.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: cs.primary))
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: _files.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  Icon(Icons.folder_open_rounded,
                                      size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Text('No audio files found in folder',
                                        style: TextStyle(color: cs.onSurfaceVariant)),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text('Import Files veya Import Folder ile ekle',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                                            fontSize: 12)),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                itemCount: _files.length,
                                itemBuilder: (context, i) {
                                  final e = _files[i];
                                  final isDir = e is Directory;
                                  final name = e.path.split(Platform.pathSeparator).last;
                                  final isAudio = !isDir &&
                                      RegExp(r'\.(mp3|m4a|flac|wav|aac|ogg|opus|wma|aiff|alac)$',
                                              caseSensitive: false)
                                          .hasMatch(name);
                                  return ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isDir
                                            ? Icons.folder_rounded
                                            : (isAudio
                                                ? Icons.music_note_rounded
                                                : Icons.insert_drive_file_rounded),
                                        color: cs.onSurfaceVariant,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    subtitle: isDir
                                        ? const Text('Klasör', style: TextStyle(fontSize: 11))
                                        : FutureBuilder<int>(
                                            future: File(e.path).length().then((v) => v).catchError((_) => 0),
                                            builder: (context, snap) {
                                              final kb = (snap.data ?? 0) / 1024;
                                              return Text(
                                                  isAudio
                                                      ? '${kb.toStringAsFixed(0)} KB • Tap to play'
                                                      : '${kb.toStringAsFixed(0)} KB',
                                                  style: TextStyle(
                                                      fontSize: 11, color: cs.onSurfaceVariant));
                                            },
                                          ),
                                    trailing: isDir
                                        ? const Icon(Icons.chevron_right_rounded, size: 18)
                                        : IconButton(
                                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                            onPressed: isAudio ? () => _playFile(e.path) : null,
                                          ),
                                    onTap: () {
                                      if (isDir) _enterDir(e.path);
                                      else if (isAudio) _playFile(e.path);
                                    },
                                    onLongPress: isDir
                                        ? null
                                        : () => _showFileActions(e.path, name),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _playFile(String path) async {
    final lib = context.read<LibraryProvider>();
    // Dosyayı kütüphanede bul veya geçici SongModel ile çal
    SongModel? match;
    for (final s in lib.songs) {
      if (s.filePath == path) {
        match = s;
        break;
      }
    }
    final stat = await File(path).stat();
    match ??= SongModel(
      id: 'file:${path.hashCode}',
      title: path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.[^.]+$'), ''),
      artist: 'Bilinmeyen sanatçı',
      album: '',
      filePath: path,
      duration: Duration.zero,
      fileSize: stat.size,
    );
    await context.read<PlayerProvider>().playSong(match);
  }

  void _showFileActions(String path, String name) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Çal'),
              onTap: () {
                Navigator.pop(context);
                _playFile(path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Çalma listesine ekle'),
              onTap: () {
                Navigator.pop(context);
                // playlist ekleme handled via provider elsewhere
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kitaplık üzerinden listeye ekleyebilirsin')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Sil'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sil?'),
                    content: Text('"$name" silinsin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await File(path).delete();
                    await _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('"$name" silindi')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
