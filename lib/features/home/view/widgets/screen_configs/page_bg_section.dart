import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../../shared/core/theme/app_colors.dart';
import '../../../../../shared/core/theme/app_spacing.dart';
import '../../../../../shared/core/widgets/noise_background.dart';
import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_button.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import '../../../../../shared/widgets/memoir_tab_toggle.dart';

/// Settings section for configuring a per-page background image/video.
///
/// [pageKey] must match the key used by [PageBackground] on the actual screen.
class PageBgSection extends StatefulWidget {
  final StorageService storageService;
  final String pageKey;

  const PageBgSection({
    super.key,
    required this.storageService,
    required this.pageKey,
  });

  @override
  State<PageBgSection> createState() => _PageBgSectionState();
}

class _PageBgSectionState extends State<PageBgSection> {
  bool _isCustom = false;
  bool _isSaving = false;
  String? _filePath;

  static const _videoExtensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};
  static const _previewHeight = 280.0;

  @override
  void initState() {
    super.initState();
    final type = widget.storageService.pageBgType(widget.pageKey);
    _isCustom = type == 'image' || type == 'video';
    _filePath = widget.storageService.pageBgFilePath(widget.pageKey);
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
    await widget.storageService.setPageBgType(widget.pageKey, 'image');
  }

  Future<void> _pickFile() async {
    final sourceType = await showModalBottomSheet<String>(
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
                onTap: () => Navigator.pop(ctx, 'image'),
              ),
              _PickerOption(
                icon: Icons.videocam_outlined,
                label: 'Video',
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
            ],
          ),
        ),
      ),
    );

    if (sourceType == null || !mounted) return;

    final picker = ImagePicker();
    XFile? picked;
    if (sourceType == 'image') {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
    } else {
      picked = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (picked == null || !mounted) return;
    await _saveFile(picked.path);
  }

  Future<void> _saveFile(String sourcePath) async {
    setState(() => _isSaving = true);
    try {
      if (_filePath != null) {
        final old = File(_filePath!);
        if (old.existsSync()) await old.delete();
      }

      final appDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(sourcePath).toLowerCase();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final savedFile = await File(sourcePath).copy(
        p.join(appDir.path, '${widget.pageKey}_bg_$ts$ext'),
      );
      final isVideo = _videoExtensions.contains(ext);
      await widget.storageService
          .setPageBgType(widget.pageKey, isVideo ? 'video' : 'image');
      await widget.storageService
          .setPageBgFilePath(widget.pageKey, savedFile.path);
      if (mounted) setState(() => _filePath = savedFile.path);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeFile() async {
    if (_filePath != null) {
      final file = File(_filePath!);
      if (file.existsSync()) await file.delete();
    }
    await widget.storageService.clearPageBg(widget.pageKey);
    setState(() => _filePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _filePath != null && File(_filePath!).existsSync();

    return MemoirSectionCard(
      label: 'Latar Belakang',
      subtitle: 'Atur tampilan latar belakang halaman ini.',
      icon: Icons.wallpaper_outlined,
      children: [
        MemoirTabToggle<bool>(
          items: const [
            MemoirTabItem(
                value: false, label: 'Default', icon: Icons.text_fields),
            MemoirTabItem(
                value: true,
                label: 'Custom',
                icon: Icons.wallpaper_outlined),
          ],
          selected: _isCustom,
          onChanged: (value) => value ? _setCustom() : _setDefault(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!_isCustom)
          const _DefaultPreview(height: _previewHeight)
        else ...[
          if (hasFile) ...[
            if (_isVideo)
              _VideoPreview(filePath: _filePath!, height: _previewHeight)
            else
              _ImagePreview(filePath: _filePath!, height: _previewHeight),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Expanded(
                  child: MemoirButton.outlined(
                    label: _isSaving ? 'Menyimpan...' : 'Ganti',
                    icon: _isSaving ? null : Icons.swap_horiz,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _pickFile,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MemoirButton.outlined(
                    label: 'Hapus',
                    icon: Icons.delete_outline,
                    color: AppColors.error,
                    onPressed: _isSaving ? null : _removeFile,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: _previewHeight,
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
                    style:
                        TextStyle(color: AppColors.textDisabled, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            MemoirButton.filled(
              label: _isSaving ? 'Menyimpan...' : 'Pilih Media',
              icon: _isSaving ? null : Icons.upload_outlined,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _pickFile,
            ),
          ],
        ],
      ],
    );
  }
}

class _DefaultPreview extends StatelessWidget {
  final double height;
  const _DefaultPreview({required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: const Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: AppColors.surface)),
            Positioned.fill(child: RepaintBoundary(child: NoiseBackground())),
            Center(
              child: Text(
                'Default Background',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _VideoPreview extends StatefulWidget {
  final String filePath;
  final double height;
  const _VideoPreview({required this.filePath, required this.height});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath));
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      _controller.setVolume(0);
      _controller.play();
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: _initialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                      color: Colors.white54, strokeWidth: 2),
                ),
              ),
      ),
    );
  }
}

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
