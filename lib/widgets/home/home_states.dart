import 'package:flutter/material.dart';

import '../../core/melodi_design.dart';
import '../../providers/library_provider.dart';
import '../../screens/source_hub_screen.dart';

class HomeLibraryError extends StatelessWidget {
  const HomeLibraryError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: MelodiPanel(
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Yenile')),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeEmptyLibrary extends StatelessWidget {
  const HomeEmptyLibrary({super.key, required this.library});
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 170),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.library_music_rounded,
              size: 28,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Kitaplığını oluştur',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dosyalarını içe aktar veya bir müzik hesabı bağla. '
            'Melodi hepsini tek kitaplıkta düzenler.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: library.importFromFiles,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Müzik ekle'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SourceHubScreen()),
            ),
            icon: const Icon(Icons.hub_rounded, size: 18),
            label: const Text('Hesap bağla'),
          ),
        ],
      ),
    );
  }
}
