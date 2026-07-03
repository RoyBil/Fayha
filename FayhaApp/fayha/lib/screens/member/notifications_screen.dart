import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/notifications_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import '../concert_detail_screen.dart';
import '../news_detail_screen.dart';
import 'gallery_screen.dart';
import 'maestro_dm_screen.dart';
import 'messages_screen.dart';
import 'polls_screen.dart';
import 'testimonials_member_screen.dart';
import 'trip_groups_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<FeedItem>> _feed;
  Set<String> _starred = {};
  Set<String> _forcedUnread = {};
  Set<String> _read = {};
  DateTime? _lastSeen;
  String _filter = 'All';

  static const _filters = [
    'All',
    'Unread',
    'Starred',
    'Messages',
    'Announcements',
    'News',
    'Concerts',
    'Polls',
    'Trips',
    'Gallery',
  ];

  @override
  void initState() {
    super.initState();
    _feed = NotificationsService.feed();
    _loadState();
  }

  Future<void> _loadState() async {
    final s = await NotificationsService.starredIds();
    final u = await NotificationsService.forcedUnreadIds();
    final r = await NotificationsService.readIds();
    final ls = await NotificationsService.lastSeen();
    if (!mounted) return;
    setState(() {
      _starred = s;
      _forcedUnread = u;
      _read = r;
      _lastSeen = ls;
    });
  }

  void _reload() {
    setState(() => _feed = NotificationsService.feed());
    _loadState();
  }

  bool _isUnread(FeedItem i) {
    if (_forcedUnread.contains(i.id)) return true;
    if (_read.contains(i.id)) return false;
    if (_lastSeen == null) return true;
    return i.date.isAfter(_lastSeen!);
  }

  bool _matches(FeedItem i) {
    switch (_filter) {
      case 'Unread':
        return _isUnread(i);
      case 'Starred':
        return _starred.contains(i.id);
      case 'Messages':
        return i.kind == 'message';
      case 'Announcements':
        return i.kind == 'announcement';
      case 'News':
        return i.kind == 'news';
      case 'Concerts':
        return i.kind == 'concert' || i.kind == 'big_rehearsal';
      case 'Polls':
        return i.kind == 'poll';
      case 'Trips':
        return i.kind == 'trip_added' || i.kind == 'trip';
      case 'Gallery':
        return i.kind == 'gallery';
      default:
        return true;
    }
  }

  ({IconData icon, Color color, String label}) _meta(String kind) {
    switch (kind) {
      case 'message':
        return (
          icon: Icons.chat_bubble_outline,
          color: AppColors.primaryLight,
          label: 'Message',
        );
      case 'news':
        return (
          icon: Icons.newspaper,
          color: AppColors.secondary,
          label: 'News',
        );
      case 'concert':
        return (
          icon: Icons.music_note,
          color: AppColors.accentDark,
          label: 'Concert',
        );
      case 'big_rehearsal':
        return (
          icon: Icons.groups,
          color: AppColors.secondaryDark,
          label: 'Big rehearsal',
        );
      case 'poll':
        return (
          icon: Icons.poll_outlined,
          color: AppColors.primary,
          label: 'Poll',
        );
      case 'trip_added':
      case 'trip':
        return (
          icon: Icons.flight_takeoff,
          color: AppColors.accentDark,
          label: 'Trip',
        );
      case 'gallery':
        return (
          icon: Icons.photo_library_outlined,
          color: AppColors.primaryLight,
          label: 'Gallery',
        );
      case 'testimonial_pending':
        return (
          icon: Icons.rate_review_outlined,
          color: AppColors.secondary,
          label: 'Testimonial',
        );
      default:
        return (
          icon: Icons.campaign,
          color: AppColors.primary,
          label: 'Announcement',
        );
    }
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.isNegative) {
      final d = t.difference(DateTime.now());
      if (d.inDays > 0) return 'in ${d.inDays}d';
      return 'soon';
    }
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Future<void> _onTap(FeedItem i) async {
    // Tap = read. Update local + DB state, then route to the right screen.
    await NotificationsService.markItemRead(i.id);
    _read.add(i.id);
    _forcedUnread.remove(i.id);
    if (mounted) setState(() {});
    switch (i.kind) {
      case 'message':
        final memberId = i.extra['member_id'] as String?;
        final me = AppState.instance.currentMember;
        if (me == null) return;
        if (!mounted) return;
        if (me.isMaestro && memberId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaestroDmScreen(
                memberId: memberId,
                adminId: me.id,
                title: (i.extra['sender_name'] as String?) ?? 'Member',
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()),
          );
        }
        break;
      case 'concert':
      case 'big_rehearsal':
        final c = Concert(
          title: (i.extra['concert_title'] as String?) ?? i.title,
          location: (i.extra['location'] as String?) ?? '',
          date: DateTime.parse(i.extra['starts_at'] as String).toLocal(),
          description: (i.extra['description'] as String?) ?? '',
          kind: (i.extra['kind'] as String?) ?? 'concert',
          posterUrl: i.extra['poster_url'] as String?,
        );
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ConcertDetailScreen(concert: c)),
        );
        break;
      case 'news':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(
              title: i.title,
              body: i.body,
              dateLabel: i.extra['date_label'] as String?,
              posterUrl: i.extra['poster_url'] as String?,
              date: i.date,
            ),
          ),
        );
        break;
      case 'poll':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PollsScreen()),
        );
        break;
      case 'trip_added':
      case 'trip':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TripGroupsScreen()),
        );
        break;
      case 'gallery':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GalleryScreen()),
        );
        break;
      case 'testimonial_pending':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TestimonialsMemberScreen()),
        );
        break;
      default:
        // Announcement → show full body in a sheet.
        if (!mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.cream,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (i.extra['sender_name'] != null)
                  Text(
                    'From ${i.extra['sender_name']}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                const SizedBox(height: 4),
                Text(i.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  i.body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ],
            ),
          ),
        );
        break;
    }
    _loadState();
  }

  Future<void> _toggleStar(FeedItem i) async {
    await NotificationsService.toggleStar(i.id);
    final s = await NotificationsService.starredIds();
    if (!mounted) return;
    setState(() => _starred = s);
  }

  Future<void> _markUnread(FeedItem i) async {
    await NotificationsService.markUnread(i.id);
    final u = await NotificationsService.forcedUnreadIds();
    if (!mounted) return;
    setState(() => _forcedUnread = u);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BrandedBackground(
        child: Column(
          children: [
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: _filters
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: FutureBuilder<List<FeedItem>>(
                  future: _feed,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? const <FeedItem>[];
                    final items = all.where(_matches).toList();
                    if (items.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.notifications_none,
                            title: 'Nothing here',
                            message: 'No notifications match this filter.',
                          ),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: items.map((i) {
                        final m = _meta(i.kind);
                        final unread = _isUnread(i);
                        final starred = _starred.contains(i.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ElegantCard(
                            onTap: () => _onTap(i),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Unread dot (left edge).
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(
                                    top: 8,
                                    right: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: unread
                                        ? AppColors.accent
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: m.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(m.icon, size: 18, color: m.color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              i.title,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: unread
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            _ago(i.date),
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        i.body,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.5),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Star toggle.
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 20,
                                  splashRadius: 18,
                                  icon: Icon(
                                    starred ? Icons.star : Icons.star_border,
                                    color: starred
                                        ? AppColors.accentDark
                                        : AppColors.gray,
                                  ),
                                  onPressed: () => _toggleStar(i),
                                ),
                                // Overflow menu (mark unread).
                                PopupMenuButton<String>(
                                  iconSize: 18,
                                  splashRadius: 18,
                                  padding: EdgeInsets.zero,
                                  onSelected: (v) {
                                    if (v == 'unread') _markUnread(i);
                                  },
                                  itemBuilder: (_) => [
                                    if (!unread)
                                      const PopupMenuItem(
                                        value: 'unread',
                                        child: Text('Mark as unread'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
