import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/wrong_match_service.dart';
import '../services/ytmusic_service.dart';

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
    return IconButton(
      icon: Icon(Icons.flag_outlined, size: 18, color: MelodiTheme.textMuted),
      tooltip: AppLocale.tr('wrong_match'),
      onPressed: () => _showAlternatives(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Future<void> _showAlternatives(BuildContext context) async {
    final service = WrongMatchService();
    if (currentYtVideoId != null) {
      await service.flagWrongMatch(spotifyTrackId, currentYtVideoId!);
    }

    final alternatives = await service.getAlternatives(title, artist);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiTheme.containerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MelodiTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  AppLocale.tr('find_alternative'),
                  style: TextStyle(
                    color: MelodiTheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$title - $artist',
                  style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: MelodiTheme.outlineVariant, height: 1),
              if (alternatives.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48, color: MelodiTheme.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        AppLocale.tr('no_alternatives'),
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: alternatives.length,
                    itemBuilder: (context, index) {
                      final alt = alternatives[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: MelodiTheme.containerLow,
                            child: alt.thumbnailUrl != null
                                ? Image.network(alt.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        Icons.music_note_rounded,
                                        color: MelodiTheme.textMuted))
                                : Icon(Icons.music_note_rounded,
                                    color: MelodiTheme.textMuted),
                          ),
                        ),
                        title: Text(
                          alt.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: MelodiTheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          alt.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: MelodiTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () async {
                          await service.resolveAndUpdate(
                              spotifyTrackId, alt.videoId);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            onResolved?.call();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${AppLocale.tr('wrong_match')} → ${alt.title}'),
                                backgroundColor: MelodiTheme.primaryGreen,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
