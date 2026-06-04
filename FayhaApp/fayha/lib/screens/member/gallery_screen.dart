import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/gallery_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';
import 'compose_gallery_post_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<GalleryPost>> _future;

  /// IDs of posts the user has selected. Selection mode is active when
  /// [_selectionActive] is true; the set may still be empty.
  final Set<String> _selected = {};
  bool _selectionActive = false;

  bool get _canManage {
    final m = AppState.instance.currentMember;
    return m?.isContentEditor ?? false;
  }

  bool get _selectionMode => _selectionActive || _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = GalleryService.list();
  }

  void _reload() {
    setState(() {
      _future = GalleryService.list();
      _selected.clear();
      _selectionActive = false;
    });
  }

  void _enterSelection() => setState(() => _selectionActive = true);

  void _toggle(GalleryPost p) {
    setState(() {
      _selectionActive = true;
      if (_selected.contains(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected.add(p.id);
      }
    });
  }

  void _exitSelection() => setState(() {
        _selected.clear();
        _selectionActive = false;
      });

  Future<void> _newPost() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ComposeGalleryPostScreen()),
    );
    if (saved == true) _reload();
  }

  void _openViewer(List<GalleryPost> posts, int index) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryViewerScreen(
          posts: posts,
          initialIndex: index,
          canManage: _canManage,
        ),
      ),
    );
    if (changed == true) _reload();
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(n == 1
            ? 'Delete this post?'
            : 'Delete $n posts?'),
        content: const Text(
            'They will be removed from the gallery for everyone.'),
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
    final ids = _selected.toList();
    int failed = 0;
    for (final id in ids) {
      try {
        await GalleryService.deletePost(id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _reload();
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failed item(s) could not be deleted')),
      );
    }
  }

  PreferredSizeWidget _appBar() {
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
        ),
        title: Text('${_selected.length} selected'),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            ),
        ],
      );
    }
    return AppBar(
      title: const Text('Gallery'),
      actions: [
        if (_canManage)
          IconButton(
            tooltip: 'Select posts',
            icon: const Icon(Icons.check_box_outlined),
            onPressed: _enterSelection,
          ),
        if (_canManage)
          IconButton(
            tooltip: 'Add to gallery',
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: _newPost,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: _appBar(),
        body: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<GalleryPost>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = snap.data ?? const <GalleryPost>[];
              if (posts.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    const SectionHeader(
                      eyebrow: 'Gallery',
                      title: 'Moments from the Choir',
                      subtitle:
                          'Posted by editors. Tap to view full screen.',
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        _canManage
                            ? 'Nothing yet — tap + to add the first post.'
                            : 'Nothing here yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                );
              }
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(
                        eyebrow: 'Gallery',
                        title: 'Moments from the Choir',
                        subtitle: _selectionMode
                            ? 'Tap posts to select · tap × to cancel.'
                            : 'Tap to view · long-press (or ☑) to select.',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 6,
                        // Tile = square thumbnail + caption strip below.
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = posts[i];
                          final selected = _selected.contains(p.id);
                          return GestureDetector(
                            onTap: () {
                              if (_selectionMode) {
                                _toggle(p);
                              } else {
                                _openViewer(posts, i);
                              }
                            },
                            onLongPress: () => _toggle(p),
                            child: _GridTile(post: p, selected: selected),
                          );
                        },
                        childCount: posts.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  final GalleryPost post;
  final bool selected;
  const _GridTile({required this.post, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final caption = (post.caption ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: selected
                  ? Border.all(color: AppColors.primary, width: 3)
                  : null,
            ),
            padding: selected ? const EdgeInsets.all(2) : EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 4 : 6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (post.isVideo)
                    Container(color: AppColors.dark)
                  else
                    Hero(
                      tag: 'gallery_${post.id}',
                      child: Image.network(
                        post.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.offWhite,
                          child: const Icon(Icons.broken_image,
                              color: AppColors.gray),
                        ),
                        loadingBuilder: (ctx, child, ev) {
                          if (ev == null) return child;
                          return Container(color: AppColors.offWhite);
                        },
                      ),
                    ),
                  if (post.isVideo)
                    const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          size: 40, color: Colors.white),
                    ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.check,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption.isEmpty ? ' ' : caption,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: caption.isEmpty
                    ? Colors.transparent
                    : AppColors.dark,
                height: 1.2,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class GalleryViewerScreen extends StatefulWidget {
  final List<GalleryPost> posts;
  final int initialIndex;
  final bool canManage;
  const GalleryViewerScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.canManage,
  });

  @override
  State<GalleryViewerScreen> createState() => _GalleryViewerScreenState();
}

class _GalleryViewerScreenState extends State<GalleryViewerScreen> {
  late final PageController _ctrl;
  late int _index;
  // Mutable working list so edit/delete reflects immediately.
  late List<GalleryPost> _posts;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _posts = List.of(widget.posts);
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final p = _posts[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This will remove it from the gallery for everyone.'),
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
      await GalleryService.deletePost(p.id);
      if (!mounted) return;
      _changed = true;
      setState(() {
        _posts.removeAt(_index);
        if (_posts.isEmpty) {
          Navigator.pop(context, true);
          return;
        }
        if (_index >= _posts.length) _index = _posts.length - 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  Future<void> _edit() async {
    final p = _posts[_index];
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ComposeGalleryPostScreen(existing: p)),
    );
    if (saved == true) {
      _changed = true;
      // Re-fetch the list so we show updated caption/media.
      try {
        final fresh = await GalleryService.list();
        if (!mounted) return;
        setState(() {
          _posts = fresh;
          if (_index >= _posts.length) _index = _posts.length - 1;
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_posts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // forward the changed flag back to the grid
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${_posts.length}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: [
            if (widget.canManage) ...[
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            ],
          ],
        ),
        body: PageView.builder(
          controller: _ctrl,
          itemCount: _posts.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final p = _posts[i];
            return _ViewerPage(post: p, isCurrent: i == _index);
          },
        ),
      ),
    );
  }
}

class _ViewerPage extends StatelessWidget {
  final GalleryPost post;
  final bool isCurrent;
  const _ViewerPage({required this.post, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: post.isVideo
              ? _VideoStage(url: post.photoUrl, active: isCurrent)
              : InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'gallery_${post.id}',
                      child: Image.network(
                        post.photoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        if ((post.caption ?? '').isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            color: Colors.black,
            child: Text(
              post.caption!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoStage extends StatefulWidget {
  final String url;
  final bool active;
  const _VideoStage({required this.url, required this.active});

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _ctrl = c;
      await c.initialize();
      if (!mounted) return;
      c.setLooping(true);
      if (widget.active) c.play();
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(covariant _VideoStage old) {
    super.didUpdateWidget(old);
    final c = _ctrl;
    if (c == null || !_ready) return;
    if (widget.active && !c.value.isPlaying) {
      c.play();
    } else if (!widget.active && c.value.isPlaying) {
      c.pause();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
      );
    }
    final c = _ctrl;
    if (!_ready || c == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Icon(Icons.play_circle_fill_rounded,
                size: 80, color: Colors.white70),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.accent,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
