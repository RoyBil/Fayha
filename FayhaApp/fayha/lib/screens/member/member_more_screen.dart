import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/choir_data.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';
import '../member_signin_screen.dart';
import 'member_profile_screen.dart';
import 'messages_screen.dart';
import 'polls_screen.dart';
import 'attendance_history_screen.dart';
import 'attendance_screen.dart';
import 'testimonials_member_screen.dart';
import 'gallery_screen.dart';
import 'admin_panel_screen.dart';
import 'live_locations_map_screen.dart';
import 'members_directory_screen.dart';

class MemberMoreScreen extends StatelessWidget {
  const MemberMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final m = AppState.instance.currentMember!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const SectionHeader(eyebrow: 'Account', title: 'Member Settings'),
            const SizedBox(height: 14),
            ElegantCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Tile(
                    icon: Icons.person_outline,
                    title: 'My Profile',
                    subtitle: '${m.voiceSection} · ${m.branch}',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MemberProfileScreen())),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.checklist_rtl,
                    title: 'Attendance',
                    subtitle: m.isAdmin
                        ? 'Record the branch\'s rehearsal attendance'
                        : 'Your rehearsal and concert record',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => m.isAdmin
                            ? const AttendanceScreen()
                            : const AttendanceHistoryScreen(),
                      ),
                    ),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.groups_outlined,
                    title: 'Members Directory',
                    subtitle: 'Everyone in the choir, by branch',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MembersDirectoryScreen()),
                    ),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.forum_outlined,
                    title: m.isMaestro ? 'Messages' : 'Message Maestro',
                    subtitle: m.isMaestro
                        ? 'Inbox of every member'
                        : 'Direct chat with Maestro Barkev',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MessagesScreen())),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.poll_outlined,
                    title: 'Polls',
                    subtitle: 'Vote on choir decisions',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PollsScreen())),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.format_quote,
                    title: 'Testimonials',
                    subtitle: 'Share your story · view others',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TestimonialsMemberScreen())),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.photo_library_outlined,
                    title: 'Gallery',
                    subtitle: 'Moments from the choir',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GalleryScreen())),
                  ),
                  if (m.isAdmin || m.isContentEditor) ...[
                    const _Sep(),
                    _Tile(
                      icon: m.isContentEditor && !m.isAdmin
                          ? Icons.edit_note_outlined
                          : Icons.admin_panel_settings_outlined,
                      title: m.isContentEditor && !m.isAdmin
                          ? 'Editor Panel'
                          : 'Admin Panel',
                      subtitle: m.isContentEditor && !m.isAdmin
                          ? 'Post news, events and announcements'
                          : 'Approvals · members · attendance stats',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                    ),
                  ],
                  const _Sep(),
                  _Tile(
                    icon: Icons.share_location,
                    title: 'Live Locations',
                    subtitle: 'See members sharing right now',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LiveLocationsMapScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(eyebrow: 'Reach', title: 'Choir Contact'),
            const SizedBox(height: 14),
            ElegantCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Tile(
                    icon: Icons.mail_outline,
                    title: ChoirData.managerEmail,
                    subtitle: 'Manager',
                    onTap: () => launchUrl(Uri.parse('mailto:${ChoirData.managerEmail}'),
                        mode: LaunchMode.externalApplication),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.phone_outlined,
                    title: ChoirData.phones.first,
                    subtitle: 'Call manager',
                    onTap: () => launchUrl(Uri.parse('tel:${ChoirData.phones.first}'),
                        mode: LaunchMode.externalApplication),
                  ),
                  const _Sep(),
                  _Tile(
                    icon: Icons.language,
                    title: 'Website',
                    subtitle: ChoirData.websiteUrl,
                    onTap: () => launchUrl(Uri.parse(ChoirData.websiteUrl),
                        mode: LaunchMode.externalApplication),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () {
                AppState.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MemberSignInScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Fayha National Choir Members App',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 56);
}
