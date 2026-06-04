import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/gallery_service.dart';
import '../../theme/app_theme.dart';

class ComposeGalleryPostScreen extends StatefulWidget {
  /// When provided, the screen edits the given gallery post instead
  /// of creating a new one.
  final GalleryPost? existing;
  const ComposeGalleryPostScreen({super.key, this.existing});

  @override
  State<ComposeGalleryPostScreen> createState() =>
      _ComposeGalleryPostScreenState();
}

class _ComposeGalleryPostScreenState extends State<ComposeGalleryPostScreen> {
  final _caption = TextEditingController();
  // Picked file: either a path on disk (mobile/desktop, streamed) or
  // raw bytes (web, where dart:io isn't available).
  String? _mediaPath;
  Uint8List? _mediaBytes;
  int _mediaSize = 0;
  // Image-only preview bytes (we don't read videos into memory).
  Uint8List? _imagePreview;
  String _mediaExt = 'jpg';
  GalleryMediaType _type = GalleryMediaType.image;
  bool _saving = false;
  String? _uploadStatus; // visible during upload
  double? _uploadProgress; // 0..1 once we know real bytes

  bool get _hasNewMedia => _mediaPath != null || _mediaBytes != null;
  bool get _isEdit => widget.existing != null;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _caption.text = e.caption ?? '';
      _type = e.mediaType;
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  static const _videoExts = {
    'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv', '3gp', 'mpeg', 'mpg'
  };

  /// Single picker for either a photo or a video.
  ///
  /// On mobile/desktop we keep the on-disk path and stream from it
  /// during upload (so big videos never have to fit into RAM).
  /// On the web there is no real file system, so we fall back to
  /// reading bytes — `dart:io`'s `File` would throw
  /// "Unsupported operation: _Namespace" in the browser.
  Future<void> _pickMedia() async {
    final f = await ImagePicker().pickMedia();
    if (f == null) return;
    final ext = f.name.contains('.')
        ? f.name.split('.').last.toLowerCase()
        : '';
    final type = _videoExts.contains(ext)
        ? GalleryMediaType.video
        : GalleryMediaType.image;

    Uint8List? bytes;
    String? path;
    int size = 0;
    Uint8List? preview;

    if (kIsWeb) {
      bytes = await f.readAsBytes();
      size = bytes.lengthInBytes;
      if (type == GalleryMediaType.image) preview = bytes;
    } else {
      path = f.path;
      try {
        size = await File(f.path).length();
      } catch (_) {}
      if (type == GalleryMediaType.image) {
        try {
          preview = await f.readAsBytes();
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _mediaPath = path;
      _mediaBytes = bytes;
      _mediaSize = size;
      _imagePreview = preview;
      _mediaExt = ext.isEmpty
          ? (type == GalleryMediaType.video ? 'mp4' : 'jpg')
          : ext;
      _type = type;
    });
  }

  Future<void> _save() async {
    if (!_isEdit && !_hasNewMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a photo or video first')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _uploadStatus = null;
    });
    try {
      String? newUrl;
      GalleryMediaType? newType;
      if (_hasNewMedia) {
        final total = _mediaSize;
        setState(() {
          _uploadProgress = 0;
          _uploadStatus = 'Uploading 0 / ${_formatBytes(total)}…';
        });
        void reportProgress(int sent, int totalBytes) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = sent / totalBytes;
            _uploadStatus =
                'Uploading ${_formatBytes(sent)} / ${_formatBytes(totalBytes)}'
                ' · ${(sent * 100 / totalBytes).toStringAsFixed(0)}%';
          });
        }

        if (_mediaPath != null) {
          // Mobile / desktop: stream straight from disk.
          newUrl = await GalleryService.uploadFileWithProgress(
            localPath: _mediaPath!,
            fileExtension: _mediaExt,
            type: _type,
            onProgress: reportProgress,
          );
        } else {
          // Web fallback: bytes are already in memory.
          newUrl = await GalleryService.uploadMediaWithProgress(
            bytes: _mediaBytes!,
            fileExtension: _mediaExt,
            type: _type,
            onProgress: reportProgress,
          );
        }
        newType = _type;
      }
      if (!mounted) return;
      setState(() {
        _uploadProgress = null; // indeterminate while DB writes
        _uploadStatus = 'Saving post…';
      });
      final caption =
          _caption.text.trim().isEmpty ? null : _caption.text.trim();
      if (_isEdit) {
        await GalleryService.updatePost(
          id: widget.existing!.id,
          caption: _caption.text.trim(),
          photoUrl: newUrl,
          mediaType: newType,
        );
      } else {
        await GalleryService.addPost(
          photoUrl: newUrl!,
          mediaType: newType!,
          caption: caption,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uploadStatus = null;
        _uploadProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            _isEdit ? 'Could not save changes: $e' : 'Could not post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNewMedia = _hasNewMedia;
    final existingUrl = widget.existing?.photoUrl;
    final showExistingPreview = !hasNewMedia && existingUrl != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit ? 'Edit Gallery Post' : 'New Gallery Post')),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _saving,
            child: _form(hasNewMedia, showExistingPreview, existingUrl),
          ),
          if (_uploadStatus != null) _uploadOverlay(),
        ],
      ),
    );
  }

  Widget _uploadOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    color: AppColors.primary, size: 40),
                const SizedBox(height: 12),
                Text(
                  _uploadStatus!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _uploadProgress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(
      bool hasNewMedia, bool showExistingPreview, String? existingUrl) {
    return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (hasNewMedia || showExistingPreview)
                      ? AppColors.primary
                      : AppColors.offWhite,
                  width: (hasNewMedia || showExistingPreview) ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _preview(hasNewMedia, showExistingPreview, existingUrl),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.perm_media_outlined, size: 18),
              label: Text(hasNewMedia
                  ? 'Choose a different photo or video'
                  : 'Choose a photo or video'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _caption,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.cream),
                    )
                  : Icon(_isEdit ? Icons.save : Icons.upload, size: 18),
              label: Text(_isEdit ? 'Save Changes' : 'Post to Gallery'),
            ),
          ],
        );
  }

  Widget _preview(
      bool hasNewMedia, bool showExistingPreview, String? existingUrl) {
    if (hasNewMedia && _type == GalleryMediaType.image && _imagePreview != null) {
      return Image.memory(_imagePreview!, fit: BoxFit.cover);
    }
    if (hasNewMedia && _type == GalleryMediaType.video) {
      // We don't preview the chosen video before upload — just confirm
      // it and show its size so the editor knows what they're uploading.
      return Container(
        color: AppColors.dark,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie, size: 48, color: AppColors.cream),
              const SizedBox(height: 6),
              const Text('Video selected',
                  style: TextStyle(color: AppColors.cream)),
              if (_mediaSize > 0) ...[
                const SizedBox(height: 2),
                Text(_formatBytes(_mediaSize),
                    style: const TextStyle(
                        color: AppColors.cream, fontSize: 12)),
              ],
            ],
          ),
        ),
      );
    }
    if (showExistingPreview) {
      if (_type == GalleryMediaType.image) {
        return Image.network(existingUrl!, fit: BoxFit.cover);
      }
      return Container(
        color: AppColors.dark,
        child: const Center(
          child: Icon(Icons.movie, size: 48, color: AppColors.cream),
        ),
      );
    }
    return InkWell(
      onTap: _pickMedia,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.perm_media_outlined,
              size: 48, color: AppColors.primary),
          SizedBox(height: 8),
          Text('Tap to pick a photo or video'),
        ],
      ),
    );
  }
}
