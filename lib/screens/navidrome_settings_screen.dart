import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/melodi_design.dart';
import '../models/song_model.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../services/music_source.dart';
import '../services/navidrome_service.dart';

class NavidromeSettingsScreen extends StatefulWidget {
  const NavidromeSettingsScreen({super.key});

  @override
  State<NavidromeSettingsScreen> createState() =>
      _NavidromeSettingsScreenState();
}

class _NavidromeSettingsScreenState extends State<NavidromeSettingsScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = NavidromeService.instance;

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;
  Future<List<NavidromePlaylist>>? _playlists;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final credentials = await _service.loadConfiguration();
    if (!mounted) return;
    if (credentials != null) {
      _serverController.text = credentials.serverUrl;
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
      _playlists = _service.getPlaylists();
    }
    setState(() => _loading = false);
  }

  Future<void> _connect() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.connect(
        serverUrl: _serverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _playlists = _service.getPlaylists());
      _message('Navidrome sunucusuna bağlandı');
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnect();
    if (!mounted) return;
    _passwordController.clear();
    setState(() => _playlists = null);
    _message('Navidrome bağlantısı kaldırıldı');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Navidrome / Subsonic')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                MelodiPanel(
                  emphasized: _service.isConnected,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C8CFF)
                                   .withOpacity(0.16),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.dns_rounded,
                              color: Color(0xFF6C8CFF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _service.isConnected
                                      ? 'Kişisel kitaplığın bağlı'
                                      : 'Kişisel müzik sunucunu bağla',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Navidrome ve Subsonic uyumlu sunuculardan tam parça, kayıpsız akış ve çevrimdışı indirme.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _serverController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Sunucu adresi',
                          hintText: 'https://music.example.com',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameController,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı adı',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Parola',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Göster' : 'Gizle',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Parola cihazın güvenli anahtar zincirinde tutulur. İsteklerde parola yerine her istekte yenilenen tuzlu kimlik doğrulama anahtarı kullanılır. Sunucu bağlantısında HTTPS gerekir.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _connect,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.link_rounded),
                              label: Text(
                                _service.isConnected
                                    ? 'Bağlantıyı doğrula'
                                    : 'Bağlan',
                              ),
                            ),
                          ),
                          if (_service.isConnected) ...[
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'Bağlantıyı kaldır',
                              onPressed: _saving ? null : _disconnect,
                              icon: const Icon(Icons.link_off_rounded),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (_service.isConnected) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sunucudaki listeler',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Yenile',
                        onPressed: () => setState(
                          () => _playlists = _service.getPlaylists(),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<NavidromePlaylist>>(
                    future: _playlists,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _InfoCard(
                          icon: Icons.cloud_off_rounded,
                          text: _friendlyError(snapshot.error!),
                        );
                      }
                      final playlists = snapshot.data ?? const [];
                      if (playlists.isEmpty) {
                        return const _InfoCard(
                          icon: Icons.queue_music_rounded,
                          text: 'Sunucuda çalma listesi bulunamadı.',
                        );
                      }
                      return Column(
                        children: [
                          for (final playlist in playlists)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlaylistCard(
                                playlist: playlist,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => NavidromePlaylistScreen(
                                      playlist: playlist,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('Connection refused')) {
      return 'Sunucu bağlantıyı reddetti. Adresi ve ağı kontrol et.';
    }
    if (text.contains('Failed host lookup')) {
      return 'Sunucu bulunamadı. Adresi ve internet bağlantısını kontrol et.';
    }
    return text;
  }

  void _message(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? colors.error : colors.primary,
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final NavidromePlaylist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = NavidromeService.instance.coverArtUrl(playlist.coverArt);
    return MelodiPanel(
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 58,
              height: 58,
              child: coverUrl == null
                  ? const ColoredBox(
                      color: Color(0x226C8CFF),
                      child: Icon(Icons.queue_music_rounded),
                    )
                  : Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0x226C8CFF),
                        child: Icon(Icons.queue_music_rounded),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${playlist.songCount} parça · ${_formatDuration(playlist.duration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class NavidromePlaylistScreen extends StatefulWidget {
  const NavidromePlaylistScreen({super.key, required this.playlist});

  final NavidromePlaylist playlist;

  @override
  State<NavidromePlaylistScreen> createState() =>
      _NavidromePlaylistScreenState();
}

class _NavidromePlaylistScreenState extends State<NavidromePlaylistScreen> {
  final _service = NavidromeService.instance;
  late Future<List<OnlineTrack>> _tracks;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tracks = _service.getPlaylistTracks(widget.playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.name)),
      body: FutureBuilder<List<OnlineTrack>>(
        future: _tracks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Liste yüklenemedi: ${snapshot.error}'),
              ),
            );
          }
          final tracks = snapshot.data ?? const [];
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, tracks)),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) => _trackTile(tracks[index]),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, List<OnlineTrack> tracks) {
    final theme = Theme.of(context);
    final coverUrl = _service.coverArtUrl(widget.playlist.coverArt, size: 800);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: coverUrl == null
                  ? const ColoredBox(
                      color: Color(0x226C8CFF),
                      child: Icon(Icons.queue_music_rounded, size: 64),
                    )
                  : Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0x226C8CFF),
                        child: Icon(Icons.queue_music_rounded, size: 64),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.playlist.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${tracks.length} parça · kişisel sunucu',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      tracks.isEmpty || _busy ? null : () => _playAll(tracks),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Tümünü çal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: tracks.isEmpty ? null : () => _downloadAll(tracks),
                  icon: const Icon(Icons.download_for_offline_rounded),
                  label: const Text('Tümünü indir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trackTile(OnlineTrack track) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 48,
          height: 48,
          child: track.thumbnailUrl == null
              ? const ColoredBox(
                  color: Color(0x226C8CFF),
                  child: Icon(Icons.music_note_rounded),
                )
              : Image.network(
                  track.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0x226C8CFF),
                    child: Icon(Icons.music_note_rounded),
                  ),
                ),
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artist} · ${_formatDuration(track.duration)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'play') _playTrack(track);
          if (value == 'download') _downloadTrack(track);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'play',
            child: ListTile(
              leading: Icon(Icons.play_arrow_rounded),
              title: Text('Oynat'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'download',
            child: ListTile(
              leading: Icon(Icons.download_rounded),
              title: Text('İndir'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () => _playTrack(track),
    );
  }

  Future<SongModel> _song(OnlineTrack track, {bool loadArtwork = false}) async {
    final artwork =
        loadArtwork ? await _service.fetchArtwork(track.thumbnailUrl) : null;
    return SongModel(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album ?? 'Navidrome',
      duration: track.duration,
      filePath: track.streamUrl ?? _service.streamUrl(track.id),
      albumArt: artwork,
      fileSize: 0,
    );
  }

  Future<void> _playTrack(OnlineTrack track) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final song = await _song(track, loadArtwork: true);
      if (!mounted) return;
      await context.read<PlayerProvider>().playSong(song);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _playAll(List<OnlineTrack> tracks) async {
    if (_busy || tracks.isEmpty) return;
    setState(() => _busy = true);
    try {
      final songs = <SongModel>[];
      for (var index = 0; index < tracks.length; index++) {
        songs.add(await _song(tracks[index], loadArtwork: index == 0));
      }
      if (!mounted) return;
      await context.read<PlayerProvider>().playFromQueue(songs, 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _downloadTrack(OnlineTrack track) {
    context.read<DownloadProvider>().enqueueTrack(
          spotifyTrackId: track.id,
          title: track.title,
          artist: track.artist,
          album: track.album,
          imageUrl: track.thumbnailUrl,
          expectedDurationMs: track.duration.inMilliseconds,
          directUrl: _service.downloadUrl(track.id),
        );
    _message('${track.title} indirme kuyruğuna eklendi');
  }

  void _downloadAll(List<OnlineTrack> tracks) {
    for (final track in tracks) {
      context.read<DownloadProvider>().enqueueTrack(
            spotifyTrackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            imageUrl: track.thumbnailUrl,
            expectedDurationMs: track.duration.inMilliseconds,
            directUrl: _service.downloadUrl(track.id),
          );
    }
    _message('${tracks.length} parça indirme kuyruğuna eklendi');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return MelodiPanel(
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours} sa $minutes dk';
  }
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inMinutes}:$seconds';
}
