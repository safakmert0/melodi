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
      backgroundColor: const Color(0xFF07080C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Kapak Akışı'),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.15,
            colors: [
              colors.primary .withOpacity(0.24),
              const Color(0xFF07080C),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const Spacer(),
              SizedBox(
                height: MediaQuery.sizeOf(context).width * 0.78,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: queue.length,
                  onPageChanged: (index) =>
                      setState(() => _selectedIndex = index),
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: _controller!,
                    builder: (context, child) {
                      var page = _selectedIndex.toDouble();
                      if (_controller!.hasClients &&
                          _controller!.position.haveDimensions) {
                        page = _controller!.page ?? page;
                      }
                      final delta = (index - page).clamp(-1.0, 1.0);
                      final scale = 1 - delta.abs() * 0.17;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014)
                          ..rotateY(-delta * 0.42)
                          ..scale(scale, scale, 1),
                        child: child,
                      );
                    },
                    child: _CoverCard(
                      song: queue[index],
                      active: index == player.currentIndex,
                      onTap: () async {
                        await player.playFromQueue(queue, index);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      selected.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      selected.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_selectedIndex + 1} / ${queue.length} · Kapağa dokunarak çal',
                      style: TextStyle(
                        color: Colors.white .withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
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
    return Semantics(
      button: true,
      label: '${song.title}, ${song.artist}',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: active
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black .withOpacity(0.65),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: song.albumArt == null
                  ? ColoredBox(
                      color: const Color(0xFF1C1E27),
                      child: Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: 72,
                          color: Colors.white .withOpacity(0.25),
                        ),
                      ),
                    )
                  : Image.memory(
                      song.albumArt!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF1C1E27),
                        child: Icon(Icons.album_rounded, size: 72),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
