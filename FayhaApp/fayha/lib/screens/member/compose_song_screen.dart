import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/mock_data.dart';
import '../../services/admin_service.dart';
import '../../services/choir_songs_service.dart';
import '../../theme/app_theme.dart';

enum _SongTarget { audience, choir }

class ComposeSongScreen extends StatefulWidget {
  /// Edit mode for an existing choir library song.
  final ChoirSong? existing;

  /// Edit mode for an existing audience (public) song.
  final RepertoireSong? existingAudience;
  const ComposeSongScreen({super.key, this.existing, this.existingAudience});

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
  final List<_PickedAudio?> _parts = List<_PickedAudio?>.filled(
    choirVoiceParts.length,
    null,
  );
  _PickedAudio? _audienceAudio;
  _PickedAudio? _sheetMusic;

  bool get _isEdit => widget.existing != null;
  bool get _isAudienceEdit => widget.existingAudience != null;

  // Existing sheet-music URL (edit mode) — shown so user knows one exists.
  String? _existingSheetMusicUrl;

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
      _existingSheetMusicUrl = e.sheetMusicUrl;
      _target = _SongTarget.choir;
    }
    final ea = widget.existingAudience;
    if (ea != null) {
      _title.text = ea.title;
      _subtitle.text = ea.subtitle;
      _composers.text = ea.composers;
      _description.text = ea.description ?? '';
      _lyrics.text = ea.lyrics;
      _youtube.text = ea.youtubeUrl ?? '';
      _target = _SongTarget.audience;
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

  /// Re-encodes an MP3 at 128 kbps when the file exceeds 3 MB.
  /// Returns the original bytes unchanged for non-MP3 files, files that are
  /// already within the limit, or when FFmpeg fails (safe fallback).
  static Future<List<int>> _compressMp3IfNeeded(
    List<int> bytes,
    String extension,
  ) async {
    const limit = 3 * 1024 * 1024; // 3 MB
    if (extension.toLowerCase() != 'mp3' || bytes.length <= limit) {
      return bytes;
    }
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final inputPath = '${tempDir.path}/fayha_in_$ts.mp3';
    final outputPath = '${tempDir.path}/fayha_out_$ts.mp3';
    try {
      await File(inputPath).writeAsBytes(bytes);
      final session = await FFmpegKit.execute(
        '-i "$inputPath" -b:a 128k -ar 44100 -y "$outputPath"',
      );
      final rc = await session.getReturnCode();
      if (!ReturnCode.isSuccess(rc)) return bytes;
      final compressed = await File(outputPath).readAsBytes();
      return compressed.length < bytes.length ? compressed : bytes;
    } catch (_) {
      return bytes;
    } finally {
      try {
        await File(inputPath).delete();
      } catch (_) {}
      try {
        await File(outputPath).delete();
      } catch (_) {}
    }
  }

  Future<void> _pickAudienceAudio() async {
    const typeGroup = XTypeGroup(
      label: 'Audio',
      extensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'mp3';
    setState(() {
      _audienceAudio = _PickedAudio(
        filename: name,
        extension: ext,
        bytes: bytes,
      );
    });
  }

  Future<void> _pickSheetMusic() async {
    const typeGroup = XTypeGroup(
      label: 'Sheet Music',
      extensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'pdf';
    setState(() {
      _sheetMusic = _PickedAudio(filename: name, extension: ext, bytes: bytes);
    });
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
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'm4a';
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
      // Create mode: at least one voice part is required so the song
      // has something to play.
      final any = _parts.any((p) => p != null);
      if (!any) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload at least one voice part (e.g. Soprano).'),
          ),
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
        String? audioUrl;
        if (_audienceAudio != null) {
          setState(() => _progress = 'Processing audio…');
          final finalBytes = await _compressMp3IfNeeded(
            _audienceAudio!.bytes,
            _audienceAudio!.extension,
          );
          setState(() => _progress = 'Uploading audio…');
          audioUrl = await AdminService.uploadSongAudio(
            bytes: Uint8List.fromList(finalBytes),
            fileExtension: _audienceAudio!.extension,
          );
        }
        setState(() => _progress = 'Saving…');
        if (_isAudienceEdit) {
          await AdminService.updateSong(
            id: widget.existingAudience!.id,
            title: _title.text.trim(),
            subtitle: _subtitle.text.trim().isEmpty
                ? null
                : _subtitle.text.trim(),
            composers: _composers.text.trim().isEmpty
                ? null
                : _composers.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            lyrics: _lyrics.text.trim().isEmpty ? null : _lyrics.text.trim(),
            youtubeUrl: _youtube.text.trim().isEmpty
                ? null
                : _youtube.text.trim(),
            audioUrl: audioUrl,
          );
        } else {
          await AdminService.addSong(
            title: _title.text.trim(),
            subtitle: _subtitle.text.trim().isEmpty
                ? null
                : _subtitle.text.trim(),
            composers: _composers.text.trim().isEmpty
                ? null
                : _composers.text.trim(),
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            lyrics: _lyrics.text.trim().isEmpty ? null : _lyrics.text.trim(),
            youtubeUrl: _youtube.text.trim().isEmpty
                ? null
                : _youtube.text.trim(),
            audioUrl: audioUrl,
          );
        }
      } else if (_isEdit) {
        // ===== EDIT MODE =====
        final existing = widget.existing!;
        final partPatch = <String, String?>{};
        final picked = <int>[];
        for (var i = 0; i < _parts.length; i++) {
          if (_parts[i] != null) picked.add(i);
        }
        for (var k = 0; k < picked.length; k++) {
          final i = picked[k];
          setState(
            () => _progress =
                'Processing ${choirVoiceParts[i]} (${k + 1}/${picked.length})…',
          );
          final p = _parts[i]!;
          final finalBytes = await _compressMp3IfNeeded(p.bytes, p.extension);
          setState(
            () => _progress =
                'Uploading ${choirVoiceParts[i]} (${k + 1}/${picked.length})…',
          );
          partPatch[choirVoicePartKeys[i]] = await ChoirSongsService.uploadPart(
            songId: existing.id,
            partKey: choirVoicePartKeys[i],
            bytes: Uint8List.fromList(finalBytes),
            fileExtension: p.extension,
          );
        }
        String? newSheetUrl;
        if (_sheetMusic != null) {
          setState(() => _progress = 'Uploading sheet music…');
          newSheetUrl = await ChoirSongsService.uploadSheetMusic(
            songId: existing.id,
            bytes: Uint8List.fromList(_sheetMusic!.bytes),
            fileExtension: _sheetMusic!.extension,
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
          sheetMusicUrl: newSheetUrl,
          partUrls: partPatch.isEmpty ? null : partPatch,
        );
        ChoirSongsService.invalidateCache();
      } else {
        // ===== CREATE CHOIR SONG =====
        final id = 'csong_${DateTime.now().millisecondsSinceEpoch}';
        final partUrls = <String, String?>{};
        final picked = <int>[];
        for (var i = 0; i < _parts.length; i++) {
          if (_parts[i] != null) picked.add(i);
        }
        for (var k = 0; k < picked.length; k++) {
          final i = picked[k];
          setState(
            () => _progress =
                'Processing ${choirVoiceParts[i]} (${k + 1}/${picked.length})…',
          );
          final p = _parts[i]!;
          final finalBytes = await _compressMp3IfNeeded(p.bytes, p.extension);
          setState(
            () => _progress =
                'Uploading ${choirVoiceParts[i]} (${k + 1}/${picked.length})…',
          );
          partUrls[choirVoicePartKeys[i]] = await ChoirSongsService.uploadPart(
            songId: id,
            partKey: choirVoicePartKeys[i],
            bytes: Uint8List.fromList(finalBytes),
            fileExtension: p.extension,
          );
        }
        String? newSheetUrl;
        if (_sheetMusic != null) {
          setState(() => _progress = 'Uploading sheet music…');
          newSheetUrl = await ChoirSongsService.uploadSheetMusic(
            songId: id,
            bytes: Uint8List.fromList(_sheetMusic!.bytes),
            fileExtension: _sheetMusic!.extension,
          );
        }
        setState(() => _progress = 'Publishing…');
        await ChoirSongsService.create(
          id: id,
          title: _title.text.trim(),
          subtitle: _subtitle.text.trim().isEmpty
              ? null
              : _subtitle.text.trim(),
          composers: _composers.text.trim().isEmpty
              ? null
              : _composers.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          lyrics: _lyrics.text.trim().isEmpty ? null : _lyrics.text.trim(),
          youtubeUrl: _youtube.text.trim().isEmpty
              ? null
              : _youtube.text.trim(),
          sheetMusicUrl: newSheetUrl,
          partUrls: partUrls,
        );
      }
      ChoirSongsService.invalidateCache();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _progress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Could not save changes: $e' : 'Could not add song: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit || _isAudienceEdit ? 'Edit Song' : 'Add a Song'),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (!_isEdit && !_isAudienceEdit) ...[
                Text(
                  'Where does this song go?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _targetChoice(
                        label: 'Choir library',
                        sub: 'Members only · 9 voice parts',
                        icon: Icons.groups,
                        value: _SongTarget.choir,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _targetChoice(
                        label: 'Audience page',
                        sub: 'Public · with audio',
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
              _field(
                _youtube,
                'YouTube link (optional)',
                Icons.play_circle_outline,
              ),
              if (_target == _SongTarget.audience) ...[
                const SizedBox(height: 22),
                Text(
                  'Audio file',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _isAudienceEdit
                      ? 'Pick a new file to replace the existing audio, or leave empty to keep it.'
                      : 'Upload an mp3, m4a or wav file so visitors can listen to the song.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _audienceAudioRow(),
              ],
              if (_target == _SongTarget.choir) ...[
                const SizedBox(height: 26),
                Text(
                  _isEdit
                      ? 'Voice part audio (replace any)'
                      : 'Voice part audio (optional per part)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? 'Pick a new file only for the sections you want to replace.'
                      : 'Upload an audio file (m4a, mp3, wav…) for each section you have ready. At least one is required.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < choirVoiceParts.length; i++) _partRow(i),
                const SizedBox(height: 22),
                Text(
                  'Sheet music (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _existingSheetMusicUrl != null
                      ? 'A score is already uploaded. Pick a file to replace it.'
                      : 'Upload a PDF or image score that members can view.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _sheetMusicRow(),
              ],
              const SizedBox(height: 24),
              if (_saving && _progress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text(
                      _progress!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
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
                    : Icon(
                        (_isEdit || _isAudienceEdit) ? Icons.save : Icons.add,
                        size: 18,
                      ),
                label: Text(
                  (_isEdit || _isAudienceEdit) ? 'Save Changes' : 'Add Song',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audienceAudioRow() {
    final picked = _audienceAudio != null;
    return Container(
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
            child: const Icon(
              Icons.audiotrack,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              picked
                  ? _audienceAudio!.filename
                  : (_isAudienceEdit
                        ? 'Current audio kept — tap Replace to change'
                        : 'No file selected'),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _pickAudienceAudio,
            icon: Icon(
              (picked || _isAudienceEdit)
                  ? Icons.swap_horiz
                  : Icons.upload_file,
              size: 16,
            ),
            label: Text((picked || _isAudienceEdit) ? 'Replace' : 'Upload'),
          ),
        ],
      ),
    );
  }

  Widget _sheetMusicRow() {
    final picked = _sheetMusic != null;
    final hasExisting = _existingSheetMusicUrl != null;
    return Container(
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
              color: AppColors.accentDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.accentDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              picked
                  ? _sheetMusic!.filename
                  : (hasExisting
                        ? 'Score already uploaded — tap Replace to change'
                        : 'No file selected'),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _pickSheetMusic,
            icon: Icon(
              (picked || hasExisting) ? Icons.swap_horiz : Icons.upload_file,
              size: 16,
            ),
            label: Text((picked || hasExisting) ? 'Replace' : 'Upload'),
          ),
        ],
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
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.cream : AppColors.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? AppColors.cream : AppColors.dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? AppColors.cream.withValues(alpha: 0.8)
                      : AppColors.gray,
                ),
              ),
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
                  Text(
                    choirVoiceParts[i],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool required = false,
    int lines = 1,
  }) {
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
