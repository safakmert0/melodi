import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';

class StreamingPrompt extends StatelessWidget {
  const StreamingPrompt({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const StreamingPrompt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MelodiTheme.containerLow,
      title: Text(
        AppLocale.tr('streaming_prompt_title'),
        style: TextStyle(color: MelodiTheme.onSurface),
      ),
      content: Text(
        AppLocale.tr('streaming_prompt_body'),
        style: TextStyle(color: MelodiTheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            AppLocale.tr('download'),
            style: TextStyle(color: MelodiTheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            AppLocale.tr('stream'),
            style: TextStyle(color: MelodiTheme.primaryGreen),
          ),
        ),
      ],
    );
  }
}
