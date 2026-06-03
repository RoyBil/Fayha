import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/choir_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';

/// Public detail page for an upcoming Concert or Big Rehearsal.
/// Opened by tapping a card in the audience home's "Coming Up" list.
class ConcertDetailScreen extends StatelessWidget {
  final Concert concert;
  const ConcertDetailScreen({super.key, required this.concert});

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  static const _weekdays = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];

  String _fullDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  String _time(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _openMap() async {
    final query = Uri.encodeComponent(concert.location);
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRehearsal = concert.isRehearsal;
    final accent = isRehearsal ? AppColors.secondaryDark : AppColors.accentDark;
    final kindLabel = isRehearsal ? 'BIG REHEARSAL' : 'CONCERT';
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: concert.posterUrl != null ? 320 : 140,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.cream,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                concert.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              centerTitle: false,
              background: concert.posterUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          concert.posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.primary),
                        ),
                        // Dark gradient at the bottom so the title is readable.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x88000000),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: AppColors.primary),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    kindLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElegantCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(theme, Icons.calendar_today,
                          'Date', _fullDate(concert.date)),
                      const Divider(height: 22),
                      _row(theme, Icons.schedule, 'Time',
                          _time(concert.date)),
                      const Divider(height: 22),
                      _row(theme, Icons.place_outlined, 'Location',
                          concert.location),
                    ],
                  ),
                ),
                if (concert.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('About this event',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ElegantCard(
                    child: Text(
                      concert.description,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openMap,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Get directions'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String label, String value) {
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
