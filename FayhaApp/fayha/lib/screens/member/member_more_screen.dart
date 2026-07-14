import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/choir_data.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_list_tile.dart';
import '../../widgets/elegant_card.dart';
import '../member_signin_screen.dart';
import 'member_profile_screen.dart';
import 'messages_screen.dart';
import 'polls_screen.dart';
import 'attendance_history_screen.dart';
import 'attendance_screen.dart';
import 'testimonials_member_screen.dart';
import 'gallery_screen.dart';
import 'qr_check_in_screen.dart';
import 'admin_panel_screen.dart';
import 'bus_routes_screen.dart';
import 'live_locations_map_screen.dart';
import 'members_directory_screen.dart';
import 'trip_groups_screen.dart';

class MemberMoreScreen extends StatelessWidget {
  const MemberMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final m = AppState.instance.currentMember!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xl,
            AppSpacing.page,
            AppSpacing.xxxl,
          ),
          children: [
            // ── Account ────────────────────────────────────────────────────
            _GroupLabel('Account'),
            _TileGroup([
              AppListTile(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: '${m.voiceSection} · ${m.branch}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MemberProfileScreen(),
                  ),
                ),
              ),
              AppListTile(
                icon: Icons.checklist_rtl,
                iconColor: AppColors.secondary,
                iconBackground: AppColors.secondary.withValues(alpha: 0.08),
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
              if (!m.isAdmin)
                AppListTile(
                  icon: Icons.qr_code_scanner,
                  iconColor: AppColors.accentDark,
                  iconBackground: AppColors.accent.withValues(alpha: 0.1),
                  title: 'Scan to Check In',
                  subtitle: 'Scan the QR your admin shows to mark attendance',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrCheckInScreen()),
                  ),
                ),
            ]),

            const SizedBox(height: AppSpacing.lg),

            // ── Choir ──────────────────────────────────────────────────────
            _GroupLabel('Choir'),
            _TileGroup([
              AppListTile(
                icon: Icons.groups_outlined,
                title: 'Members Directory',
                subtitle: 'Everyone in the choir, by branch',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MembersDirectoryScreen(),
                  ),
                ),
              ),
              AppListTile(
                icon: Icons.forum_outlined,
                iconColor: AppColors.accentDark,
                iconBackground: AppColors.accent.withValues(alpha: 0.1),
                title: 'Messages',
                subtitle: m.isMaestro
                    ? 'Inbox of every member'
                    : 'Chat with admins and Maestro',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()),
                ),
              ),
              AppListTile(
                icon: Icons.poll_outlined,
                title: 'Polls',
                subtitle: 'Vote on choir decisions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PollsScreen()),
                ),
              ),
              AppListTile(
                icon: Icons.format_quote,
                title: 'Testimonials',
                subtitle: 'View members\' stories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TestimonialsMemberScreen(),
                  ),
                ),
              ),
              AppListTile(
                icon: Icons.photo_library_outlined,
                iconColor: AppColors.secondary,
                iconBackground: AppColors.secondary.withValues(alpha: 0.08),
                title: 'Gallery',
                subtitle: 'Moments from the choir',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),

            // ── Tools ──────────────────────────────────────────────────────
            _GroupLabel('Tools'),
            _TileGroup([
              AppListTile(
                icon: Icons.share_location,
                title: 'Live Locations',
                subtitle: 'See members sharing right now',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LiveLocationsMapScreen(),
                  ),
                ),
              ),
              AppListTile(
                icon: Icons.directions_bus_outlined,
                iconColor: AppColors.secondary,
                iconBackground: AppColors.secondary.withValues(alpha: 0.08),
                title: 'Bus Routes',
                subtitle: m.isAdmin || m.isMaestro
                    ? 'Manage routes · drive trips · live tracking'
                    : 'See live bus · request pickup',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusRoutesScreen()),
                ),
              ),
              AppListTile(
                icon: Icons.flight_takeoff_outlined,
                iconColor: AppColors.accentDark,
                iconBackground: AppColors.accent.withValues(alpha: 0.1),
                title: 'Trip Groups',
                subtitle: m.isAdmin
                    ? 'Manage trip groups · assign members · share info'
                    : 'View your trip details and upload documents',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TripGroupsScreen()),
                ),
              ),
            ]),

            // ── Admin (role-gated) ─────────────────────────────────────────
            if (m.isAdmin || m.isContentEditor) ...[
              const SizedBox(height: AppSpacing.lg),
              _GroupLabel('Admin'),
              _TileGroup([
                AppListTile(
                  icon: m.isContentEditor && !m.isAdmin
                      ? Icons.edit_note_outlined
                      : Icons.admin_panel_settings_outlined,
                  iconColor: AppColors.accentDark,
                  iconBackground: AppColors.accent.withValues(alpha: 0.1),
                  title: m.isContentEditor && !m.isAdmin
                      ? 'Editor Panel'
                      : 'Admin Panel',
                  subtitle: m.isContentEditor && !m.isAdmin
                      ? 'Post news, events and announcements'
                      : 'Approvals · members · attendance stats',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                  ),
                ),
              ]),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── Contact ────────────────────────────────────────────────────
            _GroupLabel('Contact'),
            _TileGroup([
              AppListTile(
                icon: Icons.mail_outline,
                title: ChoirData.managerEmail,
                subtitle: 'Manager',
                onTap: () => launchUrl(
                  Uri.parse('mailto:${ChoirData.managerEmail}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              AppListTile(
                icon: Icons.phone_outlined,
                title: ChoirData.phones.first,
                subtitle: 'Call manager',
                onTap: () => launchUrl(
                  Uri.parse('tel:${ChoirData.phones.first}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              AppListTile(
                icon: Icons.language,
                title: 'Website',
                subtitle: ChoirData.websiteUrl,
                onTap: () => launchUrl(
                  Uri.parse(ChoirData.websiteUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),

            // ── Sign out ───────────────────────────────────────────────────
            _GroupLabel('Session'),
            _TileGroup([
              AppListTile(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'You will need to sign in again',
                destructive: true,
                onTap: () {
                  AuthService.signOutFast();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MemberSignInScreen(),
                    ),
                    (_) => false,
                  );
                },
              ),
            ]),

            const SizedBox(height: AppSpacing.xl),
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

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.lightGray,
        ),
      ),
    );
  }
}

class _TileGroup extends StatelessWidget {
  final List<Widget> children;
  const _TileGroup(this.children);

  @override
  Widget build(BuildContext context) {
    final visible = children.whereType<Widget>().toList();
    return ElegantCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            visible[i],
            if (i < visible.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}
