import 'package:flutter/material.dart';

import '../core/melodi_design.dart';
import '../services/follows_service.dart';

/// Takip edilen kanallar: yeni yuklemeler sunucuda otomatik indirilir.
class FollowsScreen extends StatefulWidget {
  const FollowsScreen({super.key});

  @override
  State<FollowsScreen> createState() => _FollowsScreenState();
}

class _FollowsScreenState extends State<FollowsScreen> {
  List<FollowedChannel> _items = const [];
  bool _loading = true;
  bool _checking = false;
  String? _report;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await FollowsService.instance.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addDialog() async {
    final urlCtrl = TextEditingController();
    String preset = 'music_only';
    bool lyrics = false;
    int maxItems = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Kanal takip et'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kanal / liste URL',
                    hintText: 'https://www.youtube.com/@...',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: preset,
                  decoration:
                      const InputDecoration(labelText: 'Kalite'),
                  items: FollowedChannel.presets
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) =>
                      setD(() => preset = v ?? 'music_only'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sözleri de indir'),
                  value: lyrics,
                  onChanged: (v) => setD(() => lyrics = v),
                ),
                Row(
                  children: [
                    const Text('Tur başına en fazla: '),
                    DropdownButton<int>(
                      value: maxItems,
                      items: [1, 2, 3, 5, 10]
                          .map((n) => DropdownMenuItem(
                              value: n, child: Text('$n')))
                          .toList(),
                      onChanged: (v) =>
                          setD(() => maxItems = v ?? 3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    urlCtrl.dispose();
    if (ok != true || !mounted) return;
    final (id, err) = await FollowsService.instance.add(
      url: urlCtrl.text,
      preset: preset,
      writeLyrics: lyrics,
      maxItems: maxItems,
    );
    if (!mounted) return;
    if (err == 'yetkisiz') {
      _tokenDialog();
      return;
    }
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eklenemedi${err != null ? ': $err' : ''}')),
      );
      return;
    }
    await _reload();
  }

  Future<void> _tokenDialog() async {
    final ctrl = TextEditingController(
        text: await FollowsService.instance.apiToken() ?? '');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API anahtarı gerekli'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'MELODI_API_TOKEN',
            hintText: 'Sunucudaki anahtar',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FollowsService.instance.setApiToken(ctrl.text);
    }
    ctrl.dispose();
  }

  Future<void> _remove(FollowedChannel f) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Takibi bırak?'),
            content: Text(f.url,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Bırak'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await FollowsService.instance.remove(f.id);
    await _reload();
  }

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _report = null;
    });
    final rep = await FollowsService.instance.checkNow();
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (rep == null) {
        _report = 'Denetim başarısız.';
      } else if (rep['error'] == 'yetkisiz') {
        _report = 'Yetkisiz: API anahtarı gerekli.';
      } else {
        final rows = (rep['report'] as List? ?? const []);
        var fresh = 0, got = 0;
        for (final r in rows.whereType<Map>()) {
          fresh += ((r['new'] as num?)?.toInt() ?? 0);
          got += ((r['downloaded'] as num?)?.toInt() ?? 0);
        }
        _report = rows.isEmpty
            ? 'Takip yok.'
            : '$fresh yeni bulundu, $got indirildi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Takip Edilen Kanallar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Takip et'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  MelodiPanel(
                    child: Row(
                      children: [
                        Icon(Icons.sync_rounded,
                            color: scheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Yeni yüklemeler sunucuda otomatik indirilir ve kütüphaneye katar.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _checking ? null : _checkNow,
                          icon: _checking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  size: 18),
                          label: const Text('Şimdi denetle'),
                        ),
                      ),
                    ],
                  ),
                  if (_report != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_report!,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13)),
                    ),
                  const SectionHeader(
                      title: 'Kanallar', subtitle: null),
                  if (_items.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Henüz takip yok. + ile kanal ekle.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ..._items.map((f) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: MelodiPanel(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.primaryContainer,
                                  ),
                                  child: Icon(
                                    Icons
                                        .subscriptions_rounded,
                                    size: 20,
                                    color: scheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        f.url,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${f.preset} · ${f.tracked} takipte',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: scheme
                                                .onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Takibi bırak',
                                  icon: const Icon(
                                      Icons.delete_outline_rounded),
                                  onPressed: () => _remove(f),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
      ),
    );
  }
}
