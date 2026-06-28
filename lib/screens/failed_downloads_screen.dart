import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/download_provider.dart';
import '../services/download_manager.dart';

class FailedDownloadsScreen extends StatelessWidget {
  const FailedDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('failed')),
        backgroundColor: MelodiTheme.containerLow,
        foregroundColor: MelodiTheme.onSurface,
        elevation: 0,
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, provider, _) {
          final failed = provider.failedDownloads;
          if (failed.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 80, color: MelodiTheme.primaryGreen),
                  const SizedBox(height: 24),
                  Text(
                    AppLocale.tr('no_failed_downloads'),
                    style: TextStyle(
                      color: MelodiTheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎉',
                    style: TextStyle(fontSize: 32),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (failed.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '${failed.length} ${AppLocale.tr('failed')}',
                        style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => provider.retryAllFailed(),
                        icon: Icon(Icons.refresh_rounded, size: 18, color: MelodiTheme.primaryGreen),
                        label: Text(AppLocale.tr('retry_all'),
                            style: TextStyle(color: MelodiTheme.primaryGreen, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => provider.clearFailed(),
                        icon: Icon(Icons.delete_sweep_rounded, size: 18, color: MelodiTheme.errorRed),
                        label: Text(AppLocale.tr('clear_all'),
                            style: TextStyle(color: MelodiTheme.errorRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: failed.length,
                  itemBuilder: (context, index) {
                    final task = failed[index];
                    return _FailedDownloadTile(task: task);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FailedDownloadTile extends StatefulWidget {
  final DownloadTask task;
  const _FailedDownloadTile({required this.task});

  @override
  State<_FailedDownloadTile> createState() => _FailedDownloadTileState();
}

class _FailedDownloadTileState extends State<_FailedDownloadTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DownloadProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: MelodiTheme.containerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MelodiTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_rounded, color: MelodiTheme.errorRed, size: 22),
            ),
            title: Text(
              widget.task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _expanded ? (widget.task.error ?? '') : (widget.task.error ?? ''),
                          maxLines: _expanded ? 10 : 1,
                          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: TextStyle(color: MelodiTheme.errorRed, fontSize: 12),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: MelodiTheme.textMuted,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: MelodiTheme.primaryGreen, size: 20),
                  onPressed: () => provider.retryTask(widget.task.id),
                  tooltip: AppLocale.tr('retry'),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: MelodiTheme.textMuted, size: 20),
                  onPressed: () => provider.cancelTask(widget.task.id),
                  tooltip: AppLocale.tr('clear'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
