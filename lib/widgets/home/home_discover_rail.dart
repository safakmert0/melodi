import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/discover_service.dart';
import '../../screens/discover_screen.dart';

class HomeDiscoverRail extends StatelessWidget {
  const HomeDiscoverRail({super.key});

  static const _categories = [
    DiscoverCategory.yeniCikanlar,
    DiscoverCategory.trendler,
    DiscoverCategory.top10,
    DiscoverCategory.top50,
    DiscoverCategory.topluluk,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keşfet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            'Hızlı seçimler',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final c = _categories[index];
                return _CategoryCard(category: c);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final DiscoverCategory category;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DiscoverScreen(category: category),
            ),
          );
        },
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                category.icon,
                color: MelodiTheme.primaryGreen,
                size: 26,
              ),
              const Spacer(),
              Text(
                category.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                category.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
