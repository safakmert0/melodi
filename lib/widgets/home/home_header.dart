import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Home screen header with search and profile
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          _buildSearchBar(context),

          const SizedBox(height: 24),

          // Quick stats row
          _buildQuickStats(context),

          const Spacer(),

          // User profile area
          _buildProfileArea(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blur: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Aramak istediğinizi yazın...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(30),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _StatItemQuick(
          icon: Icons.music_note,
          label: '1.2M',
          color: Colors.green,
          isDark: isDark,
        ),
        const SizedBox(width: 16),
        _StatItemQuick(
          icon: Icons.favorite,
          label: '240K',
          color: Colors.pink,
          isDark: isDark,
        ),
        const SizedBox(width: 16),
        _StatItemQuick(
          icon: Icons.remove,
          label: '340K',
          color: Colors.cyan,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildProfileArea(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.green,
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Kullanıcı',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to profile
              },
              child: const Text(
                'Hesap',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quick stat item widget
class _StatItemQuick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _StatItemQuick({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? color.withOpacity(0.1) : color.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}