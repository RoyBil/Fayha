import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
import '../../services/qr_attendance_service.dart';
import '../../theme/app_theme.dart';

class ComposeEventScreen extends StatefulWidget {
  /// When non-null, the screen edits the given event row.
  final Map<String, dynamic>? existing;
  const ComposeEventScreen({super.key, this.existing});

  @override
  State<ComposeEventScreen> createState() => _ComposeEventScreenState();
}

class _ComposeEventScreenState extends State<ComposeEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _mapsLink = TextEditingController();
  String _kind = 'concert';
  DateTime? _date;
  TimeOfDay? _time;
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
      _title.text = (e['title'] as String?) ?? '';
      _location.text = (e['location'] as String?) ?? '';
      _description.text = (e['description'] as String?) ?? '';
      _mapsLink.text = (e['maps_url'] as String?) ?? '';
      _kind = (e['kind'] as String?) ?? 'concert';
      final startsAt = e['starts_at'] as String?;
      if (startsAt != null) {
        final dt = DateTime.parse(startsAt).toLocal();
        _date = DateTime(dt.year, dt.month, dt.day);
        _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      _existingPosterUrl = e['poster_url'] as String?;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _mapsLink.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (t != null) setState(() => _time = t);
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
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a date and time')));
      return;
    }
    setState(() => _saving = true);
    try {
      final when = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      String? posterUrl;
      if (_posterBytes != null) {
        posterUrl = await AdminService.uploadEventPoster(
          bytes: _posterBytes!,
          fileExtension: _posterExt,
        );
      } else if (_isEdit) {
        posterUrl = _existingPosterUrl;
      }
      final mapsUrl = _mapsLink.text.trim();
      if (_isEdit) {
        await AdminService.updateEvent(
          id: widget.existing!['id'] as String,
          title: _title.text.trim(),
          location: _location.text.trim(),
          startsAt: when,
          kind: _kind,
          description: _description.text.trim(),
          posterUrl: posterUrl,
          mapsUrl: mapsUrl,
          clearMapsUrl: mapsUrl.isEmpty,
        );
      } else {
        final concertId = await AdminService.addEvent(
          title: _title.text.trim(),
          location: _location.text.trim(),
          startsAt: when,
          kind: _kind,
          description: _description.text.trim(),
          posterUrl: posterUrl,
          mapsUrl: mapsUrl.isEmpty ? null : mapsUrl,
        );
        // Auto-create a pre-scheduled QR attendance session for concerts
        // and big rehearsals: 5:55 PM → 9:00 PM on the event date.
        try {
          final sessionStart = DateTime(
            when.year,
            when.month,
            when.day,
            17,
            55,
          );
          final sessionEnd = DateTime(when.year, when.month, when.day, 21, 0);
          await QrAttendanceService.preScheduleForConcert(
            concertId: concertId,
            validFrom: sessionStart,
            expiresAt: sessionEnd,
            lateAfter: sessionStart.add(const Duration(minutes: 15)),
          );
        } catch (_) {
          // Best-effort — does not block event creation
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Could not save changes: $e' : 'Could not add event: $e',
          ),
        ),
      );
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Event' : 'Add Event')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _kindChoice('concert', 'Concert', Icons.music_note),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _kindChoice(
                      'rehearsal',
                      'Big Rehearsal',
                      Icons.groups,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _pickTile(
                      icon: Icons.calendar_today,
                      label: _date == null ? 'Date' : _fmtDate(_date!),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pickTile(
                      icon: Icons.schedule,
                      label: _time == null ? 'Time' : _time!.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mapsLink,
                decoration: const InputDecoration(
                  labelText: 'Google Maps link (optional)',
                  prefixIcon: Icon(Icons.map_outlined),
                  hintText: 'https://maps.google.com/…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
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
                    : Icon(_isEdit ? Icons.save : Icons.add, size: 18),
                label: Text(_isEdit ? 'Save Changes' : 'Add Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChoice(String value, String label, IconData icon) {
    final selected = _kind == value;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _kind = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
                color: selected ? AppColors.cream : AppColors.primary,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? AppColors.cream : AppColors.dark,
                ),
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
                  'Poster (optional)',
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

  Widget _pickTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.offWhite),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
