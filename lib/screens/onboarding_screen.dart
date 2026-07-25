import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/splash_screen.dart';
import '../widgets/main_shell.dart';
import 'settings_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showSplash = true;
  String _downloadPath = '';
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await DatabaseService.instance.setSetting('onboarding_completed', 'true');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          setState(() => _showSplash = false);
          _fadeController.forward();
          _slideController.forward();
        },
      );
    }

    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: FadeTransition(
        opacity: _fadeController,
        child: Stack(
          children: [
            // Animated background gradient
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPageColor(_currentPage).withOpacity(0.12),
                      MelodiTheme.background,
                      MelodiTheme.background,
                      _getPageColor(_currentPage).withOpacity(0.06),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            // Floating orbs
            Positioned.fill(
              child: CustomPaint(
                painter: _OrbPainter(
                  color: _getPageColor(_currentPage),
                  progress: _currentPage / 4,
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  _buildTopBar(),
                  // Page content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildWelcomePage(),
                        _buildLanguagePage(),
                        _buildThemePage(),
                        _buildServicesPage(),
                        _buildDownloadPage(),
                      ],
                    ),
                  ),
                  // Bottom section
                  _buildBottomSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPageColor(int page) {
    switch (page) {
      case 0:
        return MelodiTheme.primaryGreen;
      case 1:
        return const Color(0xFF42A5F5);
      case 2:
        return const Color(0xFF64B5F6);
      case 3:
        return MelodiTheme.primaryContainer;
      case 4:
        return const Color(0xFF8D67AB);
      default:
        return MelodiTheme.primaryGreen;
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            GestureDetector(
              onTap: _prevPage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MelodiTheme.surfaceBright.withOpacity(0.5),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: MelodiTheme.onSurface,
                ),
              ),
            )
          else
            const SizedBox(width: 40),
          const Spacer(),
          // Skip button
          if (_currentPage < 4)
            GestureDetector(
              onTap: _complete,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MelodiTheme.outlineVariant.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  AppLocale.tr('skip'),
                  style: MelodiTheme.bodySm(
                    color: MelodiTheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated logo with glow
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeOutBack,
            )),
            child: FadeTransition(
              opacity: _slideController,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: MelodiTheme.primaryGreen.withOpacity(0.25),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MelodiTheme.primaryGreen.withOpacity(0.15),
                        MelodiTheme.primaryGreen.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: MelodiTheme.primaryGreen.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MelodiTheme.primaryGreen.withOpacity(0.2),
                            MelodiTheme.primaryGreen.withOpacity(0.08),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 52,
                        color: MelodiTheme.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 56),
          // Title
          Text(
            AppLocale.tr('welcome_to_melodi'),
            style: MelodiTheme.display(size: 44),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Subtitle
          Text(
            AppLocale.tr('onboarding_welcome_desc'),
            style: MelodiTheme.body(
              size: 19,
              color: MelodiTheme.onSurfaceVariant.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Feature highlights
          _FeatureRow(
            icon: Icons.bolt_rounded,
            text: AppLocale.tr('signal_path_preparing'),
          ),
          const SizedBox(height: 12),
          _FeatureRow(
            icon: Icons.shield_rounded,
            text: AppLocale.tr('scanning_library'),
          ),
          const SizedBox(height: 12),
          _FeatureRow(
            icon: Icons.favorite_rounded,
            text: AppLocale.tr('enjoy_listening'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MelodiTheme.primaryGreen.withOpacity(0.15),
                  MelodiTheme.primaryGreen.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: MelodiTheme.primaryGreen.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.language_rounded,
              size: 40,
              color: MelodiTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 44),
          // Title
          Text(
            AppLocale.tr('choose_language'),
            style: MelodiTheme.heading(size: 38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            AppLocale.tr('onboarding_language_desc'),
            style: MelodiTheme.body(
              size: 18,
              color: MelodiTheme.onSurfaceVariant.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 44),
          _LanguageSelector(),
        ],
      ),
    );
  }

  Widget _buildThemePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MelodiTheme.primaryGreen.withOpacity(0.15),
                  MelodiTheme.primaryGreen.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: MelodiTheme.primaryGreen.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.palette_rounded,
              size: 40,
              color: MelodiTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 44),
          // Title
          Text(
            AppLocale.tr('choose_theme'),
            style: MelodiTheme.heading(size: 38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            AppLocale.tr('onboarding_theme_desc'),
            style: MelodiTheme.body(
              size: 18,
              color: MelodiTheme.onSurfaceVariant.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 44),
          _ThemeSelector(),
        ],
      ),
    );
  }

  Widget _buildServicesPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MelodiTheme.primaryGreen.withOpacity(0.15),
                  MelodiTheme.primaryGreen.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: MelodiTheme.primaryGreen.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.sync_rounded,
              size: 40,
              color: MelodiTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 44),
          // Title
          Text(
            AppLocale.tr('connect_services'),
            style: MelodiTheme.heading(size: 38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            AppLocale.tr('onboarding_services_desc'),
            style: MelodiTheme.body(
              size: 18,
              color: MelodiTheme.onSurfaceVariant.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 44),
          // Service cards
          _ServiceCard(
            icon: Icons.music_note_rounded,
            iconColor: const Color(0xFF2196F3),
            title: 'Spotify',
            subtitle: AppLocale.tr('spotify_subtitle'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          _ServiceCard(
            icon: Icons.play_circle_rounded,
            iconColor: const Color(0xFFFF0000),
            title: 'YouTube Music',
            subtitle: AppLocale.tr('youtube_subtitle'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MelodiTheme.primaryGreen.withOpacity(0.12),
              border:
                  Border.all(color: MelodiTheme.primaryGreen.withOpacity(0.25)),
            ),
            child: const Icon(Icons.folder_special_rounded,
                size: 40, color: MelodiTheme.primaryGreen),
          ),
          const SizedBox(height: 36),
          Text('İndirme konumunu seç',
              style: MelodiTheme.heading(size: 30),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text(
            'Çevrimdışı müziklerin kaydedileceği klasörü şimdi seçebilirsin. Daha sonra Ayarlar bölümünden değiştirebilirsin.',
            style:
                MelodiTheme.body(size: 16, color: MelodiTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MelodiTheme.containerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MelodiTheme.outlineVariant),
            ),
            child: Text(
              _downloadPath.isEmpty
                  ? 'Varsayılan uygulama klasörü kullanılacak'
                  : _downloadPath,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MelodiTheme.bodySm(color: MelodiTheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              final path = await FilePicker.platform
                  .getDirectoryPath(dialogTitle: 'İndirme klasörünü seç');
              if (!mounted || path == null || path.isEmpty) return;
              await DatabaseService.instance.setSetting('download_path', path);
              setState(() => _downloadPath = path);
            },
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Klasör seç'),
            style: FilledButton.styleFrom(
              backgroundColor: MelodiTheme.primaryGreen,
              foregroundColor: MelodiTheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          Text('Seçmeden devam edersen varsayılan konum kullanılır.',
              style: MelodiTheme.labelSm(color: MelodiTheme.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 16, 40, 40),
      child: Column(
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [MelodiTheme.primaryGreen, Color(0xFF42A5F5)],
                        )
                      : null,
                  color: isActive
                      ? null
                      : MelodiTheme.surfaceBright.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: MelodiTheme.primaryGreen.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          // Next button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: MelodiTheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentPage < 4
                        ? AppLocale.tr('next')
                        : AppLocale.tr('get_started'),
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _currentPage < 4
                        ? Icons.arrow_forward_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Floating orb painter
class _OrbPainter extends CustomPainter {
  final Color color;
  final double progress;

  _OrbPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final orbs = [
      Offset(size.width * 0.8, size.height * 0.15),
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.85, size.height * 0.85),
    ];

    for (int i = 0; i < orbs.length; i++) {
      final orbProgress = (progress + i * 0.33) % 1.0;
      final radius = 60.0 + orbProgress * 40.0;
      final opacity = (0.03 + orbProgress * 0.02).clamp(0.0, 0.05);

      paint.shader = RadialGradient(
        colors: [
          color.withOpacity(opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orbs[i], radius: radius));

      canvas.drawCircle(orbs[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// Feature row for welcome page
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MelodiTheme.primaryGreen.withOpacity(0.1),
          ),
          child: Icon(
            icon,
            size: 16,
            color: MelodiTheme.primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: MelodiTheme.bodySm(
            size: 15,
            color: MelodiTheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatefulWidget {
  @override
  State<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<_LanguageSelector> {
  String _selectedLocale = AppLocale.currentLocale;

  @override
  Widget build(BuildContext context) {
    final languages = [
      ('TÜRKÇE', 'tr', '\u{1F1F9}\u{1F1F7}'),
      ('English', 'en', '\u{1F1EC}\u{1F1E7}'),
      ('Deutsch', 'de', '\u{1F1E9}\u{1F1EA}'),
    ];

    return Column(
      children: languages.map((lang) {
        final isSelected = _selectedLocale == lang.$2;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedLocale = lang.$2);
            context.read<LocaleNotifier>().change(lang.$2);
            DatabaseService.instance.setSetting('app_locale', lang.$2);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        MelodiTheme.primaryGreen.withOpacity(0.12),
                        MelodiTheme.primaryGreen.withOpacity(0.05),
                      ],
                    )
                  : null,
              color: isSelected ? null : MelodiTheme.containerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? MelodiTheme.primaryGreen.withOpacity(0.5)
                    : MelodiTheme.outlineVariant.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(
                  lang.$3,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.$1,
                        style: TextStyle(
                          fontFamily: AppConstants.fontFamily,
                          fontSize: 19,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? MelodiTheme.primaryGreen
                              : MelodiTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MelodiTheme.primaryGreen,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: MelodiTheme.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ThemeOption(
          label: AppLocale.tr('dark'),
          icon: Icons.dark_mode_rounded,
          isSelected: context.watch<ThemeProvider>().isDark,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<ThemeProvider>().setThemeMode(ThemeMode.dark);
          },
        ),
        const SizedBox(width: 24),
        _ThemeOption(
          label: AppLocale.tr('light'),
          icon: Icons.light_mode_rounded,
          isSelected: context.watch<ThemeProvider>().isLight,
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<ThemeProvider>().setThemeMode(ThemeMode.light);
          },
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MelodiTheme.primaryGreen.withOpacity(0.12),
                    MelodiTheme.primaryGreen.withOpacity(0.05),
                  ],
                )
              : null,
          color: isSelected ? null : MelodiTheme.containerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? MelodiTheme.primaryGreen.withOpacity(0.5)
                : MelodiTheme.outlineVariant.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? MelodiTheme.primaryGreen.withOpacity(0.15)
                    : MelodiTheme.containerHigh,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected
                    ? MelodiTheme.primaryGreen
                    : MelodiTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppConstants.fontFamily,
                fontSize: 17,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? MelodiTheme.primaryGreen
                    : MelodiTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ServiceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MelodiTheme.containerLow,
              MelodiTheme.containerLow.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: MelodiTheme.outlineVariant.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.12),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MelodiTheme.title(
                      size: 18,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: MelodiTheme.bodySm(
                      size: 14,
                      color: MelodiTheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: MelodiTheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
