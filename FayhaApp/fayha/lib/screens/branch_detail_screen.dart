import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/map_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';

/// Public detail page for one of the four choir branches. Opens
/// from tapping a branch row in the Audience map / Branches tab.
class BranchDetailScreen extends StatelessWidget {
  final BranchLocation branch;
  const BranchDetailScreen({super.key, required this.branch});

  Future<void> _openMap() async {
    await launchUrl(Uri.parse(branch.mapUrl),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = LatLng(branch.lat, branch.lng);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('${branch.name} Branch'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // Hero card with branch color.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [branch.color, branch.color.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.account_balance,
                    color: AppColors.cream, size: 40),
                const SizedBox(height: 8),
                Text(
                  '${branch.name} Branch',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  branch.practiceLocation,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.cream.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.event_outlined,
                  label: 'Opened',
                  value: '${branch.yearOpened}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.groups_outlined,
                  label: 'Members',
                  value: '~${branch.membersApprox}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Quick info
          const SectionHeader(eyebrow: 'About', title: 'The branch'),
          const SizedBox(height: 12),
          ElegantCard(
            child: Column(
              children: [
                _Row(
                  icon: Icons.person_outline,
                  label: 'Conductor',
                  value: branch.conductor,
                ),
                const Divider(height: 22),
                _Row(
                  icon: Icons.schedule,
                  label: 'Rehearsals',
                  value: branch.rehearsalSchedule,
                ),
                const Divider(height: 22),
                _Row(
                  icon: Icons.place_outlined,
                  label: 'Address',
                  value: branch.practiceLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ElegantCard(
            child: Text(
              branch.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),

          const SizedBox(height: 22),

          // Map
          const SectionHeader(eyebrow: 'Location', title: 'Find us'),
          const SizedBox(height: 12),
          ElegantCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 14,
                        minZoom: 4,
                        maxZoom: 19,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.pinchZoom |
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
                          userAgentPackageName: 'com.fayhanationalchoir.app',
                          additionalOptions: const {'r': ''},
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: Icon(Icons.account_balance,
                                color: branch.color, size: 32),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Get directions'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.offWhite),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.primary)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
  });

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
