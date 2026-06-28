import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/splash_screen.dart';
import '../widgets/main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showSplash = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await DatabaseService.instance.setSetting('onboarding_completed', 'true');
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          setState(() => _showSplash = false);
        },
      );
    }

    return Scaffold(
      backgroundColor: MelodiTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: List.generate(4, (i) {
                  final isActive = i <= _currentPage;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive ? MelodiTheme.primaryGreen : MelodiTheme.surfaceBright,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.library_music_rounded,
                    title: AppLocale.tr('welcome_to_melodi'),
                    description: AppLocale.tr('onboarding_welcome_desc'),
                    child: _LanguageSelector(),
                  ),
                  _OnboardingPage(
                    icon: Icons.language_rounded,
                    title: AppLocale.tr('choose_language'),
                    description: AppLocale.tr('onboarding_language_desc'),
                    child: _LanguageSelector(),
                  ),
                  _OnboardingPage(
                    icon: Icons.palette_rounded,
                    title: AppLocale.tr('choose_theme'),
                    description: AppLocale.tr('onboarding_theme_desc'),
                    child: _ThemeSelector(),
                  ),
                  _OnboardingPage(
                    icon: Icons.sync_rounded,
                    title: AppLocale.tr('connect_services'),
                    description: AppLocale.tr('onboarding_services_desc'),
                  ),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _currentPage < 3 ? _complete : null,
            child: Text(
              AppLocale.tr('skip'),
              style: const TextStyle(
                fontFamily: AppConstants.fontFamily,
                color: MelodiTheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < 3) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart,
                  );
                } else {
                  _complete();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MelodiTheme.primaryGreen,
                foregroundColor: MelodiTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 8,
                shadowColor: MelodiTheme.primaryGreen.withOpacity(0.3),
              ),
              child: Text(
                _currentPage < 3
                    ? AppLocale.tr('next')
                    : AppLocale.tr('get_started'),
                style: const TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? child;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: MelodiTheme.containerLow,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: MelodiTheme.primaryGreen.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, size: 56, color: MelodiTheme.primaryGreen),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: MelodiTheme.heading(size: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: MelodiTheme.body(color: MelodiTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (child != null) ...[
            const SizedBox(height: 32),
            child!,
          ],
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final languages = [
      ('Türkçe', 'tr'),
      ('English', 'en'),
      ('Deutsch', 'de'),
    ];

    return Column(
      children: languages.map((lang) {
        final isSelected = AppLocale.currentLocale == lang.$2;
        return GestureDetector(
          onTap: () {
            AppLocale.currentLocale = lang.$2;
            DatabaseService.instance.setSetting('app_locale', lang.$2);
            context.read<LocaleNotifier>().notifyListeners();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? MelodiTheme.primaryGreen.withOpacity(0.15)
                  : MelodiTheme.containerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  lang.$1,
                  style: MelodiTheme.body(
                    color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.onSurface,
                    weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_rounded, color: MelodiTheme.primaryGreen, size: 20),
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
          isSelected: true,
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _ThemeOption(
          label: AppLocale.tr('light'),
          icon: Icons.light_mode_rounded,
          isSelected: false,
          onTap: () {},
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
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? MelodiTheme.primaryGreen.withOpacity(0.15) : MelodiTheme.containerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              style: MelodiTheme.bodySm(
                color: isSelected ? MelodiTheme.primaryGreen : MelodiTheme.onSurfaceVariant,
                weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
