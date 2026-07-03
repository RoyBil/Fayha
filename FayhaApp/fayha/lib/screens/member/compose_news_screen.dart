import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class ComposeNewsScreen extends StatefulWidget {
  /// When non-null, the screen runs in edit mode for an existing row.
  final Map<String, dynamic>? existing;
  const ComposeNewsScreen({super.key, this.existing});

  @override
  State<ComposeNewsScreen> createState() => _ComposeNewsScreenState();
}

class _ComposeNewsScreenState extends State<ComposeNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateLabel = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  Uint8List? _posterBytes;
  String _posterExt = 'jpg';
  String? _existingPosterUrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _dateLabel.text = (e['date_label'] as String?) ?? '';
      _title.text = (e['title'] as String?) ?? '';
      _body.text = (e['body'] as String?) ?? '';
      _existingPosterUrl = e['poster_url'] as String?;
    }
  }

  @override
  void dispose() {
    _dateLabel.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final ext = f.name.contains('.')
        ? f.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!mounted) return;
    setState(() {
      _posterBytes = bytes;
      _posterExt = ext;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? posterUrl;
      if (_posterBytes != null) {
        posterUrl = await AdminService.uploadEventPoster(
          bytes: _posterBytes!,
          fileExtension: _posterExt,
        );
      } else if (_isEdit) {
        // Keep the existing poster — explicitly pass it so updateNews
        // doesn't treat null as "clear it".
        posterUrl = _existingPosterUrl;
      }
      if (_isEdit) {
        await AdminService.updateNews(
          id: widget.existing!['id'] as String,
          dateLabel: _dateLabel.text.trim(),
          title: _title.text.trim(),
          body: _body.text.trim(),
          posterUrl: posterUrl,
        );
      } else {
        await AdminService.addNews(
          dateLabel: _dateLabel.text.trim(),
          title: _title.text.trim(),
          body: _body.text.trim(),
          posterUrl: posterUrl,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Could not save changes: $e' : 'Could not post news: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit News' : 'Post News')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextFormField(
                controller: _dateLabel,
                decoration: const InputDecoration(
                  labelText: 'Date label (e.g. "May 2026")',
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Headline',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _body,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Article',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _posterPicker(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cream,
                        ),
                      )
                    : Icon(_isEdit ? Icons.save : Icons.publish, size: 18),
                label: Text(_isEdit ? 'Save Changes' : 'Publish News'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterPicker() {
    final hasPoster = _posterBytes != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasPoster ? AppColors.primary : AppColors.offWhite,
          width: hasPoster ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cover image (optional)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: _pickPoster,
                icon: Icon(
                  hasPoster ? Icons.swap_horiz : Icons.upload,
                  size: 16,
                ),
                label: Text(hasPoster ? 'Replace' : 'Choose image'),
              ),
            ],
          ),
          if (hasPoster) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _posterBytes!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ] else if (_existingPosterUrl != null &&
              _existingPosterUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _existingPosterUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
