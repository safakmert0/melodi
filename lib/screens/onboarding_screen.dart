import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../providers/theme_provider.dart';
import '../theme/app_tokens.dart';
import '../services/database_service.dart';
import '../widgets/main_shell.dart';
import '../widgets/splash_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;
  final PageController _controller = PageController();
  int _page = 0;
  bool _showSplash = true;

  String _copy(String tr, String en, String de) {
    switch (AppLocale.currentLocale) {
      case 'en':
        return en;
      case 'de':
        return de;
      default:
        return tr;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await DatabaseService.instance.setSetting('onboarding_completed', 'true');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  void _goTo(int page) {
    HapticFeedback.selectionClick();
    _controller.animateToPage(
      page.clamp(0, _pageCount - 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A direct dependency guarantees that language changes repaint the current
    // onboarding page immediately, without waiting for a page transition.
    context.watch<LocaleNotifier>().locale;
    if (_showSplash) {
      return SplashScreen(
        onComplete: () => setState(() => _showSplash = false),
      );
    }

    final theme = Theme.of(context);
    final accent = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              page: _page,
              pageCount: _pageCount,
              onBack: () => _goTo(_page - 1),
              onSkip: _complete,
              skipLabel: _copy('Atla', 'Skip', 'Überspringen'),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _buildWelcome(theme),
                  _buildLanguage(theme),
                  _buildTheme(theme),
                ],
              ),
            ),
            _BottomDock(
              page: _page,
              pageCount: _pageCount,
              accent: accent,
              label: _page == _pageCount - 1
                  ? _copy('Melodi’yi aç', 'Open Melodi', 'Melodi öffnen')
                  : _copy('Devam', 'Continue', 'Weiter'),
              onPressed: _page == _pageCount - 1
                  ? _complete
                  : () => _goTo(_page + 1),
            ),
          ],
        ),
      ),
    );
  }

  Color _pageAccent(ThemeData theme, int page) => switch (page) {
        1 => const Color(0xFF2EC4B6),
        2 => const Color(0xFF8C72FF),
        3 => const Color(0xFFFF9F43),
        _ => theme.colorScheme.primary,
      };

  Widget _pageBody({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(24, 12, 24, 12),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: child,
        ),
      ),
    );
  }

  Widget _buildWelcome(ThemeData theme) {
    return _pageBody(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorialMark(color: theme.colorScheme.primary),
          const SizedBox(height: 34),
          Text(
            _copy('Müzik, tek bir yerde.', 'Music, in one place.',
                'Musik an einem Ort.'),
            style: theme.textTheme.displayLarge,
          ),
          const SizedBox(height: 18),
          Text(
            _copy(
              'Yerel arşivin, çevrim içi kaynakların, indirmelerin ve canlı sözlerin için yeni nesil müzik alanı.',
              'A new home for your local library, online sources, downloads and live lyrics.',
              'Ein neues Zuhause für deine lokale Mediathek, Online-Quellen, Downloads und Live-Texte.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeaturePill(icon: Icons.offline_bolt_rounded, label: 'Offline'),
              _FeaturePill(
                  icon: Icons.lyrics_rounded,
                  label: _copy('Canlı söz', 'Live lyrics', 'Live-Texte')),
              _FeaturePill(
                  icon: Icons.hub_rounded,
                  label: _copy('Çoklu kaynak', 'Multi-source', 'Multi-Quelle')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguage(ThemeData theme) {
    final selected = context.watch<LocaleNotifier>().locale;
    final languages = [
      ('Türkçe', 'tr', 'TR'),
      ('English', 'en', 'EN'),
      ('Deutsch', 'de', 'DE'),
    ];
    return _pageBody(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(
              icon: Icons.translate_rounded, color: _pageAccent(theme, 1)),
          const SizedBox(height: 26),
          Text(_copy('Dilini seç', 'Choose your language', 'Sprache wählen'),
              style: theme.textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            _copy(
                'Seçim anında tüm kurulum akışına uygulanır.',
                'Your choice is applied to setup instantly.',
                'Deine Auswahl wird sofort auf die Einrichtung angewendet.'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          for (final language in languages) ...[
            _ChoiceTile(
              title: language.$1,
              badge: language.$3,
              selected: selected == language.$2,
              accent: _pageAccent(theme, 1),
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<LocaleNotifier>().change(language.$2);
                DatabaseService.instance.setSetting('app_locale', language.$2);
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildTheme(ThemeData theme) {
    final provider = context.watch<ThemeProvider>();
    final accent = _pageAccent(theme, 2);
    return _pageBody(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(icon: Icons.auto_awesome_rounded, color: accent),
          const SizedBox(height: 26),
          Text(
              _copy('Nasıl görünsün?', 'Choose your atmosphere',
                  'Wähle deine Atmosphäre'),
              style: theme.textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            _copy(
                'Her seçenek yüksek kontrast ve aynı premium kimlikle tasarlandı.',
                'Every option keeps high contrast and the same premium identity.',
                'Jede Option bietet hohen Kontrast und dieselbe Premium-Identität.'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          _ThemePreview(
            label: _copy('Sistem', 'System', 'System'),
            icon: Icons.brightness_auto_rounded,
            selected: provider.themeMode == ThemeMode.system,
            accent: accent,
            onTap: () => provider.setThemeMode(ThemeMode.system),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ThemePreview(
                  label: _copy('Açık', 'Light', 'Hell'),
                  icon: Icons.light_mode_rounded,
                  selected: provider.isLight,
                  accent: accent,
                  onTap: () => provider.setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemePreview(
                  label: _copy('Koyu', 'Dark', 'Dunkel'),
                  icon: Icons.dark_mode_rounded,
                  selected: provider.isDark,
                  accent: accent,
                  onTap: () => provider.setThemeMode(ThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSources(ThemeData theme) {
    final accent = _pageAccent(theme, 3);
    return _pageBody(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIcon(icon: Icons.hub_rounded, color: accent),
          const SizedBox(height: 26),
          Text(
              _copy('Kaynaklarını birleştir', 'Bring your sources together',
                  'Verbinde deine Quellen'),
              style: theme.textTheme.headlineLarge),
          const SizedBox(height: 10),
          Text(
            _copy(
              'Hesap bağlamak isteğe bağlıdır. Yerel müzik ve çevrim içi arama hemen kullanılabilir.',
              'Connecting accounts is optional. Local music and online search work right away.',
              'Konten sind optional. Lokale Musik und Online-Suche funktionieren sofort.',
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          _SourcePreview(
            icon: Icons.music_note_rounded,
            title: 'Spotify',
            subtitle: _copy('Kitaplık ve çalma listeleri',
                'Library and playlists', 'Mediathek und Playlists'),
            color: const Color(0xFF1ED760),
          ),
          const SizedBox(height: 10),
          _SourcePreview(
            icon: Icons.play_arrow_rounded,
            title: 'YouTube Music',
            subtitle: _copy(
                'Tam parça kaynağı ve keşif',
                'Full-track source and discovery',
                'Volltitel-Quelle und Entdecken'),
            color: const Color(0xFFFF3B30),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SourceHubScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
            label: Text(_copy(
                'Kaynakları yönet', 'Manage sources', 'Quellen verwalten')),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.pageCount,
    required this.onBack,
    required this.onSkip,
    required this.skipLabel,
  });

  final int page;
  final int pageCount;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: page == 0
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pageCount,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: page == index ? 24 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: page == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: page == pageCount - 1
                ? null
                : TextButton(onPressed: onSkip, child: Text(skipLabel)),
          ),
        ],
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.page,
    required this.pageCount,
    required this.accent,
    required this.label,
    required this.onPressed,
  });

  final int page;
  final int pageCount;
  final Color accent;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colors.onSurface,
            foregroundColor: colors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Icon(
                  page == pageCount - 1
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialMark extends StatelessWidget {
  const _EditorialMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 0,
            child: Transform.rotate(
              angle: -0.12,
              child: _AlbumTile(color: color, icon: Icons.graphic_eq_rounded),
            ),
          ),
          Positioned(
            left: 112,
            top: 24,
            child: Transform.rotate(
              angle: 0.11,
              child: const _AlbumTile(
                  color: Color(0xFF8C72FF), icon: Icons.waves_rounded),
            ),
          ),
          Positioned(
            left: 205,
            top: 4,
            child: Transform.rotate(
              angle: -0.04,
              child: const _AlbumTile(
                  color: Color(0xFF2EC4B6), icon: Icons.music_note_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 112,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Icon(icon, color: colors.onSurfaceVariant, size: 28),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Icon(icon, color: colors.onSurfaceVariant, size: 22),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.badge,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String title;
  final String badge;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(badge,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontSize: 11)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontSize: 14))),
              Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourcePreview extends StatelessWidget {
  const _SourcePreview({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
