import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/library_health_service.dart';

class LibraryHealthScreen extends StatefulWidget {
  const LibraryHealthScreen({super.key});

  @override
  State<LibraryHealthScreen> createState() => _LibraryHealthScreenState();
}

class _LibraryHealthScreenState extends State<LibraryHealthScreen> {
  final LibraryHealthService _service = LibraryHealthService();
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await _service.scanLibrary();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    await _service.invalidateCache();
    await _service.scanLibrary();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _fixAll() async {
    final fixed = await _service.fixAllIssues();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fixed ${AppLocale.tr('issues_found')} ${AppLocale.tr('fix_all')}'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _fixIssue(String issueId) async {
    final success = await _service.fixIssue(issueId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Issue fixed' : 'Could not fix issue'),
          backgroundColor: success ? AppTheme.primaryColor : AppTheme.errorColor,
        ),
      );
      setState(() {});
    }
  }

  Color _healthColor(double score) {
    if (score >= 80) return const Color(0xFF34C759);
    if (score >= 50) return const Color(0xFFFFCC02);
    return const Color(0xFFFF3B30);
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'error': return const Color(0xFFFF3B30);
      case 'warning': return const Color(0xFFFFCC02);
      default: return const Color(0xFF007AFF);
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'error': return Icons.error_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocale.tr('library_health')),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_scanning)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: AppLocale.tr('rescan'),
              onPressed: _rescan,
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final issues = _service.issues;
    final score = _service.getHealthScore();

    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHealthScore(score),
            const SizedBox(height: 24),
            Icon(Icons.check_circle_outline_rounded, size: 64, color: const Color(0xFF34C759)),
            const SizedBox(height: 16),
            Text(
              AppLocale.tr('no_issues'),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final byCategory = _service.getIssuesByCategory();
    final fixableCount = _service.getFixableCount();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHealthScore(score),
        const SizedBox(height: 24),
        if (fixableCount > 0) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fixAll,
              icon: const Icon(Icons.build_rounded, size: 18),
              label: Text('${AppLocale.tr('fix_all')} ($fixableCount)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        ...byCategory.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHealthScore(double score) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 12,
                backgroundColor: AppTheme.card,
                valueColor: AlwaysStoppedAnimation<Color>(_healthColor(score)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${score.round()}',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppLocale.tr('health_score'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> issues) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            Icon(_categoryIcon(category), size: 20, color: AppTheme.textPrimary),
            const SizedBox(width: 10),
            Text(
              _categoryTitle(category),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${issues.length}',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        children: [
          ...issues.map((issue) => _buildIssueTile(issue)),
        ],
      ),
    );
  }

  Widget _buildIssueTile(Map<String, dynamic> issue) {
    final severity = issue['severity'] as String;
    final autoFixable = (issue['autoFixable'] as int?) == 1;
    final description = issue['description'] as String;
    final issueId = issue['id'] as String;

    final isSummary = issueId.endsWith('_summary');

    if (isSummary) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Icon(_severityIcon(severity), size: 16, color: _severityColor(severity)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                description,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(_severityIcon(severity), size: 14, color: _severityColor(severity)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (autoFixable)
            TextButton(
              onPressed: () => _fixIssue(issueId),
              child: Text(
                AppLocale.tr('fix_all'),
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Album Art': return Icons.image_rounded;
      case 'Metadata': return Icons.article_rounded;
      case 'Matching': return Icons.compare_arrows_rounded;
      case 'Downloads': return Icons.download_rounded;
      case 'Blocked': return Icons.block_rounded;
      case 'Duplicates': return Icons.content_copy_rounded;
      case 'Orphaned': return Icons.insert_drive_file_rounded;
      default: return Icons.warning_rounded;
    }
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'Album Art': return AppLocale.tr('missing_art');
      case 'Metadata': return AppLocale.tr('missing_metadata');
      case 'Matching': return AppLocale.tr('low_confidence');
      case 'Downloads': return AppLocale.tr('failed_downloads_issue');
      case 'Blocked': return 'Blocked';
      case 'Duplicates': return AppLocale.tr('duplicates');
      case 'Orphaned': return AppLocale.tr('orphaned_files');
      default: return category;
    }
  }
}
