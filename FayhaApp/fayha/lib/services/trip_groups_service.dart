import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// Models
// ============================================================

class TripGroup {
  final String id;
  final String name;
  final String? description;
  final String? destination;
  final DateTime? departureDate;
  final DateTime? returnDate;
  final DateTime createdAt;
  /// Members assigned to this group (populated when fetched with members).
  final List<TripGroupMember> members;

  const TripGroup({
    required this.id,
    required this.name,
    this.description,
    this.destination,
    this.departureDate,
    this.returnDate,
    required this.createdAt,
    this.members = const [],
  });

  factory TripGroup.fromMap(Map<String, dynamic> m,
      {List<TripGroupMember>? members}) {
    return TripGroup(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      description: m['description'] as String?,
      destination: m['destination'] as String?,
      departureDate: m['departure_date'] != null
          ? DateTime.parse(m['departure_date'] as String)
          : null,
      returnDate: m['return_date'] != null
          ? DateTime.parse(m['return_date'] as String)
          : null,
      createdAt: DateTime.parse(m['created_at'] as String),
      members: members ?? const [],
    );
  }
}

class TripGroupMember {
  final String groupId;
  final String memberId;
  final String? memberName;
  final String? memberPhotoUrl;
  final String? voiceSection;
  final String? branch;

  const TripGroupMember({
    required this.groupId,
    required this.memberId,
    this.memberName,
    this.memberPhotoUrl,
    this.voiceSection,
    this.branch,
  });

  factory TripGroupMember.fromMap(Map<String, dynamic> m) {
    final member = m['members'] as Map<String, dynamic>?;
    return TripGroupMember(
      groupId: m['group_id'] as String,
      memberId: m['member_id'] as String,
      memberName: member?['name'] as String?,
      memberPhotoUrl: member?['photo_url'] as String?,
      voiceSection: member?['voice_section'] as String?,
      branch: member?['branch'] as String?,
    );
  }
}

enum TripInfoCategory { announcement, visa, tickets, hotel, schedule, other }

extension TripInfoCategoryX on TripInfoCategory {
  String get label {
    switch (this) {
      case TripInfoCategory.announcement: return 'Announcement';
      case TripInfoCategory.visa:         return 'Visa';
      case TripInfoCategory.tickets:      return 'Tickets';
      case TripInfoCategory.hotel:        return 'Hotel';
      case TripInfoCategory.schedule:     return 'Schedule';
      case TripInfoCategory.other:        return 'Other';
    }
  }

  String get dbValue {
    switch (this) {
      case TripInfoCategory.announcement: return 'announcement';
      case TripInfoCategory.visa:         return 'visa';
      case TripInfoCategory.tickets:      return 'tickets';
      case TripInfoCategory.hotel:        return 'hotel';
      case TripInfoCategory.schedule:     return 'schedule';
      case TripInfoCategory.other:        return 'other';
    }
  }
}

class TripGroupInfo {
  final String id;
  final String groupId;
  final TripInfoCategory category;
  final String title;
  final String? body;
  final String? fileUrl;
  final String? fileName;
  final DateTime createdAt;

  const TripGroupInfo({
    required this.id,
    required this.groupId,
    required this.category,
    required this.title,
    this.body,
    this.fileUrl,
    this.fileName,
    required this.createdAt,
  });

  factory TripGroupInfo.fromMap(Map<String, dynamic> m) {
    return TripGroupInfo(
      id: m['id'] as String,
      groupId: m['group_id'] as String,
      category: _categoryFrom(m['category'] as String?),
      title: (m['title'] as String?) ?? '',
      body: m['body'] as String?,
      fileUrl: m['file_url'] as String?,
      fileName: m['file_name'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  static TripInfoCategory _categoryFrom(String? v) {
    switch (v) {
      case 'visa':         return TripInfoCategory.visa;
      case 'tickets':      return TripInfoCategory.tickets;
      case 'hotel':        return TripInfoCategory.hotel;
      case 'schedule':     return TripInfoCategory.schedule;
      case 'announcement': return TripInfoCategory.announcement;
      default:             return TripInfoCategory.other;
    }
  }
}

enum TripDocumentType { passport, visa, insurance, other }

extension TripDocumentTypeX on TripDocumentType {
  String get label {
    switch (this) {
      case TripDocumentType.passport:   return 'Passport';
      case TripDocumentType.visa:       return 'Visa';
      case TripDocumentType.insurance:  return 'Insurance';
      case TripDocumentType.other:      return 'Other';
    }
  }

  String get dbValue {
    switch (this) {
      case TripDocumentType.passport:  return 'passport';
      case TripDocumentType.visa:      return 'visa';
      case TripDocumentType.insurance: return 'insurance';
      case TripDocumentType.other:     return 'other';
    }
  }
}

class TripGroupDocument {
  final String id;
  final String groupId;
  final String memberId;
  final String? memberName;
  final TripDocumentType documentType;
  final String fileName;
  final String fileUrl;
  final DateTime uploadedAt;

  const TripGroupDocument({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.memberName,
    required this.documentType,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory TripGroupDocument.fromMap(Map<String, dynamic> m) {
    final member = m['members'] as Map<String, dynamic>?;
    return TripGroupDocument(
      id: m['id'] as String,
      groupId: m['group_id'] as String,
      memberId: m['member_id'] as String,
      memberName: member?['name'] as String?,
      documentType: _docTypeFrom(m['document_type'] as String?),
      fileName: (m['file_name'] as String?) ?? '',
      fileUrl: (m['file_url'] as String?) ?? '',
      uploadedAt: DateTime.parse(m['uploaded_at'] as String),
    );
  }

  static TripDocumentType _docTypeFrom(String? v) {
    switch (v) {
      case 'passport':  return TripDocumentType.passport;
      case 'visa':      return TripDocumentType.visa;
      case 'insurance': return TripDocumentType.insurance;
      default:          return TripDocumentType.other;
    }
  }
}

// ============================================================
// Service
// ============================================================

class TripGroupsService {
  static final _c = Supabase.instance.client;

  // ---------- Groups ----------

  /// All groups (admin view).
  static Future<List<TripGroup>> fetchAll() async {
    final rows = await _c
        .from('trip_groups')
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((r) => TripGroup.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Groups the current user belongs to (member view).
  static Future<List<TripGroup>> fetchMine() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return const [];
    final memberships = await _c
        .from('trip_group_members')
        .select('group_id')
        .eq('member_id', me);
    final ids = (memberships as List)
        .map((r) => (r as Map<String, dynamic>)['group_id'] as String)
        .toList();
    if (ids.isEmpty) return const [];
    final rows = await _c
        .from('trip_groups')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => TripGroup.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<TripGroup> create({
    required String name,
    String? description,
    String? destination,
    DateTime? departureDate,
    DateTime? returnDate,
  }) async {
    final me = _c.auth.currentUser?.id;
    final row = await _c.from('trip_groups').insert({
      'name': name,
      if (description != null) 'description': description,
      if (destination != null) 'destination': destination,
      if (departureDate != null)
        'departure_date': departureDate.toIso8601String().split('T').first,
      if (returnDate != null)
        'return_date': returnDate.toIso8601String().split('T').first,
      if (me != null) 'created_by': me,
    }).select().single();
    return TripGroup.fromMap(row);
  }

  static Future<void> update(
    String groupId, {
    String? name,
    String? description,
    String? destination,
    DateTime? departureDate,
    DateTime? returnDate,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (destination != null) 'destination': destination,
      if (departureDate != null)
        'departure_date': departureDate.toIso8601String().split('T').first,
      if (returnDate != null)
        'return_date': returnDate.toIso8601String().split('T').first,
    };
    if (updates.isEmpty) return;
    await _c.from('trip_groups').update(updates).eq('id', groupId);
  }

  static Future<void> delete(String groupId) async {
    await _c.from('trip_groups').delete().eq('id', groupId);
  }

  // ---------- Members ----------

  static Future<List<TripGroupMember>> fetchMembers(String groupId) async {
    final rows = await _c
        .from('trip_group_members')
        .select('group_id, member_id, members!trip_group_members_member_id_fkey(name, photo_url, voice_section, branch)')
        .eq('group_id', groupId);
    return (rows as List)
        .map((r) => TripGroupMember.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addMember(String groupId, String memberId) async {
    await _c.from('trip_group_members').upsert({
      'group_id': groupId,
      'member_id': memberId,
    });
  }

  /// Insert an in-app notification telling a member they were added to a trip.
  static Future<void> notifyMemberAdded({
    required String memberId,
    required String groupId,
    required String groupName,
  }) async {
    await _c.from('member_notifications').insert({
      'member_id': memberId,
      'kind': 'trip_added',
      'title': 'Added to $groupName',
      'body': "You've been added to the $groupName trip group.",
      'source_id': groupId,
    });
  }

  static Future<void> removeMember(String groupId, String memberId) async {
    await _c
        .from('trip_group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('member_id', memberId);
  }

  // ---------- Info ----------

  static Future<List<TripGroupInfo>> fetchInfo(String groupId) async {
    final rows = await _c
        .from('trip_group_info')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => TripGroupInfo.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> postInfo({
    required String groupId,
    required TripInfoCategory category,
    required String title,
    String? body,
    String? fileUrl,
    String? fileName,
  }) async {
    final me = _c.auth.currentUser?.id;
    await _c.from('trip_group_info').insert({
      'group_id': groupId,
      'category': category.dbValue,
      'title': title,
      if (body != null) 'body': body,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileName != null) 'file_name': fileName,
      if (me != null) 'created_by': me,
    });
  }

  static Future<void> deleteInfo(String infoId) async {
    await _c.from('trip_group_info').delete().eq('id', infoId);
  }

  // ---------- Documents ----------

  static Future<List<TripGroupDocument>> fetchDocuments(
      String groupId, String memberId) async {
    final rows = await _c
        .from('trip_group_documents')
        .select()
        .eq('group_id', groupId)
        .eq('member_id', memberId)
        .order('uploaded_at', ascending: false);
    return (rows as List)
        .map((r) => TripGroupDocument.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TripGroupDocument>> fetchAllDocuments(
      String groupId) async {
    final rows = await _c
        .from('trip_group_documents')
        .select('*, members!trip_group_documents_member_id_fkey(name)')
        .eq('group_id', groupId)
        .order('uploaded_at', ascending: false);
    return (rows as List)
        .map((r) => TripGroupDocument.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Upload a file attachment for a trip info post.
  /// Returns (url, name) of the stored file.
  static Future<({String url, String name})> uploadInfoFile({
    required String groupId,
    required Uint8List bytes,
    required String fileName,
    required String fileExtension,
  }) async {
    final path =
        'info/$groupId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _c.storage.from('trip_documents').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    final url = _c.storage.from('trip_documents').getPublicUrl(path);
    return (url: url, name: fileName);
  }

  static Future<TripGroupDocument> uploadDocument({
    required String groupId,
    required String memberId,
    required TripDocumentType documentType,
    required Uint8List bytes,
    required String fileName,
    required String fileExtension,
  }) async {
    final path =
        '$groupId/$memberId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _c.storage.from('trip_documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false),
        );
    final url = _c.storage.from('trip_documents').getPublicUrl(path);
    final row = await _c.from('trip_group_documents').insert({
      'group_id': groupId,
      'member_id': memberId,
      'document_type': documentType.dbValue,
      'file_name': fileName,
      'file_url': url,
    }).select().single();
    return TripGroupDocument.fromMap(row);
  }

  static Future<void> deleteDocument(String documentId, String fileUrl) async {
    // Extract storage path from URL.
    final uri = Uri.parse(fileUrl);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('trip_documents');
    if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
      final storagePath = segments.sublist(bucketIndex + 1).join('/');
      await _c.storage.from('trip_documents').remove([storagePath]);
    }
    await _c.from('trip_group_documents').delete().eq('id', documentId);
  }
}
