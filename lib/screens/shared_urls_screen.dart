import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../services/database_service.dart';

class SharedUrlsScreen extends StatefulWidget {
  const SharedUrlsScreen({super.key});

  @override
  State<SharedUrlsScreen> createState() => _SharedUrlsScreenState();
}

class _SharedUrlsScreenState extends State<SharedUrlsScreen> {
  List<Map<String, dynamic>> _urls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final urls = await db.getPendingSharedUrls();
    if (mounted) setState(() { _urls = urls; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        title: Text('Shared Links', style: TextStyle(color: MelodiTheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: MelodiTheme.onSurface),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: MelodiTheme.primaryGreen))
          : _urls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, size: 64, color: MelodiTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(AppLocale.tr('no_shared_links'), style: TextStyle(color: MelodiTheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _urls.length,
                  itemBuilder: (context, index) {
                    final item = _urls[index];
                    return ListTile(
                      leading: Icon(Icons.link_rounded, color: MelodiTheme.primaryGreen),
                      title: Text(
                        item['url'] as String,
                        style: TextStyle(color: MelodiTheme.onSurface, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item['sharedAt'] as String,
                        style: TextStyle(color: MelodiTheme.textMuted, fontSize: 11),
                      ),
                      trailing: Icon(Icons.check_circle_outline, color: MelodiTheme.textMuted, size: 20),
                    );
                  },
                ),
    );
  }
}
