import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await DatabaseService.instance.setSetting('onboarding_completed', 'true');
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.library_music_rounded,
                    title: AppLocale.tr('welcome_to_melodi'),
                    description: AppLocale.tr('onboarding_welcome_desc'),
                    isDark: isDark,
                  ),
                  _OnboardingPage(
                    icon: Icons.language_rounded,
                    title: AppLocale.tr('choose_language'),
                    description: AppLocale.tr('onboarding_language_desc'),
                    isDark: isDark,
                    child: _LanguageSelector(),
                  ),
                  _OnboardingPage(
                    icon: Icons.palette_rounded,
                    title: AppLocale.tr('choose_theme'),
                    description: AppLocale.tr('onboarding_theme_desc'),
                    isDark: isDark,
                    child: _ThemeSelector(),
                  ),
                  _OnboardingPage(
                    icon: Icons.sync_rounded,
                    title: AppLocale.tr('connect_services'),
                    description: AppLocale.tr('onboarding_services_desc'),
                    isDark: isDark,
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
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _currentPage < 3 ? _complete : null,
            child: Text(
              AppLocale.tr('skip'),
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Row(
            children: List.generate(4, (i) => _buildDot(i)),
          ),
          ElevatedButton(
            onPressed: _currentPage < 3
                ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    )
                : _complete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _currentPage < 3 ? AppLocale.tr('next') : AppLocale.tr('get_started'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final Widget? child;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.4,
            ),
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
    final locales = [
      {'code': 'tr', 'label': 'Türkçe', 'flag': '🇹🇷'},
      {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
      {'code': 'de', 'label': 'Deutsch', 'flag': '🇩🇪'},
    ];

    return Column(
      children: locales.map((l) {
        final isSelected = AppLocale.currentLocale == l['code'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              AppLocale.currentLocale = l['code'] as String;
              DatabaseService.instance.setSetting('app_locale', l['code'] as String);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: AppTheme.primaryColor, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Text(l['flag'] as String, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Text(
                    l['label'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? AppTheme.primaryColor : null,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24),
                ],
              ),
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
    final theme = context.watch<ThemeProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ThemeOption(
          icon: Icons.light_mode_rounded,
          label: AppLocale.tr('light'),
          isSelected: theme.isLight,
          onTap: () => theme.setThemeMode(ThemeMode.light),
        ),
        const SizedBox(width: 16),
        _ThemeOption(
          icon: Icons.dark_mode_rounded,
          label: AppLocale.tr('dark'),
          isSelected: theme.isDark,
          onTap: () => theme.setThemeMode(ThemeMode.dark),
        ),
        const SizedBox(width: 16),
        _ThemeOption(
          icon: Icons.settings_brightness_rounded,
          label: AppLocale.tr('system'),
          isSelected: theme.themeMode == ThemeMode.system,
          onTap: () => theme.setThemeMode(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 2)
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
