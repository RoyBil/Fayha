import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import '../../services/trip_groups_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/section_header.dart';

/// Detail view for a single trip group.
/// Members: see their own documents + all trip info posted by admins.
/// Admins: also manage members, post info, and see every member's documents.
class TripGroupDetailScreen extends StatefulWidget {
  final TripGroup group;
  const TripGroupDetailScreen({super.key, required this.group});

  @override
  State<TripGroupDetailScreen> createState() => _TripGroupDetailScreenState();
}

class _TripGroupDetailScreenState extends State<TripGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late TripGroup _group;

  bool get _isAdmin => AppState.instance.isAdmin;
  String get _myId => AppState.instance.currentMember?.id ?? '';

  late Future<List<TripGroupInfo>> _info;
  late Future<List<TripGroupDocument>> _docs;
  late Future<List<TripGroupMember>> _members;
  late Future<Map<String, Set<TripDocumentType>>> _docTypes;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _info = TripGroupsService.fetchInfo(_group.id);
      _docs = _isAdmin
          ? TripGroupsService.fetchAllDocuments(_group.id)
          : TripGroupsService.fetchDocuments(_group.id, _myId);
      _members = TripGroupsService.fetchMembers(_group.id);
      _docTypes = TripGroupsService.fetchDocumentTypes(_group.id);
    });
  }

  Future<void> _editRequiredDocs() async {
    final selected = await showDialog<List<TripDocumentType>>(
      context: context,
      builder: (_) => _RequiredDocsDialog(current: _group.requiredDocTypes),
    );
    if (selected == null) return;
    try {
      await TripGroupsService.update(_group.id, requiredDocTypes: selected);
      setState(() {
        _group = TripGroup(
          id: _group.id,
          name: _group.name,
          description: _group.description,
          destination: _group.destination,
          departureDate: _group.departureDate,
          returnDate: _group.returnDate,
          createdAt: _group.createdAt,
          requiredDocTypes: selected,
          members: _group.members,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: 'Required documents',
              onPressed: _editRequiredDocs,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray,
          indicatorColor: AppColors.accent,
          tabs: [
            const Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info'),
            const Tab(
              icon: Icon(Icons.folder_outlined, size: 18),
              text: 'Documents',
            ),
            Tab(
              icon: const Icon(Icons.people_outline, size: 18),
              text: _isAdmin ? 'Members' : 'Team',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _InfoTab(
            future: _info,
            isAdmin: _isAdmin,
            groupId: _group.id,
            onChanged: _reload,
          ),
          _DocumentsTab(
            future: _docs,
            groupId: _group.id,
            memberId: _myId,
            isAdmin: _isAdmin,
            onChanged: _reload,
          ),
          _MembersTab(
            future: _members,
            docTypesFuture: _docTypes,
            requiredDocTypes: _group.requiredDocTypes,
            groupId: _group.id,
            groupName: _group.name,
            isAdmin: _isAdmin,
            onChanged: _reload,
          ),
        ],
      ),
    );
  }
}

// ── Info tab ──────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final Future<List<TripGroupInfo>> future;
  final bool isAdmin;
  final String groupId;
  final VoidCallback onChanged;

  const _InfoTab({
    required this.future,
    required this.isAdmin,
    required this.groupId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: FutureBuilder<List<TripGroupInfo>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <TripGroupInfo>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FilledButton.icon(
                    onPressed: () => _postInfo(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Post trip information'),
                  ),
                ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No trip information posted yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final cat in TripInfoCategory.values) ...[
                  Builder(
                    builder: (context) {
                      final catItems = items
                          .where((i) => i.category == cat)
                          .toList();
                      if (catItems.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: _CategoryLabel(category: cat),
                          ),
                          ...catItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _InfoCard(
                                item: item,
                                isAdmin: isAdmin,
                                onDelete: () async {
                                  await TripGroupsService.deleteInfo(item.id);
                                  onChanged();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _postInfo(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _InfoFormDialog(),
    );
    if (result == null) return;

    String? fileUrl;
    String? fileName;
    final xFile = result['file'] as XFile?;

    if (xFile != null) {
      try {
        final bytes = Uint8List.fromList(await xFile.readAsBytes());
        final ext = xFile.name.contains('.')
            ? xFile.name.split('.').last
            : 'bin';
        final uploaded = await TripGroupsService.uploadInfoFile(
          groupId: groupId,
          bytes: bytes,
          fileName: xFile.name,
          fileExtension: ext,
        );
        fileUrl = uploaded.url;
        fileName = uploaded.name;
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File upload failed: $e')));
        return;
      }
    }

    if (!context.mounted) return;
    try {
      await TripGroupsService.postInfo(
        groupId: groupId,
        category: result['category'] as TripInfoCategory,
        title: result['title'] as String,
        body: result['body'] as String?,
        fileUrl: fileUrl,
        fileName: fileName,
      );
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post: $e')));
    }
  }
}

class _CategoryLabel extends StatelessWidget {
  final TripInfoCategory category;
  const _CategoryLabel({required this.category});

  static const _icons = {
    TripInfoCategory.announcement: Icons.campaign_outlined,
    TripInfoCategory.visa: Icons.badge_outlined,
    TripInfoCategory.tickets: Icons.airplane_ticket_outlined,
    TripInfoCategory.hotel: Icons.hotel_outlined,
    TripInfoCategory.schedule: Icons.event_note_outlined,
    TripInfoCategory.other: Icons.info_outline,
  };

  static const _colors = {
    TripInfoCategory.announcement: AppColors.accentDark,
    TripInfoCategory.visa: AppColors.secondary,
    TripInfoCategory.tickets: AppColors.primary,
    TripInfoCategory.hotel: Color(0xFF6B5582),
    TripInfoCategory.schedule: Color(0xFF2A7B4F),
    TripInfoCategory.other: AppColors.gray,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[category] ?? AppColors.gray;
    final icon = _icons[category] ?? Icons.info_outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          category.label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final TripGroupInfo item;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _InfoCard({
    required this.item,
    required this.isAdmin,
    required this.onDelete,
  });

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};

  bool get _isImage {
    final name = item.fileName;
    if (name == null) return false;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return _imageExts.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = item.fileUrl != null && _isImage;
    final hasFile = item.fileUrl != null && !_isImage;

    return ElegantCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width image preview
            if (hasImage)
              Image.network(
                item.fileUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: AppColors.offWhite,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.lightGray,
                      size: 32,
                    ),
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + delete
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.gray,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Description
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.body!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ],
                  // Non-image file chip
                  if (hasFile) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse(item.fileUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.fileName ?? 'Open attachment',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.open_in_new,
                              size: 13,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _fmt(item.createdAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Documents tab ─────────────────────────────────────────────────────────────

class _DocumentsTab extends StatefulWidget {
  final Future<List<TripGroupDocument>> future;
  final String groupId;
  final String memberId;
  final bool isAdmin;
  final VoidCallback onChanged;

  const _DocumentsTab({
    required this.future,
    required this.groupId,
    required this.memberId,
    required this.isAdmin,
    required this.onChanged,
  });

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  bool _uploading = false;

  Future<void> _upload() async {
    const typeGroup = XTypeGroup(
      label: 'Travel documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    if (!mounted) return;
    final docType = await showDialog<TripDocumentType>(
      context: context,
      builder: (_) => _DocTypeDialog(),
    );
    if (docType == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final ext = name.contains('.') ? name.split('.').last : 'bin';
      await TripGroupsService.uploadDocument(
        groupId: widget.groupId,
        memberId: widget.memberId,
        documentType: docType,
        bytes: Uint8List.fromList(bytes),
        fileName: name,
        fileExtension: ext,
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(TripGroupDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Delete "${doc.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await TripGroupsService.deleteDocument(doc.id, doc.fileUrl);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onChanged(),
      child: FutureBuilder<List<TripGroupDocument>>(
        future: widget.future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data ?? const <TripGroupDocument>[];

          if (widget.isAdmin) {
            return _AdminDocsView(
              docs: docs,
              onDelete: _delete,
              onUpload: _upload,
              uploading: _uploading,
            );
          }

          // Member view: own documents + upload
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const SectionHeader(
                eyebrow: 'My Documents',
                title: 'Upload Files',
                subtitle:
                    'Upload your passport, visa, insurance and other travel documents.',
              ),
              const SizedBox(height: 16),
              AbsorbPointer(
                absorbing: _uploading,
                child: FilledButton.icon(
                  onPressed: _upload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cream,
                          ),
                        )
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text(_uploading ? 'Uploading…' : 'Upload document'),
                ),
              ),
              const SizedBox(height: 20),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No documents uploaded yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...docs.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DocCard(
                      doc: doc,
                      showMember: false,
                      canDelete: true,
                      onDelete: () => _delete(doc),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Admin view: all members' documents grouped by member name.
class _AdminDocsView extends StatelessWidget {
  final List<TripGroupDocument> docs;
  final Future<void> Function(TripGroupDocument) onDelete;
  final VoidCallback onUpload;
  final bool uploading;

  const _AdminDocsView({
    required this.docs,
    required this.onDelete,
    required this.onUpload,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    // Group by memberId
    final Map<String, List<TripGroupDocument>> byMember = {};
    for (final doc in docs) {
      byMember.putIfAbsent(doc.memberId, () => []).add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SectionHeader(
          eyebrow: 'All Members',
          title: 'Uploaded Documents',
          subtitle: 'Documents submitted by every member in this trip group.',
        ),
        const SizedBox(height: 16),
        AbsorbPointer(
          absorbing: uploading,
          child: FilledButton.icon(
            onPressed: onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cream,
                    ),
                  )
                : const Icon(Icons.upload_file, size: 18),
            label: Text(uploading ? 'Uploading…' : 'Upload document'),
          ),
        ),
        const SizedBox(height: 20),
        if (byMember.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No documents uploaded yet.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final entry in byMember.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  Avatar(
                    name:
                        docs
                            .firstWhere((d) => d.memberId == entry.key)
                            .memberName ??
                        '',
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      docs
                              .firstWhere((d) => d.memberId == entry.key)
                              .memberName ??
                          'Member',
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DocCard(
                  doc: doc,
                  showMember: false,
                  canDelete: true,
                  onDelete: () => onDelete(doc),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  final TripGroupDocument doc;
  final bool showMember;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _DocCard({
    required this.doc,
    required this.showMember,
    required this.canDelete,
    this.onDelete,
  });

  static const _icons = {
    TripDocumentType.passport: Icons.book_outlined,
    TripDocumentType.profilePhoto: Icons.portrait_outlined,
    TripDocumentType.visa: Icons.badge_outlined,
    TripDocumentType.insurance: Icons.health_and_safety_outlined,
    TripDocumentType.other: Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _icons[doc.documentType] ?? Icons.description_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${doc.documentType.label} · ${_fmt(doc.uploadedAt)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.download_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: 'Download',
            onPressed: () => launchUrl(
              Uri.parse(doc.fileUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          if (canDelete && onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.gray,
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Members tab (admin only) ──────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final Future<List<TripGroupMember>> future;
  final Future<Map<String, Set<TripDocumentType>>> docTypesFuture;
  final List<TripDocumentType> requiredDocTypes;
  final String groupId;
  final String groupName;
  final bool isAdmin;
  final VoidCallback onChanged;

  const _MembersTab({
    required this.future,
    required this.docTypesFuture,
    required this.requiredDocTypes,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.onChanged,
  });

  static Color _statusColor(
    Set<TripDocumentType>? docs,
    List<TripDocumentType> required,
  ) {
    if (required.isEmpty) return const Color(0xFF43A047);
    if (docs == null || docs.isEmpty) return const Color(0xFFE53935);
    if (required.every(docs.contains)) return const Color(0xFF43A047);
    return const Color(0xFFFB8C00);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: FutureBuilder<List<TripGroupMember>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snap.data ?? const <TripGroupMember>[];
          return FutureBuilder<Map<String, Set<TripDocumentType>>>(
            future: docTypesFuture,
            builder: (context, docSnap) {
              final docTypes =
                  docSnap.data ?? const <String, Set<TripDocumentType>>{};
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FilledButton.icon(
                        onPressed: () => _pickMembers(context, members),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Add members'),
                      ),
                    ),
                  if (members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          isAdmin
                              ? 'No members in this group yet.'
                              : 'No fellow travelers yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    if (isAdmin && requiredDocTypes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DocStatusLegend(),
                      ),
                    ...members.map((m) {
                      final uploaded = docTypes[m.memberId];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemberTile(
                          member: m,
                          uploaded: uploaded,
                          requiredTypes: requiredDocTypes,
                          statusColor: _statusColor(uploaded, requiredDocTypes),
                          showStatus: requiredDocTypes.isNotEmpty,
                          canRemove: isAdmin,
                          onRemove: isAdmin
                              ? () async {
                                  await TripGroupsService.removeMember(
                                    groupId,
                                    m.memberId,
                                  );
                                  onChanged();
                                }
                              : null,
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickMembers(
    BuildContext context,
    List<TripGroupMember> existing,
  ) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MemberPickerDialog(
        groupId: groupId,
        existingMemberIds: existing.map((m) => m.memberId).toSet(),
      ),
    );
    if (selected == null || selected.isEmpty) return;

    int added = 0;
    String? lastError;
    for (final id in selected) {
      try {
        await TripGroupsService.addMember(groupId, id);
        added++;
        // Notification is best-effort: a failure must not undo the membership.
        try {
          await TripGroupsService.notifyMemberAdded(
            memberId: id,
            groupId: groupId,
            groupName: groupName,
          );
        } catch (_) {}
      } catch (e) {
        lastError = e.toString();
      }
    }

    // Refresh the member list regardless of whether some notifications failed.
    if (added > 0) onChanged();

    if (lastError != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Could not add members: $lastError'
                : '${selected.length - added} member(s) could not be added',
          ),
        ),
      );
    }
  }
}

class _DocStatusLegend extends StatelessWidget {
  const _DocStatusLegend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        _dot(const Color(0xFF43A047)),
        const SizedBox(width: 4),
        Text('All required', style: style),
        const SizedBox(width: 12),
        _dot(const Color(0xFFFB8C00)),
        const SizedBox(width: 4),
        Text('Partial', style: style),
        const SizedBox(width: 12),
        _dot(const Color(0xFFE53935)),
        const SizedBox(width: 4),
        Text('Missing', style: style),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _MemberTile extends StatelessWidget {
  final TripGroupMember member;
  final Set<TripDocumentType>? uploaded;
  final List<TripDocumentType> requiredTypes;
  final Color? statusColor;
  final bool showStatus;
  final bool canRemove;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.member,
    required this.requiredTypes,
    this.uploaded,
    this.statusColor,
    this.showStatus = false,
    this.canRemove = false,
    this.onRemove,
  });

  List<TripDocumentType> get _missing =>
      requiredTypes.where((t) => !(uploaded?.contains(t) ?? false)).toList();

  String? get _missingText {
    final m = _missing;
    if (m.isEmpty) return null;
    if (m.length == 1) return '${m.first.label} still required';
    return '${m.first.label} and ${m.length - 1} others still required';
  }

  void _showDetail(BuildContext context) {
    if (requiredTypes.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final name = member.memberName ?? 'Unknown';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Required documents',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 16),
              ...requiredTypes.map((t) {
                final done = uploaded?.contains(t) ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: done
                            ? const Color(0xFF43A047)
                            : const Color(0xFFE53935),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        done ? 'Uploaded' : 'Missing',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: done
                              ? const Color(0xFF43A047)
                              : const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member.memberName ?? 'Unknown';
    final missingText = _missingText;
    return GestureDetector(
      onTap: requiredTypes.isNotEmpty ? () => _showDetail(context) : null,
      child: ElegantCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Avatar(name: name, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  if (member.voiceSection != null)
                    Text(
                      '${member.voiceSection} · ${member.branch ?? ''}',
                      style: theme.textTheme.labelSmall,
                    ),
                  if (missingText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        missingText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _missing.length == requiredTypes.length
                              ? const Color(0xFFE53935)
                              : const Color(0xFFFB8C00),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showStatus && statusColor != null)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            if (canRemove)
              IconButton(
                icon: const Icon(
                  Icons.person_remove_outlined,
                  size: 18,
                  color: AppColors.gray,
                ),
                tooltip: 'Remove from group',
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Required docs dialog ──────────────────────────────────────────────────────

class _RequiredDocsDialog extends StatefulWidget {
  final List<TripDocumentType> current;
  const _RequiredDocsDialog({required this.current});

  @override
  State<_RequiredDocsDialog> createState() => _RequiredDocsDialogState();
}

class _RequiredDocsDialogState extends State<_RequiredDocsDialog> {
  late final Set<TripDocumentType> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Required documents'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: TripDocumentType.values
            .where((t) => t != TripDocumentType.other)
            .map(
              (t) => CheckboxListTile(
                title: Text(t.label),
                value: _selected.contains(t),
                contentPadding: EdgeInsets.zero,
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _selected.add(t);
                  } else {
                    _selected.remove(t);
                  }
                }),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── Member picker dialog ──────────────────────────────────────────────────────

class _MemberPickerDialog extends StatefulWidget {
  final String groupId;
  final Set<String> existingMemberIds;

  const _MemberPickerDialog({
    required this.groupId,
    required this.existingMemberIds,
  });

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  late Future<List<Member>> _allMembers;
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allMembers = AdminService.fetchRoster();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Members',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_selected.isNotEmpty)
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Member>>(
              future: _allMembers,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? const <Member>[];
                // Exclude already-added members
                final available = all
                    .where((m) => !widget.existingMemberIds.contains(m.id))
                    .toList();
                // Apply search filter
                final filtered = _query.isEmpty
                    ? available
                    : available
                          .where(
                            (m) =>
                                m.name.toLowerCase().contains(_query) ||
                                m.voiceSection.toLowerCase().contains(_query) ||
                                m.branch.toLowerCase().contains(_query),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      available.isEmpty
                          ? 'All choir members are already in this group.'
                          : 'No results for "$_query".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.gray),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    final checked = _selected.contains(m.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(m.id);
                        } else {
                          _selected.remove(m.id);
                        }
                      }),
                      secondary: Avatar(name: m.name, size: 36),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          m.voiceSection,
                          m.branch,
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    _selected.isEmpty ? 'Add' : 'Add ${_selected.length}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _InfoFormDialog extends StatefulWidget {
  const _InfoFormDialog();

  @override
  State<_InfoFormDialog> createState() => _InfoFormDialogState();
}

class _InfoFormDialogState extends State<_InfoFormDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  TripInfoCategory _category = TripInfoCategory.announcement;
  XFile? _file;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'Attachments',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xlsx'],
    );
    final picked = await openFile(acceptedTypeGroups: [typeGroup]);
    if (picked != null) setState(() => _file = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Post Trip Information'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Category'),
              child: DropdownButton<TripInfoCategory>(
                value: _category,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: TripInfoCategory.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            if (_file == null)
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Attach a file'),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _file!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _file = null),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, {
              'category': _category,
              'title': title,
              'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
              'file': _file,
            });
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}

class _DocTypeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Document type'),
      children: TripDocumentType.values
          .map(
            (t) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(t.label),
              ),
            ),
          )
          .toList(),
    );
  }
}
