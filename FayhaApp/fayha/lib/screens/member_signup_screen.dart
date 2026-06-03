import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/choir_data.dart';
import '../data/map_data.dart';
import '../services/audience_data.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';

class MemberSignUpScreen extends StatefulWidget {
  const MemberSignUpScreen({super.key});

  @override
  State<MemberSignUpScreen> createState() => _MemberSignUpScreenState();
}

class _MemberSignUpScreenState extends State<MemberSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String? _branch;
  String? _voice;
  bool _obscure = true;
  bool _submitting = false;
  bool _submitted = false;

  // profile photo (held in memory until the account is created)
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  // clothing inventory
  static const _clothingTypes = ['Costume', 'T-shirt', 'Sweatshirt', 'Caps'];
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'One Size'];
  final Map<String, bool> _hasItem = {
    for (final t in _clothingTypes) t: false,
  };
  final Map<String, String> _itemSize = {
    for (final t in _clothingTypes) t: (t == 'Caps' ? 'One Size' : 'M'),
  };
  final Map<String, int> _itemQty = {for (final t in _clothingTypes) t: 1};

  // new vs returning
  bool _isReturning = false;
  DateTime? _joinDate;

  // trips the choir made (from the venues table), and the ones picked
  List<Venue> _allTrips = [];
  bool _tripsLoading = true;
  final Set<String> _selectedTrips = {};

  @override
  void initState() {
    super.initState();
    AudienceData.fetchVenues().then((v) {
      if (!mounted) return;
      setState(() {
        _allTrips = [...v]..sort((a, b) => a.sortDate.compareTo(b.sortDate));
        _tripsLoading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _tripsLoading = false);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _isMaestroEmail =>
      _email.text.trim().toLowerCase() == 'maestro@fayhanationalchoir.com';

  Future<void> _pickPhoto() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoExt = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : 'jpg';
    });
  }

  Future<DateTime?> _pickDate({DateTime? initial}) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(2015),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isMaestroEmail && (_branch == null || _voice == null)) {
      _toast('Please select your branch and voice section');
      return;
    }
    if (_isReturning && _joinDate == null) {
      _toast('Please pick the date you joined the choir');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _toast('Passwords do not match');
      return;
    }
    setState(() => _submitting = true);
    try {
      final trips = _selectedTrips.toList();
      await AuthService.signUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        branch: _branch ?? 'Tripoli',
        voiceSection: _voice ?? 'Soprano',
        joinDate: _isReturning ? _joinDate : null,
        travelsCount: _isReturning ? trips.length : 0,
        travelLocations: _isReturning ? trips : const [],
        isReturning: _isReturning,
        clothing: [
          for (final t in _clothingTypes)
            if (_hasItem[t] == true)
              {'type': t, 'size': _itemSize[t], 'quantity': _itemQty[t]},
        ],
      );
      // Account exists now — upload the photo if one was chosen.
      if (_photoBytes != null) {
        final uid = AuthService.currentUserId;
        if (uid != null) {
          try {
            await AuthService.uploadAvatar(
              memberId: uid,
              bytes: _photoBytes!,
              fileExtension: _photoExt,
            );
          } catch (_) {
            // Account was still created; photo can be added later from profile.
          }
        }
      }
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(_friendlyError(e));
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('already registered') || s.contains('already been registered')) {
      return 'That email is already registered. Try signing in.';
    }
    if (s.contains('Password')) return 'Password must be at least 6 characters.';
    return 'Could not register: $s';
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Member')),
      body: _submitted ? _pendingState(theme) : _form(theme),
    );
  }

  Widget _pendingState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_bottom, color: AppColors.accentDark, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Awaiting Approval',
              style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Your account has been created and is pending approval. The Maestro and admin team will review and confirm your access. You can sign in once approved.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _form(ThemeData theme) {
    return AbsorbPointer(
      absorbing: _submitting,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  if (_photoBytes != null)
                    CircleAvatar(
                      radius: 42,
                      backgroundImage: MemoryImage(_photoBytes!),
                    )
                  else
                    Avatar(
                      name: _name.text.isEmpty ? 'New Member' : _name.text,
                      size: 84,
                    ),
                  Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickPhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.camera_alt, size: 16, color: AppColors.dark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _photoBytes == null ? 'Add a profile photo (optional)' : 'Photo selected',
                style: theme.textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPassword,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _password.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            if (!_isMaestroEmail) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _branch,
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: ChoirData.branches
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _branch = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _voice,
                decoration: const InputDecoration(
                  labelText: 'Voice section',
                  prefixIcon: Icon(Icons.music_note_outlined),
                ),
                items: ChoirData.voiceSections
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _voice = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ],

            const SizedBox(height: 24),
            if (_isMaestroEmail)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium,
                        size: 20, color: AppColors.accentDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Founder account — branch, voice section and choir history are pre-configured. Just set your name, email and password.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isReturning ? AppColors.primary : AppColors.offWhite,
                    width: _isReturning ? 1.5 : 1,
                  ),
                ),
                child: SwitchListTile(
                  title: const Text('I am an existing choir member'),
                  subtitle:
                      const Text('Turn on to add your history with the choir'),
                  value: _isReturning,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isReturning = v),
                ),
              ),

            if (_isReturning) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your history with the choir',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    _dateTile(
                      label: 'When did you join Fayha?',
                      value: _joinDate,
                      onPick: () async {
                        final d = await _pickDate(initial: _joinDate);
                        if (d != null) setState(() => _joinDate = d);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.flight_takeoff, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Trips you joined with the choir',
                            style: theme.textTheme.titleSmall),
                        const Spacer(),
                        if (_selectedTrips.isNotEmpty)
                          Text('${_selectedTrips.length} selected',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _tripsPicker(theme),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _clothingSection(theme),
            ],
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : const Text('Submit for Approval'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripsPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _tripsLoading || _allTrips.isEmpty ? null : _openTripsSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.offWhite),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tripsLoading
                        ? 'Loading trips…'
                        : _allTrips.isEmpty
                            ? 'No choir trips on record yet'
                            : _selectedTrips.isEmpty
                                ? 'Choose the trips you joined'
                                : '${_selectedTrips.length} trip(s) selected',
                    style: TextStyle(
                      color: _selectedTrips.isEmpty
                          ? AppColors.gray
                          : AppColors.dark,
                    ),
                  ),
                ),
                if (!_tripsLoading && _allTrips.isNotEmpty)
                  const Icon(Icons.chevron_right, color: AppColors.gray),
              ],
            ),
          ),
        ),
        if (_selectedTrips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTrips
                .map((t) => Chip(
                      label: Text(t),
                      backgroundColor: Colors.white,
                      onDeleted: () => setState(() => _selectedTrips.remove(t)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  void _openTripsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            final filtered = _allTrips.where((v) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return v.city.toLowerCase().contains(q) ||
                  v.country.toLowerCase().contains(q);
            }).toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scroll) => Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Choir Trips',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search country or city…',
                        prefixIcon: Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) => setSheet(() => query = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final v = filtered[i];
                        final label = '${v.city}, ${v.country}';
                        final selected = _selectedTrips.contains(label);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setSheet(() {
                                if (selected) {
                                  _selectedTrips.remove(label);
                                } else {
                                  _selectedTrips.add(label);
                                }
                              });
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.offWhite,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 20,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.gray,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(label,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall),
                                        Text(v.date,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _clothingSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choir clothing you have', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Tell us what uniform items you already own.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        ..._clothingTypes.map((t) {
          final has = _hasItem[t] ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: has ? AppColors.primary : AppColors.offWhite,
                width: has ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      t == 'Suit'
                          ? Icons.checkroom
                          : t == 'Shirt'
                              ? Icons.dry_cleaning
                              : Icons.sports_baseball,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t == 'Suit' ? 'Suit (shirt + pants)' : t,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Switch(
                      value: has,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _hasItem[t] = v),
                    ),
                  ],
                ),
                if (has)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 28),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _itemSize[t],
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Size',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: _sizes
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _itemSize[t] = v ?? 'M'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Qty', style: theme.textTheme.labelMedium),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: (_itemQty[t] ?? 1) > 1
                              ? () => setState(() => _itemQty[t] = _itemQty[t]! - 1)
                              : null,
                        ),
                        Text('${_itemQty[t]}', style: theme.textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              setState(() => _itemQty[t] = (_itemQty[t] ?? 1) + 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
  }) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.offWhite),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value == null ? label : '$label: ${_fmt(value)}',
                style: TextStyle(
                  color: value == null ? AppColors.gray : AppColors.dark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray),
          ],
        ),
      ),
    );
  }
}
