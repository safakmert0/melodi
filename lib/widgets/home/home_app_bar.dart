import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Melodi logo header for the app bar
class MelodiLogoHeader extends StatelessWidget {
  const MelodiLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.music_note,
            color: Colors.green,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Melodi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// App bar with search and actions
class MelodiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  const MelodiAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.onBack,
    this.onSearch,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBackground =
        isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AppBar(
      backgroundColor: scaffoldBackground,
      elevation: 0,
      title: Row(
        children: [
          if (showBackButton && onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: onBack,
              tooltip: 'Geri',
            ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}