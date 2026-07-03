import 'package:flutter/material.dart';
import '../data/choir_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';
import 'concert_detail_screen.dart';
import 'public_map_screen.dart';

class ConcertsScreen extends StatelessWidget {
  const ConcertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const SectionHeader(
          eyebrow: 'On Stage',
          title: 'Upcoming Concerts',
          subtitle: 'Join us at our next performances across Lebanon.',
        ),
        const SizedBox(height: 20),
        ...ChoirData.upcomingConcerts.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ConcertTile(concert: c),
          ),
        ),
        const SizedBox(height: 32),
        _RehearsalLocationsCard(),
      ],
    );
  }
}

class _ConcertTile extends StatelessWidget {
  final Concert concert;
  const _ConcertTile({required this.concert});

  static const _months = [
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

  static const _monthsShort = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  String _formatTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compact list tile — full details open on tap via
    // ConcertDetailScreen. The previous version expanded the
    // description + action buttons inline, which made the list page
    // feel like a stack of separate screens.
    return ElegantCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConcertDetailScreen(concert: concert),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  _monthsShort[concert.date.month - 1],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accentLight,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  concert.date.day.toString(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  concert.date.year.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.cream.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(concert.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 13, color: AppColors.gray),
                    const SizedBox(width: 4),
                    Text(
                      '${_months[concert.date.month - 1]} ${concert.date.day} · ${_formatTime(concert.date)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        concert.location,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}

class _RehearsalLocationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      background: AppColors.offWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_city,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text('Rehearsal Branches', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Weekly rehearsals at four branches across Lebanon. Tap a branch to see it on the map.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ChoirData.branches
                .map(
                  (b) => ActionChip(
                    avatar: const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(b),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('$b Branch')),
                          body: PublicMapScreen(initialBranchName: b),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
