import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../services/choir_history_service.dart';
import '../../theme/app_theme.dart';

class ComposeChoirHistoryTripScreen extends StatefulWidget {
  final ChoirHistoryTrip? existing;
  const ComposeChoirHistoryTripScreen({super.key, this.existing});

  @override
  State<ComposeChoirHistoryTripScreen> createState() =>
      _ComposeChoirHistoryTripScreenState();
}

class _PickedPhoto {
  final String filename;
  final String extension;
  final List<int> bytes;
  const _PickedPhoto({
    required this.filename,
    required this.extension,
    required this.bytes,
  });
}

class _ComposeChoirHistoryTripScreenState
    extends State<ComposeChoirHistoryTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _description = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _existingPhotos = [];
  final List<_PickedPhoto> _newPhotos = [];
  bool _saving = false;
  String? _progress;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _city.text = e.city;
      _country.text = e.country;
      _description.text = e.description ?? '';
      _startDate = e.startDate;
      _endDate = e.endDate;
      _existingPhotos = List.from(e.photoUrls);
      if (e.lat != null) _lat.text = e.lat!.toString();
      if (e.lng != null) _lng.text = e.lng!.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _country.dispose();
    _description.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return;
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final name = f.name;
      final ext =
          name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
      setState(() {
        _newPhotos.add(
          _PickedPhoto(filename: name, extension: ext, bytes: bytes),
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a start date')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _progress = 'Saving…';
    });
    try {
      final double? lat = double.tryParse(_lat.text.trim());
      final double? lng = double.tryParse(_lng.text.trim());
      final bool hadCoords =
          widget.existing?.lat != null || widget.existing?.lng != null;
      final bool clearedCoords =
          _lat.text.trim().isEmpty && _lng.text.trim().isEmpty && hadCoords;

      final String tripId;
      if (_isEdit) {
        tripId = widget.existing!.id;
        await ChoirHistoryService.update(
          tripId,
          name: _name.text.trim(),
          city: _city.text.trim(),
          country: _country.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          clearEndDate: _endDate == null && widget.existing?.endDate != null,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          lat: lat,
          lng: lng,
          clearCoordinates: clearedCoords,
        );
      } else {
        tripId = await ChoirHistoryService.create(
          name: _name.text.trim(),
          city: _city.text.trim(),
          country: _country.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          lat: lat,
          lng: lng,
        );
      }

      // Upload any new photos
      final uploaded = <String>[];
      for (var i = 0; i < _newPhotos.length; i++) {
        final p = _newPhotos[i];
        setState(
          () => _progress =
              'Uploading photo ${i + 1} of ${_newPhotos.length}…',
        );
        final url = await ChoirHistoryService.uploadPhoto(
          tripId: tripId,
          bytes: Uint8List.fromList(p.bytes),
          fileExtension: p.extension,
        );
        uploaded.add(url);
      }

      // Persist photo list if anything changed
      final photosChanged = uploaded.isNotEmpty ||
          _existingPhotos.length != (widget.existing?.photoUrls.length ?? 0);
      if (photosChanged) {
        setState(() => _progress = 'Saving photos…');
        await ChoirHistoryService.update(
          tripId,
          photoUrls: [..._existingPhotos, ...uploaded],
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _fmtDate(DateTime? d) =>
      d == null ? 'Pick date' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Trip' : 'Add Historical Trip'),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              if (_progress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _progress!,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: AppColors.gray),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ── Core fields ─────────────────────────────────────────────
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Trip name *',
                  hintText: 'e.g. Cannes International Choral Festival 2019',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'City *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _country,
                      decoration: const InputDecoration(labelText: 'Country *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Dates ────────────────────────────────────────────────────
              Text('Travel dates *', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _startDate = d);
                      },
                      icon: const Icon(Icons.flight_takeoff, size: 16),
                      label: Text(_fmtDate(_startDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate:
                              _endDate ?? (_startDate ?? DateTime.now()),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _endDate = d);
                      },
                      icon: const Icon(Icons.flight_land, size: 16),
                      label: Text(_fmtDate(_endDate)),
                    ),
                  ),
                ],
              ),
              if (_endDate != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _endDate = null),
                    child: const Text('Clear end date'),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // ── Description ──────────────────────────────────────────────
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'What did the choir do? Highlights, achievements, impressions…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),

              // ── Coordinates (optional, for map pin) ──────────────────────
              Text(
                'Map coordinates (optional)',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Used to show a pin on the map. Find them on Google Maps — right-click the city and copy the numbers.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g. 26.6087',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lng,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g. 37.9226',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Photos ───────────────────────────────────────────────────
              Text('Photos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Add photos from the trip. Tap a thumbnail to remove it.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),

              // Existing photos
              if (_existingPhotos.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _existingPhotos.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () =>
                        setState(() => _existingPhotos.removeAt(i)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            _existingPhotos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.offWhite,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.gray,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // New photos queued for upload
              if (_newPhotos.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _newPhotos
                      .asMap()
                      .entries
                      .map(
                        (e) => Chip(
                          label: Text(
                            e.value.filename,
                            overflow: TextOverflow.ellipsis,
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _newPhotos.removeAt(e.key)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],

              OutlinedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add photos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
