import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/notifications_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/branded_background.dart';
import 'member_home_screen.dart';
import 'song_library_screen.dart';
import 'private_news_screen.dart';
import 'map_screen.dart';
import 'member_more_screen.dart';
import 'notifications_screen.dart';

class MemberShell extends StatefulWidget {
  const MemberShell({super.key});

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _index = 0;
  int _unread = 0;

  final _screens = const <Widget>[
    MemberHomeScreen(),
    SongLibraryScreen(),
    PrivateNewsScreen(),
    MapScreen(),
    MemberMoreScreen(),
  ];

  static const _titles = ['Home', 'Songs', 'News', 'Map', 'More'];

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await NotificationsService.unreadCount();
      if (!mounted) return;
      setState(() => _unread = n);
    } catch (_) {
      // ignore — bell just won't show a badge
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    await NotificationsService.markSeen();
    await _refreshUnread();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be returned to the public app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (_, __) {
        final m = AppState.instance.currentMember;
        if (m == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Row(
              children: [
                Avatar(name: m.name, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_titles[_index],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text(
                        '${m.voiceSection} · ${m.branch}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.gray, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: _openNotifications,
                  ),
                  if (_unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.cream, width: 1.5),
                        ),
                        child: Text(
                          _unread > 9 ? '9+' : '$_unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout),
                onPressed: () => _confirmLogout(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: BrandedBackground(
            child: IndexedStack(index: _index, children: _screens),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) {
              setState(() => _index = i);
              _refreshUnread();
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music_outlined),
                activeIcon: Icon(Icons.library_music),
                label: 'Songs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.feed_outlined),
                activeIcon: Icon(Icons.feed),
                label: 'News',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_outlined),
                activeIcon: Icon(Icons.more_horiz),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}
