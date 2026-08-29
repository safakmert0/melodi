import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/wrong_match_service.dart';

class WrongMatchButton extends StatelessWidget {
  final String spotifyTrackId;
  final String? currentYtVideoId;
  final String title;
  final String artist;
  final VoidCallback? onResolved;

  const WrongMatchButton({
    super.key,
    required this.spotifyTrackId,
    this.currentYtVideoId,
    required this.title,
    required this.artist,
    this.onResolved,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.flag_outlined, size: 18, color: scheme.onSurfaceVariant),
      tooltip: AppLocale.tr('wrong_match'),
      onPressed: () => _showAlternatives(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Future<void> _showAlternatives(BuildContext context) async {
    final service = WrongMatchService();
    if (currentYtVideoId != null) await service.flagWrongMatch(spotifyTrackId, currentYtVideoId!);
    final alternatives = await service.getAlternatives(title, artist);
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12)), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      builder: (ctx) {
        final s = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 32, height: 3, decoration: BoxDecoration(color: s.outlineVariant, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(AppLocale.tr('find_alternative'), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: s.onSurface, fontWeight: FontWeight.w600))),
              const SizedBox(height: 4),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$title - $artist', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant), textAlign: TextAlign.center)),
              const SizedBox(height: 12),
              Divider(color: s.outlineVariant.withValues(alpha: 0.5), height: 1),
              if (alternatives.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [Icon(Icons.search_off_rounded, size: 40, color: s.onSurfaceVariant), const SizedBox(height: 12), Text(AppLocale.tr('no_alternatives'), style: TextStyle(color: s.onSurfaceVariant, fontSize: 13))]),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: alternatives.length,
                    itemBuilder: (context, index) {
                      final alt = alternatives[index];
                      final sc = Theme.of(context).colorScheme;
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: sc.surfaceContainerHighest,
                            child: alt.thumbnailUrl != null
                                ? Image.network(alt.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, color: sc.onSurfaceVariant))
                                : Icon(Icons.music_note_rounded, color: sc.onSurfaceVariant),
                          ),
                        ),
                        title: Text(alt.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: sc.onSurface, fontSize: 13)),
                        subtitle: Text(alt.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sc.onSurfaceVariant)),
                        onTap: () async {
                          await service.resolveAndUpdate(spotifyTrackId, alt.id);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            onResolved?.call();
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${AppLocale.tr('wrong_match')} → ${alt.title}')));
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
