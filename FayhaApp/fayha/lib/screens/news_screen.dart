import 'package:flutter/material.dart';
import '../data/choir_data.dart';
import '../data/map_data.dart';
import '../data/mock_data.dart' show SocialPost;
import '../services/audience_data.dart';
import '../services/concerts_service.dart';
import '../services/messages_service.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final Set<int> _subscribedConcerts = <int>{};
  late Future<List<Concert>> _upcoming;
  late Future<List<NewsItem>> _news;
  late Future<List<SocialPost>> _social;
  late Future<List<BranchLocation>> _branches;
  late Future<List<ChoirMessage>> _announcements;

  @override
  void initState() {
    super.initState();
    _upcoming = ConcertsService.fetchUpcoming();
    _news = AudienceData.fetchNews();
    _social = AudienceData.fetchSocialPosts();
    _branches = AudienceData.fetchBranches();
    _announcements = MessagesService.fetch();
  }

  void _toggleSubscribe(int index) {
    setState(() {
      if (_subscribedConcerts.contains(index)) {
        _subscribedConcerts.remove(index);
      } else {
        _subscribedConcerts.add(index);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You will be notified before this concert')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ===== ANNOUNCEMENTS =====
        FutureBuilder<List<ChoirMessage>>(
          future: _announcements,
          builder: (context, snap) {
            final msgs = (snap.data ?? const <ChoirMessage>[])
                .where((m) =>
                    m.audience == 'everyone' || m.audience == 'audience')
                .toList();
            if (msgs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  eyebrow: 'From the Choir',
                  title: 'Announcements',
                ),
                const SizedBox(height: 16),
                ...msgs.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElegantCard(
                        background: AppColors.offWhite,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(m.body,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.55)),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        // ===== LATEST NEWS =====
        const SectionHeader(
          eyebrow: 'Latest',
          title: 'News & Highlights',
          subtitle: 'Updates from the choir, performances, and announcements.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<NewsItem>>(
          future: _news,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snap.data ?? const <NewsItem>[];
            return Column(
              children: items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NewsCard(
                          date: item.date,
                          title: item.title,
                          body: item.body,
                          posterUrl: item.posterUrl,
                        ),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<SocialPost>>(
          future: _social,
          builder: (context, snap) {
            final posts = snap.data ?? const <SocialPost>[];
            if (snap.connectionState != ConnectionState.done || posts.isEmpty) {
              return const SizedBox.shrink();
            }
            return _SocialSection(posts: posts);
          },
        ),

        const SizedBox(height: 36),
        // ===== UPCOMING CONCERTS =====
        const SectionHeader(
          eyebrow: 'On Stage',
          title: 'Upcoming Concerts',
          subtitle: 'Save the date — opt in to a reminder for any concert.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Concert>>(
          future: _upcoming,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Could not load concerts. Pull to retry.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final concerts = snap.data ?? const <Concert>[];
            if (concerts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No upcoming concerts announced yet — check back soon.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return Column(
              children: List.generate(concerts.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConcertCard(
                    concert: concerts[i],
                    subscribed: _subscribedConcerts.contains(i),
                    onToggle: () => _toggleSubscribe(i),
                  ),
                );
              }),
            );
          },
        ),

        const SizedBox(height: 36),
        // ===== REHEARSAL LOCATIONS =====
        const SectionHeader(
          eyebrow: 'Rehearsals',
          title: 'Where We Practice',
          subtitle: 'Branches across Lebanon — tap for details on the Map tab.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<BranchLocation>>(
          future: _branches,
          builder: (context, snap) {
            final branches = snap.data ?? const <BranchLocation>[];
            if (snap.connectionState != ConnectionState.done ||
                branches.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              children: branches
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RehearsalCard(branch: b),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final String date;
  final String title;
  final String body;
  final String? posterUrl;
  const _NewsCard({
    required this.date,
    required this.title,
    required this.body,
    this.posterUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            title: title,
            body: body,
            dateLabel: date,
            posterUrl: posterUrl,
          ),
        ),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (posterUrl != null && posterUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              child: Image.network(
                posterUrl!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date.toUpperCase(), style: theme.textTheme.labelSmall),
                const SizedBox(height: 6),
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Read more',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialSection extends StatelessWidget {
  final List<SocialPost> posts;
  const _SocialSection({required this.posts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Text(
            'From our social feed',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.accentDark,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...posts.map((p) {
          final isInsta = p.platform == 'Instagram';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElegantCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isInsta ? AppColors.primary : AppColors.secondary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isInsta ? Icons.camera_alt : Icons.facebook,
                      size: 16,
                      color: isInsta ? AppColors.primary : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.author, style: theme.textTheme.titleSmall),
                        Text('${p.platform} · ${p.postedAgo}',
                            style: theme.textTheme.labelSmall),
                        const SizedBox(height: 6),
                        Text(p.body,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ConcertCard extends StatelessWidget {
  final Concert concert;
  final bool subscribed;
  final VoidCallback onToggle;
  const _ConcertCard({
    required this.concert,
    required this.subscribed,
    required this.onToggle,
  });

  static const _monthsShort = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _time(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(concert.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.gray),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_months[concert.date.month - 1]} ${concert.date.day} · ${_time(concert.date)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppColors.gray),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(concert.location, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            concert.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: subscribed
                    ? FilledButton.icon(
                        onPressed: onToggle,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.cream,
                        ),
                        icon: const Icon(Icons.notifications_active, size: 18),
                        label: const Text('Reminder On'),
                      )
                    : OutlinedButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.notifications_outlined, size: 18),
                        label: const Text('Remind Me'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RehearsalCard extends StatelessWidget {
  final BranchLocation branch;
  const _RehearsalCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 6, height: 56,
            decoration: BoxDecoration(
              color: branch.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: branch.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on, color: branch.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${branch.name} Branch', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(branch.practiceLocation, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(branch.rehearsalSchedule,
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
