import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/mock_data.dart';
import '../../services/social_posts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';

/// Editor / superAdmin: see every post the sync function pulled from
/// Instagram + Facebook and mark which ones surface in the audience
/// app.
class ManageSocialPostsScreen extends StatefulWidget {
  const ManageSocialPostsScreen({super.key});

  @override
  State<ManageSocialPostsScreen> createState() =>
      _ManageSocialPostsScreenState();
}

class _ManageSocialPostsScreenState extends State<ManageSocialPostsScreen> {
  List<SocialPost>? _posts;
  bool _loading = true;
  String? _busyId;
  String _filter = 'all'; // all | important | normal | hidden

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await SocialPostsService.listAll();
      if (!mounted) return;
      setState(() {
        _posts = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = const [];
        _loading = false;
      });
    }
  }

  Future<void> _setImportance(SocialPost p, SocialImportance i) async {
    if (p.id == null || _busyId != null || p.importance == i) return;
    setState(() => _busyId = p.id);
    try {
      await SocialPostsService.setImportance(p.id!, i);
      if (!mounted) return;
      setState(() {
        _posts = _posts
            ?.map((x) => x.id == p.id
                ? SocialPost(
                    id: x.id,
                    platform: x.platform,
                    author: x.author,
                    body: x.body,
                    postedAgo: x.postedAgo,
                    permalink: x.permalink,
                    mediaUrl: x.mediaUrl,
                    mediaType: x.mediaType,
                    importance: i,
                  )
                : x)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmDelete(SocialPost p) async {
    if (p.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
            'It will be re-fetched on the next sync unless the source post is also removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SocialPostsService.delete(p.id!);
      if (!mounted) return;
      setState(() => _posts = _posts?.where((x) => x.id != p.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _openSource(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final all = _posts ?? const <SocialPost>[];
    final filtered = switch (_filter) {
      'important' =>
        all.where((p) => p.importance == SocialImportance.important).toList(),
      'normal' =>
        all.where((p) => p.importance == SocialImportance.normal).toList(),
      'hidden' =>
        all.where((p) => p.importance == SocialImportance.hidden).toList(),
      _ => all,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social posts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  const SectionHeader(
                    eyebrow: 'Curate',
                    title: 'Instagram + Facebook feed',
                    subtitle:
                        'Posts come from the sync function. Only "Important" ones show up in the audience app.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [
                      _filterChip('all', 'All (${all.length})'),
                      _filterChip(
                          'important',
                          'Important (${all.where((p) => p.importance == SocialImportance.important).length})'),
                      _filterChip(
                          'normal',
                          'Normal (${all.where((p) => p.importance == SocialImportance.normal).length})'),
                      _filterChip(
                          'hidden',
                          'Hidden (${all.where((p) => p.importance == SocialImportance.hidden).length})'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          all.isEmpty
                              ? 'No posts synced yet. Run the sync_social edge function or check its secrets.'
                              : 'No posts match this filter.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ...filtered.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _postCard(p),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _filterChip(String key, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == key,
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _postCard(SocialPost p) {
    final isInsta = p.platform.toLowerCase().contains('inst');
    final tone = isInsta ? AppColors.accentDark : AppColors.primaryDark;
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isInsta ? Icons.camera_alt_outlined : Icons.facebook,
                  size: 18, color: tone),
              const SizedBox(width: 6),
              Text(p.platform.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tone,
                        letterSpacing: 0.8,
                      )),
              const Spacer(),
              Text(p.postedAgo,
                  style: Theme.of(context).textTheme.labelSmall),
              IconButton(
                tooltip: 'Open original',
                icon: const Icon(Icons.open_in_new, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: p.permalink == null
                    ? null
                    : () => _openSource(p.permalink),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(p),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(p.author,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          if ((p.mediaUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                p.mediaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 180,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (p.body.isNotEmpty)
            Text(p.body,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              _importanceChip(p, 'Important', Icons.star_rounded,
                  SocialImportance.important, AppColors.accentDark),
              _importanceChip(p, 'Normal', Icons.check_circle_outline,
                  SocialImportance.normal, AppColors.secondaryDark),
              _importanceChip(p, 'Hidden', Icons.visibility_off_outlined,
                  SocialImportance.hidden, AppColors.gray),
            ],
          ),
        ],
      ),
    );
  }

  Widget _importanceChip(
    SocialPost p,
    String label,
    IconData icon,
    SocialImportance value,
    Color color,
  ) {
    final selected = p.importance == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
      selected: selected,
      onSelected: (_) => _setImportance(p, value),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
