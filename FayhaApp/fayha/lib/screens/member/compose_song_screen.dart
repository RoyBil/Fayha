import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/choir_songs_service.dart';
import '../../theme/app_theme.dart';

enum _SongTarget { audience, choir }

class ComposeSongScreen extends StatefulWidget {
  /// When non-null, the screen runs in edit mode for an existing
  /// choir song (the audience/choir toggle is hidden, fields are
  /// pre-filled, and uploads replace existing files only if picked).
  final ChoirSong? existing;
  const ComposeSongScreen({super.key, this.existing});

  @override
  State<ComposeSongScreen> createState() => _ComposeSongScreenState();
}

class _PickedAudio {
  final String filename;
  final String extension;
  final List<int> bytes;
  const _PickedAudio({
    required this.filename,
    required this.extension,
    required this.bytes,
  });
}

class _ComposeSongScreenState extends State<ComposeSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _composers = TextEditingController();
  final _description = TextEditingController();
  final _lyrics = TextEditingController();
  final _youtube = TextEditingController();
  _SongTarget _target = _SongTarget.choir;
  bool _saving = false;
  String? _progress;
  final List<_PickedAudio?> _parts =
      List<_PickedAudio?>.filled(choirVoiceParts.length, null);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _subtitle.text = e.subtitle ?? '';
      _composers.text = e.composers ?? '';
      _description.text = e.description ?? '';
      _lyrics.text = e.lyrics ?? '';
      _youtube.text = e.youtubeUrl ?? '';
      _target = _SongTarget.choir;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _composers.dispose();
    _description.dispose();
    _lyrics.dispose();
    _youtube.dispose();
    super.dispose();
  }

  Future<void> _pickAudio(int index) async {
    final typeGroup = XTypeGroup(
      label: 'Audio',
      extensions: const ['m4a', 'mp3', 'wav', 'aac', 'ogg'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name;
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'm4a';
    setState(() {
      _parts[index] = _PickedAudio(
        filename: name,
        extension: ext,
        bytes: bytes,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_target == _SongTarget.choir && !_isEdit) {
      // Create mode: every voice part must be picked.
      final missing = <String>[];
      for (var i = 0; i < _parts.length; i++) {
        if (_parts[i] == null) missing.add(choirVoiceParts[i]);
      }
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Missing audio for: ${missing.join(', ')}')),
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _progress = 'Saving…';
    });
    try {
      if (_target == _SongTarget.audience) {
        await AdminService.addSong(
          title: _title.text.trim(),
          subtitle: _subtitle.text.trim(),
          composers: _composers.text.trim(),
          description: _description.text.trim(),
          lyrics: _lyrics.text.trim(),
          youtubeUrl:
              _youtube.text.trim().isEmpty ? null : _youtube.text.trim(),
        );
      } else if (_isEdit) {
        // ===== EDIT MODE =====
        final existing = widget.existing!;
        // Only re-upload the parts the admin picked a new file for.
        final newUrls = List<String?>.filled(_parts.length, null);
        final picked = <int>[];
        for (var i = 0; i < _parts.length; i++) {
          if (_parts[i] != null) picked.add(i);
        }
        for (var k = 0; k < picked.length; k++) {
          final i = picked[k];
          setState(() => _progress =
              'Uploading ${choirVoiceParts[i]} (${k + 1}/${picked.length})…');
          final p = _parts[i]!;
          newUrls[i] = await ChoirSongsService.uploadPart(
            songId: existing.id,
            partKey: choirVoicePartKeys[i],
            bytes: Uint8List.fromList(p.bytes),
            fileExtension: p.extension,
          );
        }
        setState(() => _progress = 'Saving changes…');
        await ChoirSongsService.update(
          id: existing.id,
          title: _title.text.trim(),
          subtitle: _subtitle.text.trim(),
          composers: _composers.text.trim(),
          description: _description.text.trim(),
          lyrics: _lyrics.text.trim(),
          youtubeUrl: _youtube.text.trim(),
          soprano1Url: newUrls[0],
          soprano2Url: newUrls[1],
          alto1Url: newUrls[2],
          alto2Url: newUrls[3],
          tenor1Url: newUrls[4],
          tenor2Url: newUrls[5],
          bass1Url: newUrls[6],
          bass2Url: newUrls[7],
        );
      } else {
        // ===== CREATE CHOIR SONG =====
        final id = 'csong_${DateTime.now().millisecondsSinceEpoch}';
        final urls = <String>[];
        for (var i = 0; i < _parts.length; i++) {
          setState(() => _progress =
              'Uploading ${choirVoiceParts[i]} (${i + 1}/${_parts.length})…');
          final p = _parts[i]!;
          final url = await ChoirSongsService.uploadPart(
            songId: id,
            partKey: choirVoicePartKeys[i],
            bytes: Uint8List.fromList(p.bytes),
            fileExtension: p.extension,
          );
          urls.add(url);
        }
        setState(() => _progress = 'Publishing…');
        await ChoirSongsService.create(
          id: id,
          title: _title.text.trim(),
          subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
          composers:
              _composers.text.trim().isEmpty ? null : _composers.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          lyrics: _lyrics.text.trim().isEmpty ? null : _lyrics.text.trim(),
          youtubeUrl:
              _youtube.text.trim().isEmpty ? null : _youtube.text.trim(),
          soprano1Url: urls[0],
          soprano2Url: urls[1],
          alto1Url: urls[2],
          alto2Url: urls[3],
          tenor1Url: urls[4],
          tenor2Url: urls[5],
          bass1Url: urls[6],
          bass2Url: urls[7],
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _progress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit
            ? 'Could not save changes: $e'
            : 'Could not add song: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Song' : 'Add a Song')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (!_isEdit) ...[
                Text('Where does this song go?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _targetChoice(
                        label: 'Choir library',
                        sub: 'Members only · 8 voice parts',
                        icon: Icons.groups,
                        value: _SongTarget.choir,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _targetChoice(
                        label: 'Audience page',
                        sub: 'Public · YouTube only',
                        icon: Icons.public,
                        value: _SongTarget.audience,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              _field(_title, 'Title', Icons.music_note, required: true),
              const SizedBox(height: 14),
              _field(_subtitle, 'Translation / subtitle', Icons.translate),
              const SizedBox(height: 14),
              _field(_composers, 'Composers / arrangement', Icons.edit_note),
              const SizedBox(height: 14),
              _field(_description, 'Description', Icons.notes, lines: 3),
              const SizedBox(height: 14),
              _field(_lyrics, 'Lyrics', Icons.lyrics_outlined, lines: 6),
              const SizedBox(height: 14),
              _field(_youtube, 'YouTube link (optional)',
                  Icons.play_circle_outline),
              if (_target == _SongTarget.choir) ...[
                const SizedBox(height: 26),
                Text(
                  _isEdit
                      ? 'Voice part audio (replace any)'
                      : 'Voice part audio (all 8 required)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? 'Pick a new file only for the sections you want to replace.'
                      : 'Upload one audio file (m4a, mp3, wav…) for each section.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < choirVoiceParts.length; i++)
                  _partRow(i),
              ],
              const SizedBox(height: 24),
              if (_saving && _progress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text(_progress!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : Icon(_isEdit ? Icons.save : Icons.add, size: 18),
                label: Text(_isEdit ? 'Save Changes' : 'Add Song'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetChoice({
    required String label,
    required String sub,
    required IconData icon,
    required _SongTarget value,
  }) {
    final selected = _target == value;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _target = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.offWhite,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? AppColors.cream : AppColors.primary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected ? AppColors.cream : AppColors.dark,
                  )),
              const SizedBox(height: 2),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? AppColors.cream.withValues(alpha: 0.8)
                        : AppColors.gray,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partRow(int i) {
    final part = _parts[i];
    final picked = part != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: picked ? AppColors.secondary : AppColors.offWhite,
            width: picked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                choirVoicePartKeys[i].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(choirVoiceParts[i],
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    picked
                        ? part.filename
                        : (_isEdit
                            ? 'Current file kept — tap Replace to change'
                            : 'No file selected'),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _pickAudio(i),
              icon: Icon(
                (picked || _isEdit) ? Icons.swap_horiz : Icons.upload_file,
                size: 16,
              ),
              label: Text((picked || _isEdit) ? 'Replace' : 'Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool required = false, int lines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: lines > 1,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
