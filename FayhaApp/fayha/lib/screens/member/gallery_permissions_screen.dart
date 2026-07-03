import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class GalleryPermissionsScreen extends StatefulWidget {
  const GalleryPermissionsScreen({super.key});

  @override
  State<GalleryPermissionsScreen> createState() =>
      _GalleryPermissionsScreenState();
}

class _GalleryPermissionsScreenState extends State<GalleryPermissionsScreen> {
  late Future<List<Member>> _membersFuture;
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _membersFuture = AdminService.fetchRoster();
  }

  void _reload() => setState(() => _membersFuture = AdminService.fetchRoster());

  Future<void> _toggle(Member m, bool value) async {
    setState(() => _loading.add(m.id));
    try {
      await AdminService.setGalleryUploadPermission(m.id, value);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading.remove(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery Upload Permissions')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Member>>(
          future: _membersFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final members = (snap.data ?? <Member>[])
                .where((m) => !m.isContentEditor && !m.leftChoir)
                .toList();
            if (members.isEmpty) {
              return const EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No members',
                message: 'Active non-editor members will appear here.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const SectionHeader(
                  eyebrow: 'Gallery',
                  title: 'Upload Permissions',
                  subtitle:
                      'Allow specific members to post photos and videos to the gallery.',
                ),
                const SizedBox(height: 16),
                for (final m in members) ...[
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Avatar(
                        name: m.name,
                        size: 40,
                        photoUrl: m.photoUrl,
                      ),
                      title: Text(m.name, style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        '${m.voiceSection} · ${m.branch}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: _loading.contains(m.id)
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: m.canUploadGallery,
                              activeThumbColor: AppColors.primary,
                              onChanged: (v) => _toggle(m, v),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
