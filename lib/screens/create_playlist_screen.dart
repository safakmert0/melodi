import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../providers/playlist_provider.dart';

class CreatePlaylistScreen extends StatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  State<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPrivate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MelodiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          AppLocale.tr('create_playlist'),
          style: MelodiTheme.heading(size: 20),
        ),
        actions: [
          TextButton(
            onPressed: _createPlaylist,
            child: const Text(
              'Create',
              style: TextStyle(
                fontFamily: AppConstants.fontFamily,
                color: MelodiTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: MelodiTheme.containerLow,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: MelodiTheme.primaryGreen.withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, size: 48, color: MelodiTheme.primaryGreen),
                  const SizedBox(height: 12),
                  Text(
                    AppLocale.tr('add_cover_photo'),
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _GlassInput(
              label: AppLocale.tr('playlist_name'),
              controller: _nameController,
              hint: AppLocale.tr('enter_playlist_name'),
            ),
            const SizedBox(height: 16),
            _GlassInput(
              label: AppLocale.tr('description'),
              controller: _descController,
              hint: AppLocale.tr('optional_description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _GlassInput(
              label: AppLocale.tr('privacy'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 20, color: MelodiTheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        AppLocale.tr('private_playlist'),
                        style: const TextStyle(
                          fontFamily: AppConstants.fontFamily,
                          color: MelodiTheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _isPrivate,
                    onChanged: (v) => setState(() => _isPrivate = v),
                    activeColor: MelodiTheme.primaryGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MelodiTheme.surfaceMid2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: MelodiTheme.primaryGreen),
                  const SizedBox(width: 8),
                  const Text(
                    'High fidelity experience active',
                    style: TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _createPlaylist,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MelodiTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  shadowColor: MelodiTheme.primaryGreen.withOpacity(0.3),
                ),
                child: const Text(
                  'Create Playlist',
                  style: TextStyle(
                    fontFamily: AppConstants.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createPlaylist() {
    if (_nameController.text.trim().isEmpty) return;
    context.read<PlaylistProvider>().createPlaylist(
      _nameController.text.trim(),
      description: _descController.text.trim(),
    );
    Navigator.of(context).pop();
  }
}

class _GlassInput extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final int maxLines;
  final Widget? child;

  const _GlassInput({
    required this.label,
    this.controller,
    this.hint,
    this.maxLines = 1,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppConstants.fontFamily,
                  color: MelodiTheme.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              child ??
                  TextField(
                    controller: controller,
                    maxLines: maxLines,
                    style: const TextStyle(
                      fontFamily: AppConstants.fontFamily,
                      color: MelodiTheme.onSurface,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        fontFamily: AppConstants.fontFamily,
                        color: MelodiTheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
