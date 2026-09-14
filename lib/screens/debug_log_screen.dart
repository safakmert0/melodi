import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/log_service.dart';

/// Debug loglari icin ekran: filtreleme, arama, paylas, temizle.
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});
  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  LogLevel? _filterLevel;
  String _search = '';
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Loglar'),
        actions: [
          PopupMenuButton<LogLevel?>(
            initialValue: _filterLevel,
            onSelected: (v) => setState(() => _filterLevel = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Tumu')),
              const PopupMenuItem(value: LogLevel.error, child: Text('Hatalar')),
              const PopupMenuItem(value: LogLevel.warning, child: Text('Uyarilar')),
              const PopupMenuItem(value: LogLevel.info, child: Text('Bilgi')),
              const PopupMenuItem(value: LogLevel.debug, child: Text('Debug')),
            ],
            icon: const Icon(Icons.filter_list),
            tooltip: 'Seviye filtresi',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Temizle',
            onPressed: () {
              context.read<LogService>().clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loglar temizlendi')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            tooltip: 'Panoya kopyala (filtreli)',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Paylas (dosya)',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama cubugu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ara... (mesaj, tag, hata)',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          // Log listesi
          Expanded(
            child: Consumer<LogService>(
              builder: (context, logService, _) {
                final logs = logService.currentLogs
                    .where((e) {
                      if (_filterLevel != null && e.level != _filterLevel) return false;
                      if (_search.isNotEmpty) {
                        final q = _search.toLowerCase();
                        final hay = '${e.message} ${e.tag} ${e.error ?? ''} ${e.stack ?? ''}'.toLowerCase();
                        if (!hay.contains(q)) return false;
                      }
                      return true;
                    })
                    .toList()
                    .reversed
                    .toList(); // en yeni ustte
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bug_report, size: 48, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Log bulunamadi', style: TextStyle(color: scheme.onSurfaceVariant)),
                        if (_filterLevel != null || _search.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() { _filterLevel = null; _search = ''; }),
                            child: const Text('Filtreleri temizle'),
                          ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // en yeni ustte
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: logs.length,
                  itemBuilder: (_, i) => _LogTile(entry: logs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    final logs = context.read<LogService>().currentLogs
        .where((e) {
          if (_filterLevel != null && e.level != _filterLevel) return false;
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            final hay = '${e.message} ${e.tag} ${e.error ?? ''} ${e.stack ?? ''}'.toLowerCase();
            return hay.contains(q);
          }
          return true;
        })
        .map((e) => e.toFileString())
        .join('\n');
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loglar panoya kopyalandi')),
    );
  }

  Future<void> _shareFile() async {
    final path = await context.read<LogService>().exportLogs();
    if (path != null && path.isNotEmpty) {
      await Share.shareXFiles([XFile(path)], text: 'Melodi debug loglari');
    }
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = entry.level == LogLevel.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${entry.timestamp.second.toString().padLeft(2, '0')}.'
                  '${entry.timestamp.millisecond.toString().padLeft(3, '0')} ',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: '${entry.levelEmoji} ',
              style: const TextStyle(fontSize: 12),
            ),
            if (entry.tag.isNotEmpty)
              TextSpan(
                text: '[${entry.tag}] ',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: entry.message,
                style: TextStyle(
                  fontSize: 12,
                  color: isError ? scheme.error : scheme.onSurface,
                  fontWeight: entry.level == LogLevel.error ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            if (entry.error != null)
              TextSpan(
                text: '\n  Error: ${entry.error}',
                style: TextStyle(fontSize: 11, color: scheme.error),
              ),
            if (entry.stack != null)
              TextSpan(
                text: '\n  Stack: ${entry.stack!.substring(0, entry.stack!.length.clamp(0, 200))}',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}