import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/widgets/memoir_button.dart';
import '../../../../shared/widgets/memoir_tab_toggle.dart';

/// Screensaver configuration section.
///
/// Toggle Default/Custom (like printer BT/USB toggle),
/// with a tall preview filling available height.
class ScreensaverConfigSection extends StatefulWidget {
  final StorageService storageService;

  const ScreensaverConfigSection({
    super.key,
    required this.storageService,
  });

  @override
  State<ScreensaverConfigSection> createState() =>
      _ScreensaverConfigSectionState();
}

class _ScreensaverConfigSectionState extends State<ScreensaverConfigSection> {
  bool _isCustom = false;
  String? _filePath;

  static const _videoExtensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};

  @override
  void initState() {
    super.initState();
    final type = widget.storageService.screensaverType;
    _isCustom = type == 'image' || type == 'video';
    _filePath = widget.storageService.screensaverFilePath;
  }

  bool get _isVideo {
    if (_filePath == null) return false;
    return _videoExtensions.contains(p.extension(_filePath!).toLowerCase());
  }

  Future<void> _setDefault() async {
    await _removeFile();
    setState(() => _isCustom = false);
  }

  Future<void> _setCustom() async {
    setState(() => _isCustom = true);
    await widget.storageService.setScreensaverType('image');
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();

    final picked = await showModalBottomSheet<XFile>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PILIH MEDIA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PickerOption(
                icon: Icons.image_outlined,
                label: 'Gambar',
                onTap: () async {
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 2048,
                    maxHeight: 2048,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
              _PickerOption(
                icon: Icons.videocam_outlined,
                label: 'Video',
                onTap: () async {
                  final file = await picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    await _saveFile(picked.path);
  }

  Future<void> _saveFile(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath).toLowerCase();
    final fileName = 'screensaver_bg$ext';
    final savedFile = await File(sourcePath).copy(
      p.join(appDir.path, fileName),
    );

    final isVideo = _videoExtensions.contains(ext);
    await widget.storageService.setScreensaverType(
      isVideo ? 'video' : 'image',
    );
    await widget.storageService.setScreensaverFilePath(savedFile.path);
    setState(() => _filePath = savedFile.path);
  }

  Future<void> _removeFile() async {
    if (_filePath != null) {
      final file = File(_filePath!);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    await widget.storageService.clearScreensaver();
    setState(() => _filePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _filePath != null && File(_filePath!).existsSync();

    // Calculate available height for preview:
    // screen height - top bar (~56) - tabs bar (~48) - padding - toggle - buttons
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = (screenHeight - 280).clamp(200.0, 800.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toggle: Default / Custom ──
        MemoirTabToggle<bool>(
          items: const [
            MemoirTabItem(value: false, label: 'Default', icon: Icons.text_fields),
            MemoirTabItem(value: true, label: 'Custom', icon: Icons.wallpaper_outlined),
          ],
          selected: _isCustom,
          onChanged: (value) => value ? _setCustom() : _setDefault(),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Preview area ──
        if (!_isCustom)
          _DefaultPreview(height: previewHeight)
        else ...[
          if (hasFile) ...[
            // ── File preview ──
            if (_isVideo)
              _VideoPreview(filePath: _filePath!, height: previewHeight)
            else
              _ImagePreview(filePath: _filePath!, height: previewHeight),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Expanded(
                  child: MemoirButton.outlined(
                    label: 'Ganti',
                    icon: Icons.swap_horiz,
                    onPressed: _pickFile,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MemoirButton.outlined(
                    label: 'Hapus',
                    icon: Icons.delete_outline,
                    color: AppColors.error,
                    onPressed: _removeFile,
                  ),
                ),
              ],
            ),
          ] else ...[
            // ── Empty placeholder ──
            Container(
              width: double.infinity,
              height: previewHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: AppColors.textDisabled,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Pilih gambar atau video',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            MemoirButton.filled(
              label: 'Pilih Media',
              icon: Icons.upload_outlined,
              onPressed: _pickFile,
            ),
          ],
        ],
      ],
    );
  }
}

// ─── Default screensaver preview ────────────────────────────────

class _DefaultPreview extends StatelessWidget {
  final double height;
  const _DefaultPreview({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'memoir.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 28,
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'TAP UNTUK MULAI',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
                letterSpacing: 2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image preview ──────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  final String filePath;
  final double height;
  const _ImagePreview({required this.filePath, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.file(
          File(filePath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.surfaceVariant,
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Video preview ──────────────────────────────────────────────

class _VideoPreview extends StatelessWidget {
  final String filePath;
  final double height;
  const _VideoPreview({required this.filePath, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 48,
              color: Colors.white54,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Video tersimpan',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Picker option in bottom sheet ──────────────────────────────

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
