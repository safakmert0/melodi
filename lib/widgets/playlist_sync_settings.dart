import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/database_service.dart';

class PlaylistSyncSettings extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistSyncSettings({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<PlaylistSyncSettings> createState() => _PlaylistSyncSettingsState();
}

class _PlaylistSyncSettingsState extends State<PlaylistSyncSettings> {
  final _db = DatabaseService.instance;
  bool _syncEnabled = true;
  bool _autoSync = false;
  String _syncDirection = 'bidirectional';
  String? _lastSyncedAt;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await _db.getPlaylistSyncState(widget.playlistId);
    if (state != null) {
      setState(() {
        _syncEnabled = (state['syncEnabled'] as int?) == 1;
        _autoSync = (state['autoSync'] as int?) == 1;
        _syncDirection = state['syncDirection'] as String? ?? 'bidirectional';
        _lastSyncedAt = state['lastSyncedAt'] as String?;
        _isLoading = false;
      });
    } else {
      final defaultAutoSync = await _db.getSetting('default_auto_sync');
      final defaultDirection = await _db.getSetting('default_sync_direction');
      setState(() {
        _syncEnabled = true;
        _autoSync = defaultAutoSync == 'true';
        _syncDirection = defaultDirection ?? 'bidirectional';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    await _db.setPlaylistSyncEnabled(widget.playlistId, _syncEnabled);
    await _db.setAutoSync(widget.playlistId, _autoSync);
    await _db.setSyncDirection(widget.playlistId, _syncDirection);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      final now = DateTime.now().toIso8601String();
      await _db.setPlaylistSyncEnabled(widget.playlistId, _syncEnabled);
      await _db.setAutoSync(widget.playlistId, _autoSync);
      await _db.setSyncDirection(widget.playlistId, _syncDirection);
      setState(() {
        _lastSyncedAt = now;
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.playlistName} ${AppLocale.tr('sync_now')}'),
            backgroundColor: MelodiTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: MelodiTheme.errorRed,
          ),
        );
      }
    }
  }

  String _formatLastSynced(String? iso) {
    if (iso == null) return '--';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '--';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: MelodiTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                  Text(
                    AppLocale.tr('sync_settings'),
                    style: TextStyle(
                      color: MelodiTheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.playlistName,
                    style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _buildToggle(
                    icon: Icons.sync_rounded,
                    title: AppLocale.tr('sync_this_playlist'),
                    value: _syncEnabled,
                    onChanged: (v) => setState(() => _syncEnabled = v),
                  ),
                  if (_syncEnabled) ...[
                    const SizedBox(height: 16),
                    _buildToggle(
                      icon: Icons.autorenew_rounded,
                      title: AppLocale.tr('auto_sync'),
                      value: _autoSync,
                      onChanged: (v) => setState(() => _autoSync = v),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocale.tr('sync_direction'),
                      style: TextStyle(
                        color: MelodiTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDirectionOption('bidirectional', AppLocale.tr('bidirectional')),
                    _buildDirectionOption('spotify_to_yt', AppLocale.tr('spotify_to_yt')),
                    _buildDirectionOption('yt_to_spotify', AppLocale.tr('yt_to_spotify')),
                    const SizedBox(height: 16),
                    _InfoRow(
                      label: AppLocale.tr('last_synced'),
                      value: _formatLastSynced(_lastSyncedAt),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _syncNow,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.sync_rounded, size: 20),
                        label: Text(AppLocale.tr('sync_now')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MelodiTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _save,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MelodiTheme.primaryGreen,
                        side: BorderSide(color: MelodiTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(AppLocale.tr('save')),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: MelodiTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: MelodiTheme.primaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(color: MelodiTheme.onSurface, fontSize: 15),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: MelodiTheme.primaryGreen,
        ),
      ],
    );
  }

  Widget _buildDirectionOption(String value, String label) {
    final selected = _syncDirection == value;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? MelodiTheme.primaryGreen : MelodiTheme.textMuted,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? MelodiTheme.primaryGreen : MelodiTheme.onSurface,
          fontSize: 14,
        ),
      ),
      onTap: () => setState(() => _syncDirection = value),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: MelodiTheme.onSurfaceVariant, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: MelodiTheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
