import 'package:flutter/material.dart';

class ListeningHeatmap extends StatelessWidget {
  const ListeningHeatmap({super.key, required this.days, this.weekCount = 26});
  final List<Map<String, dynamic>> days;
  final int weekCount;

  @override
  Widget build(BuildContext context) {
    final byDate = <String, Map<String, dynamic>>{for (final day in days) if (day['date'] != null) day['date'].toString(): day};
    final maxPlays = days.fold<int>(1, (max, day) {
      final plays = (day['totalPlays'] as num?)?.toInt() ?? 0;
      return plays > max ? plays : max;
    });
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final earliestVisible = normalizedToday.subtract(Duration(days: (weekCount * 7) - 1));
    final start = earliestVisible.subtract(Duration(days: earliestVisible.weekday % 7));
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text('Dinleme ritmi', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), Text('Son 6 ay', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant))]),
        const SizedBox(height: 4),
        Text('Daha yoğun renk, o gün daha çok müzik dinlediğini gösterir.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(weekCount, (week) {
              return Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Column(
                  children: List.generate(7, (weekday) {
                    final date = start.add(Duration(days: week * 7 + weekday));
                    final key = _dateKey(date);
                    final data = byDate[key];
                    final plays = (data?['totalPlays'] as num?)?.toInt() ?? 0;
                    final totalMs = (data?['totalDurationMs'] as num?)?.toInt() ?? 0;
                    final inFuture = date.isAfter(normalizedToday);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Tooltip(message: inFuture ? _humanDate(date) : '${_humanDate(date)} · $plays çalma · ${Duration(milliseconds: totalMs).inMinutes} dk', child: _HeatCell(intensity: inFuture ? -1 : plays / maxPlays)),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('Az', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11)), const SizedBox(width: 6), for (final value in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[_HeatCell(intensity: value, size: 10), const SizedBox(width: 3)], const SizedBox(width: 3), Text('Çok', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11))]),
      ],
    );
  }

  static String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String _humanDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.intensity, this.size = 12});
  final double intensity;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    if (intensity < 0) {
      color = Colors.transparent;
    } else if (intensity == 0) {
      color = scheme.surfaceContainerHighest;
    } else {
      // Flat neutral intensity: stronger fill with onSurfaceVariant alpha, no neon
      final a = 0.18 + intensity * 0.55;
      color = scheme.onSurfaceVariant.withValues(alpha: a.clamp(0, 1));
    }
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25), width: 0.5)));
  }
}
