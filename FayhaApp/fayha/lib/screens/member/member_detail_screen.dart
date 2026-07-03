import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/map_data.dart';
import '../../data/mock_data.dart';
import '../../services/attendance_service.dart';
import '../../services/member_songs_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';

class MemberDetailScreen extends StatefulWidget {
  final Member member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late Future<Set<String>> _songsFuture;
  int _liveRehearsals = 0;
  int _lastStatsVersion = -1;

  @override
  void initState() {
    super.initState();
    _songsFuture = MemberSongsService.fetchForMember(widget.member.id);
    _lastStatsVersion = AppState.instance.statsVersion;
    _reloadLiveStats();
    AppState.instance.addListener(_onAppStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChange);
    super.dispose();
  }

  void _onAppStateChange() {
    final v = AppState.instance.statsVersion;
    if (v != _lastStatsVersion) {
      _lastStatsVersion = v;
      _reloadLiveStats();
    }
  }

  Future<void> _reloadLiveStats() async {
    try {
      final n = await AttendanceService.rehearsalCountFor(widget.member.id);
      if (!mounted) return;
      setState(() => _liveRehearsals = n);
    } catch (_) {
      // ignore
    }
  }

  Member get member => widget.member;

  static String _singerLevelLabel(String v) {
    switch (v) {
      case 'not_on_stage':
        return 'Not on Stage';
      case 'on_stage':
        return 'On Stage';
      case 'assistant_conductor':
        return 'Assistant Conductor';
      case 'friend':
        return 'Friend';
      default:
        return v;
    }
  }

  static Color _singerLevelColor(String v) {
    switch (v) {
      case 'not_on_stage':
        return AppColors.gray;
      case 'on_stage':
        return AppColors.secondary;
      case 'assistant_conductor':
        return AppColors.accentDark;
      case 'friend':
        return AppColors.primary;
      default:
        return AppColors.gray;
    }
  }

  String _roleLabel() {
    switch (member.role) {
      case 'superAdmin':
        return 'Maestro';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  Future<void> _openMap() async {
    if (member.houseLat == null || member.houseLng == null) return;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${member.houseLat},${member.houseLng}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = MapData.colorFor(member.branch);
    final years = DateTime.now().year - member.joinDate.year;
    final hasHouse = member.houseLat != null && member.houseLng != null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Member')),
      body: BrandedBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            // ----- Header -----
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Avatar(
                    name: member.name,
                    size: 84,
                    photoUrl: member.photoUrl,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    member.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _roleLabel(),
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (member.singerLevel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _singerLevelLabel(member.singerLevel!),
                            style: TextStyle(
                              color: _singerLevelColor(member.singerLevel!),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${member.voiceSection} · ${member.branch} branch',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.cream.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ----- Stats grid: baseline + live attendance -----
            // Each rehearsal is 3 hours, so derive count from practice hours.
            Builder(
              builder: (context) {
                final baselineRehearsals = (member.practiceHours / 3).round();
                final practices = baselineRehearsals + _liveRehearsals;
                final hoursTotal = member.practiceHours + (_liveRehearsals * 3);
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatBox(
                      label: 'Concerts',
                      value: '${member.concertsCount}',
                      icon: Icons.theater_comedy,
                    ),
                    _StatBox(
                      label: 'Practices',
                      value: '$practices',
                      icon: Icons.event_available,
                    ),
                    _StatBox(
                      label: 'Hours',
                      value: hoursTotal.toStringAsFixed(0),
                      icon: Icons.timer_outlined,
                    ),
                    _StatBox(
                      label: 'Trips',
                      value: '${member.travelsCount}',
                      icon: Icons.flight_takeoff,
                    ),
                    _StatBox(
                      label: 'Years',
                      value: '$years',
                      icon: Icons.event_outlined,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 26),

            // ----- Contact / personal -----
            const SectionHeader(eyebrow: 'About', title: 'Personal'),
            const SizedBox(height: 12),
            ElegantCard(
              child: Column(
                children: [
                  _Row(
                    icon: Icons.calendar_today,
                    label: 'Joined',
                    value:
                        '${_monthName(member.joinDate.month)} ${member.joinDate.year}',
                  ),
                  if (member.phone.isNotEmpty) ...[
                    const Divider(height: 22),
                    _Row(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: member.phone,
                    ),
                  ],
                  if (member.email.isNotEmpty) ...[
                    const Divider(height: 22),
                    _Row(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      value: member.email,
                    ),
                  ],
                  if (member.isReturning &&
                      (member.breakFrom != null || member.breakTo != null)) ...[
                    const Divider(height: 22),
                    _Row(
                      icon: Icons.history_toggle_off,
                      label: 'Break',
                      value:
                          '${_fmtDate(member.breakFrom)} → ${_fmtDate(member.breakTo)}',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ----- House location -----
            if (hasHouse) ...[
              const SectionHeader(
                eyebrow: 'Location',
                title: 'House on the Map',
              ),
              const SizedBox(height: 12),
              ElegantCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              member.houseLat!,
                              member.houseLng!,
                            ),
                            initialZoom: 15,
                            minZoom: 4,
                            maxZoom: 19,
                            interactionOptions: const InteractionOptions(
                              flags:
                                  InteractiveFlag.pinchZoom |
                                  InteractiveFlag.drag |
                                  InteractiveFlag.doubleTapZoom |
                                  InteractiveFlag.flingAnimation,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName:
                                  'com.fayhanationalchoir.app',
                              additionalOptions: const {'r': ''},
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    member.houseLat!,
                                    member.houseLng!,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.home,
                                    size: 32,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.houseAddress?.isNotEmpty == true
                                      ? member.houseAddress!
                                      : 'Coordinates set',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${member.houseLat!.toStringAsFixed(4)}, ${member.houseLng!.toStringAsFixed(4)}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.open_in_new,
                              color: AppColors.primary,
                            ),
                            onPressed: _openMap,
                            tooltip: 'Open in Google Maps',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ----- Songs they know -----
            const SectionHeader(
              eyebrow: 'Repertoire',
              title: 'Songs They Know',
            ),
            const SizedBox(height: 12),
            FutureBuilder<Set<String>>(
              future: _songsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const ElegantCard(
                    child: SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final ids = snap.data ?? const <String>{};
                final knownSongs = MockData.songs
                    .where((s) => ids.contains(s.id))
                    .toList();
                if (knownSongs.isEmpty) {
                  return ElegantCard(
                    child: Text(
                      '${member.name.split(' ').first} hasn\'t memorized any songs yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return ElegantCard(
                  child: Column(
                    children: knownSongs
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColors.secondaryDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        s.subtitle,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // ----- Travel locations -----
            if (member.travelLocations.isNotEmpty) ...[
              const SectionHeader(eyebrow: 'Travels', title: 'Places Visited'),
              const SizedBox(height: 12),
              ElegantCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: member.travelLocations
                      .map(
                        (loc) => Chip(
                          label: Text(loc),
                          backgroundColor: AppColors.accent.withValues(
                            alpha: 0.18,
                          ),
                          side: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ----- Clothing -----
            if (member.clothing.isNotEmpty) ...[
              const SectionHeader(
                eyebrow: 'Wardrobe',
                title: 'Clothing Inventory',
              ),
              const SizedBox(height: 12),
              ElegantCard(
                child: Column(
                  children: member.clothing
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.offWhite,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _clothingIcon(c.type),
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.type,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      'Size ${c.size}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '×${c.quantity}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m - 1];
  }

  IconData _clothingIcon(String type) {
    switch (type.toLowerCase()) {
      case 'suit':
        return Icons.checkroom;
      case 'shirt':
        return Icons.dry_cleaning;
      case 'cap':
        return Icons.sports_baseball;
      default:
        return Icons.style;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Three boxes per row on phones, more on larger screens. Subtract
    // total padding (20 left + 20 right + 2*10 spacing) from screen width.
    final w = MediaQuery.of(context).size.width;
    final boxWidth = ((w - 40 - 20) / 3).clamp(90.0, 140.0);
    return SizedBox(
      width: boxWidth,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.offWhite),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
