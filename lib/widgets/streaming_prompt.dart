import 'package:flutter/material.dart';
import '../core/constants.dart';

class StreamingPrompt extends StatelessWidget {
  const StreamingPrompt({super.key});
  static Future<bool?> show(BuildContext context) => showDialog<bool>(context: context, builder: (_) => const StreamingPrompt());
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      title: Text(AppLocale.tr('streaming_prompt_title'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
      content: Text(AppLocale.tr('streaming_prompt_body'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocale.tr('download'), style: TextStyle(color: scheme.onSurfaceVariant))),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: scheme.onSurface, foregroundColor: scheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(AppLocale.tr('stream'))),
      ],
    );
  }
}
