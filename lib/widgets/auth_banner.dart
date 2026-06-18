import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/connection_provider.dart';

class AuthBanner extends StatelessWidget {
  final ConnectionProvider connection;
  final VoidCallback? onTap;

  const AuthBanner({
    super.key,
    required this.connection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppConstants.animationDuration,
      curve: Curves.easeInOut,
      child: connection.shouldShowBanner
          ? GestureDetector(
              onTap: onTap,
              child: Container(
                color: const Color(0xFFE65100),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _buildMessage(context),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: connection.dismiss,
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  String _buildMessage(BuildContext context) {
    if (connection.spotifyExpired && connection.ytMusicExpired) {
      return '${AppLocale.tr('spotify')} & ${AppLocale.tr('youtube_music')} ${AppLocale.tr('auth_expired')}';
    } else if (connection.spotifyExpired) {
      return AppLocale.tr('auth_expired_desc').replaceAll('{service}', AppLocale.tr('spotify'));
    } else {
      return AppLocale.tr('auth_expired_desc').replaceAll('{service}', AppLocale.tr('youtube_music'));
    }
  }
}
