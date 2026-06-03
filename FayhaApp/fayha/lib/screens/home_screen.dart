import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/choir_data.dart';
import '../data/mock_data.dart';
import '../services/audience_data.dart';
import '../services/concerts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';
import 'concert_detail_screen.dart';
import 'join_screen.dart';
import 'public_song_player_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToMusic;
  final VoidCallback? onGoToNews;

  const HomeScreen({super.key, this.onGoToMusic, this.onGoToNews});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _newsletter = TextEditingController();
  bool _subscribed = false;
  late Future<List<Concert>> _upcoming;
  late Future<List<RepertoireSong>> _songs;
  late Future<List<SocialPost>> _social;

  @override
  void initState() {
    super.initState();
    _upcoming = ConcertsService.fetchUpcoming();
    _songs = AudienceData.fetchSongs();
    _social = AudienceData.fetchSocialPosts();
  }

  @override
  void dispose() {
    _newsletter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _Hero(),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Upcoming =====
              FutureBuilder<List<Concert>>(
                future: _upcoming,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final concerts = snap.data ?? const <Concert>[];
                  if (concerts.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionRow(
                        eyebrow: 'Upcoming',
                        title: 'Coming Up',
                        onSeeMore: widget.onGoToNews,
                      ),
                      const SizedBox(height: 16),
                      ...concerts.take(3).map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NextConcertCard(concert: c),
                          )),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // ===== Join the Choir CTA =====
              _JoinCta(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinScreen()),
                ),
              ),
              const SizedBox(height: 36),

              // ===== Songs =====
              _SectionRow(
                eyebrow: 'Listen',
                title: 'Our Music',
                onSeeMore: widget.onGoToMusic,
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<RepertoireSong>>(
                future: _songs,
                builder: (context, snap) {
                  final songs = (snap.data ?? const <RepertoireSong>[]).take(3).toList();
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Column(
                    children: songs
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SongTile(song: s),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 36),

              // ===== Social feed =====
              _SectionRow(
                eyebrow: 'Social',
                title: 'From Our Feed',
                onSeeMore: widget.onGoToNews,
              ),
              const SizedBox(height: 16),
              const _InstagramHandleCard(),
              const SizedBox(height: 12),
              FutureBuilder<List<SocialPost>>(
                future: _social,
                builder: (context, snap) {
                  final posts = (snap.data ?? const <SocialPost>[]).take(2).toList();
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Column(
                    children: posts
                        .map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SocialCard(post: p),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 36),

              // ===== Newsletter =====
              _Newsletter(
                controller: _newsletter,
                subscribed: _subscribed,
                onSubmit: () async {
                  final email = _newsletter.text.trim();
                  if (!email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid email')),
                    );
                    return;
                  }
                  try {
                    await AudienceData.subscribeNewsletter(email);
                    if (!mounted) return;
                    setState(() => _subscribed = true);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not subscribe: $e')),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.charcoal],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + kToolbarHeight + 20, 24, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EST. ${ChoirData.founded}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.accentLight,
                letterSpacing: 2.0,
              )),
          const SizedBox(height: 14),
          Text(ChoirData.name,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.cream,
                fontWeight: FontWeight.w600,
                height: 1.05,
              )),
          const SizedBox(height: 14),
          Container(height: 2, width: 48, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(ChoirData.tagline,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.cream.withValues(alpha: 0.9),
                height: 1.5,
              )),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String eyebrow;
  final String title;
  final VoidCallback? onSeeMore;
  const _SectionRow({required this.eyebrow, required this.title, this.onSeeMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: SectionHeader(eyebrow: eyebrow, title: title)),
        if (onSeeMore != null)
          TextButton(
            onPressed: onSeeMore,
            child: const Text('See all →'),
          ),
      ],
    );
  }
}

class _NextConcertCard extends StatelessWidget {
  final Concert concert;
  const _NextConcertCard({required this.concert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return ElegantCard(
      background: AppColors.offWhite,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConcertDetailScreen(concert: concert),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(months[concert.date.month - 1].toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.accentLight,
                      letterSpacing: 1.5,
                    )),
                const SizedBox(height: 2),
                Text(
                  concert.date.day.toString(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w600,
                    height: 1,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (concert.isRehearsal
                            ? AppColors.secondary
                            : AppColors.accentDark)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    concert.isRehearsal ? 'BIG REHEARSAL' : 'CONCERT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: concert.isRehearsal
                          ? AppColors.secondaryDark
                          : AppColors.accentDark,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(concert.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.gray),
                    const SizedBox(width: 4),
                    Expanded(child: Text(concert.location, style: theme.textTheme.bodySmall)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(concert.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinCta extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dark.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1,
                    color: AppColors.dark, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join the Choir',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Auditions year-round — voice all welcome.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.dark.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.dark, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final RepertoireSong song;
  const _SongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PublicSongPlayerScreen(song: song))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title, style: theme.textTheme.titleMedium),
                Text(song.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}

class _SocialCard extends StatelessWidget {
  final SocialPost post;
  const _SocialCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInsta = post.platform == 'Instagram';
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isInsta ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(isInsta ? Icons.camera_alt : Icons.facebook,
                    size: 18, color: isInsta ? AppColors.primary : AppColors.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author, style: theme.textTheme.titleSmall),
                    Text('${post.platform} · ${post.postedAgo}', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
        ],
      ),
    );
  }
}

class _Newsletter extends StatelessWidget {
  final TextEditingController controller;
  final bool subscribed;
  final VoidCallback onSubmit;
  const _Newsletter({
    required this.controller,
    required this.subscribed,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: subscribed
          ? Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.accentLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You\'re subscribed! Look for the next newsletter in your inbox.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.cream),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Newsletter',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.accentLight,
                      letterSpacing: 1.5,
                    )),
                const SizedBox(height: 6),
                Text('Stay in tune',
                    style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.cream)),
                const SizedBox(height: 8),
                Text(
                  'Get concert announcements, new music releases, and stories from the choir.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.cream.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.dark),
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.dark,
                      ),
                      child: const Text('Subscribe'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Prominent Instagram handle card on the audience home — taps to
/// open @fayhanationalchoir in the Instagram app / browser.
class _InstagramHandleCard extends StatelessWidget {
  const _InstagramHandleCard();

  Future<void> _open() async {
    await launchUrl(
      Uri.parse('https://www.instagram.com/fayhanationalchoir/'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: _open,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF58529),
                  Color(0xFFDD2A7B),
                  Color(0xFF8134AF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const FaIcon(FontAwesomeIcons.instagram,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow us on Instagram',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('@fayhanationalchoir',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new,
              size: 18, color: AppColors.gray),
        ],
      ),
    );
  }
}
