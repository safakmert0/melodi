import 'package:flutter/material.dart';

import '../core/melodi_design.dart';

class ListeningHeatmap extends StatelessWidget {
  const ListeningHeatmap({
    super.key,
    required this.days,
    this.weekCount = 26,
  });

  final List<Map<String, dynamic>> days;
  final int weekCount;

  @override
  Widget build(BuildContext context) {
    final byDate = <String, Map<String, dynamic>>{
      for (final day in days)
        if (day['date'] != null) day['date'].toString(): day,
    };
    final maxPlays = days.fold<int>(1, (max, day) {
      final plays = (day['totalPlays'] as num?)?.toInt() ?? 0;
      return plays > max ? plays : max;
    });
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final earliestVisible = normalizedToday.subtract(
      Duration(days: (weekCount * 7) - 1),
    );
    final start = earliestVisible.subtract(
      Duration(days: earliestVisible.weekday % 7),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dinleme ritmi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            Text(
              'Son 6 ay',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Daha yoğun renk, o gün daha çok müzik dinlediğini gösterir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(weekCount, (week) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  children: List.generate(7, (weekday) {
                    final date = start.add(Duration(days: week * 7 + weekday));
                    final key = _dateKey(date);
                    final data = byDate[key];
                    final plays = (data?['totalPlays'] as num?)?.toInt() ?? 0;
                    final totalMs =
                        (data?['totalDurationMs'] as num?)?.toInt() ?? 0;
                    final inFuture = date.isAfter(normalizedToday);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tooltip(
                        message: inFuture
                            ? _humanDate(date)
                            : '${_humanDate(date)} · $plays çalma · ${Duration(milliseconds: totalMs).inMinutes} dk',
                        child: _HeatCell(
                          intensity: inFuture ? -1 : plays / maxPlays,
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Az', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 6),
            for (final value in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
              _HeatCell(intensity: value, size: 10),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: 3),
            Text('Çok', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _humanDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.intensity, this.size = 12});

  final double intensity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = intensity < 0
        ? Colors.transparent
        : intensity == 0
            ? colors.surfaceContainerHighest.withValues(alpha: 0.72)
            : colors.primary.withValues(alpha: 0.22 + intensity * 0.78);
    return AnimatedContainer(
      duration: MelodiMotion.quick,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
    );
  }
}
