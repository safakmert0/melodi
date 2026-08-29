import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../providers/player_provider.dart';

class CoverFlowScreen extends StatefulWidget {
  const CoverFlowScreen({super.key});

  @override
  State<CoverFlowScreen> createState() => _CoverFlowScreenState();
}

class _CoverFlowScreenState extends State<CoverFlowScreen> {
  PageController? _controller;
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final player = context.read<PlayerProvider>();
    _selectedIndex =
        player.currentIndex.clamp(0, math.max(0, player.queue.length - 1));
    _controller = PageController(
      viewportFraction: 0.72,
      initialPage: _selectedIndex,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;
    if (queue.isEmpty) {
      return const Scaffold(body: Center(child: Text('Oynatma sırası boş')));
    }
    if (_selectedIndex >= queue.length) _selectedIndex = queue.length - 1;
    final selected = queue[_selectedIndex];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Kapak Akışı',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              height: MediaQuery.sizeOf(context).width * 0.72,
              child: PageView.builder(
                controller: _controller,
                itemCount: queue.length,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                itemBuilder: (context, index) => _CoverCard(
                  song: queue[index],
                  active: index == player.currentIndex,
                  onTap: () async {
                    await player.playFromQueue(queue, index);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    selected.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedIndex + 1} / ${queue.length} · Kapağa dokunarak çal',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.song,
    required this.active,
    required this.onTap,
  });

  final SongModel song;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${song.title}, ${song.artist}',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? colors.onSurface : colors.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: song.albumArt == null
                  ? ColoredBox(
                      color: colors.surfaceContainer,
                      child: Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: 40,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Image.memory(
                      song.albumArt!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colors.surfaceContainer,
                        child: Icon(Icons.album_rounded,
                            size: 40, color: colors.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
