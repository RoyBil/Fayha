import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'push_notification_service.dart';

class DmMessage {
  final String id;
  final String? body;
  final bool fromMaestro;
  final DateTime createdAt;
  final String? audioUrl;
  final int? audioDurationMs;
  const DmMessage({
    required this.id,
    required this.body,
    required this.fromMaestro,
    required this.createdAt,
    this.audioUrl,
    this.audioDurationMs,
  });

  bool get hasAudio => audioUrl != null;
}

class DmThread {
  final String memberId;
  final String memberName;
  final String adminId;
  final String adminName;
  final String lastBody;
  final DateTime lastAt;

  /// True when the current user is on the member_id side of this thread
  /// (i.e. they initiated the conversation towards another admin).
  final bool iAmOnMemberSide;
  const DmThread({
    required this.memberId,
    required this.memberName,
    required this.adminId,
    required this.adminName,
    required this.lastBody,
    required this.lastAt,
    this.iAmOnMemberSide = false,
  });
}

/// Lightweight record for the "Pick an admin to message" picker.
class AdminContact {
  final String id;
  final String name;
  final String role; // 'admin' | 'superAdmin'
  final String branch;
  final String? photoUrl;
  const AdminContact({
    required this.id,
    required this.name,
    required this.role,
    required this.branch,
    this.photoUrl,
  });
}

class DmService {
  static final _c = Supabase.instance.client;

  /// All messages between a member and a specific admin, oldest first.
  static Future<List<DmMessage>> thread({
    required String memberId,
    required String adminId,
  }) async {
    final rows = await _c
        .from('direct_messages')
        .select()
        .eq('member_id', memberId)
        .eq('admin_id', adminId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map(
          (r) => DmMessage(
            id: r['id'] as String,
            body: r['body'] as String?,
            fromMaestro: r['from_maestro'] as bool,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            audioUrl: r['audio_url'] as String?,
            audioDurationMs: r['audio_duration_ms'] as int?,
          ),
        )
        .toList();
  }

  /// Send a message into a specific (member, admin) thread.
  /// [fromAdmin] is the direction — true when the admin/Maestro is
  /// replying. The SQL keeps the legacy column name `from_maestro`.
  static Future<void> send({
    required String memberId,
    required String adminId,
    String? body,
    required bool fromAdmin,
    String? audioUrl,
    int? audioDurationMs,
  }) async {
    await _c.from('direct_messages').insert({
      'member_id': memberId,
      'admin_id': adminId,
      'body': body,
      'from_maestro': fromAdmin,
      'sender_name': AppState.instance.currentMember?.name,
      'audio_url': audioUrl,
      'audio_duration_ms': audioDurationMs,
    });
    AppState.instance.bumpStats();
    if (fromAdmin) {
      final senderName = AppState.instance.currentMember?.name ?? 'Maestro';
      await PushNotificationService.dispatch(
        title: 'Message from $senderName',
        body: body ?? (audioUrl != null ? '🎤 Voice message' : ''),
        kind: 'dm',
        memberIds: [memberId],
      );
    }
  }

  /// Uploads a recorded audio clip to the `voice_messages` bucket
  /// (path: {auth.uid()}/{epochMs}.m4a) and returns the public URL.
  static Future<String> uploadVoice({
    required Uint8List bytes,
    String fileExtension = 'm4a',
  }) async {
    final uid = _c.auth.currentUser!.id;
    final ms = DateTime.now().millisecondsSinceEpoch;
    final path = '$uid/$ms.$fileExtension';
    final contentType = switch (fileExtension) {
      'm4a' => 'audio/mp4',
      'webm' => 'audio/webm',
      'wav' => 'audio/wav',
      _ => 'audio/$fileExtension',
    };
    await _c.storage
        .from('voice_messages')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    return _c.storage.from('voice_messages').getPublicUrl(path);
  }

  /// Admin inbox — latest message per member/admin who has a thread with
  /// the signed-in admin. RLS scopes rows to threads where admin_id = auth.uid().
  static Future<List<DmThread>> inboxForAdmin(String adminId) async {
    final rows = await _c
        .from('direct_messages')
        .select(
          'member_id,admin_id,body,audio_url,created_at,members!direct_messages_member_id_fkey(name)',
        )
        .eq('admin_id', adminId)
        .order('created_at', ascending: false);
    final seen = <String>{};
    final threads = <DmThread>[];
    for (final r in rows as List) {
      final id = r['member_id'] as String;
      if (seen.contains(id)) continue;
      seen.add(id);
      final member = r['members'] as Map<String, dynamic>?;
      final body =
          (r['body'] as String?) ??
          ((r['audio_url'] as String?) != null ? '🎙 Voice message' : '');
      threads.add(
        DmThread(
          memberId: id,
          memberName: (member?['name'] as String?) ?? 'Member',
          adminId: adminId,
          adminName: 'You',
          lastBody: body,
          lastAt: DateTime.parse(r['created_at'] as String).toLocal(),
          iAmOnMemberSide: false,
        ),
      );
    }
    return threads;
  }

  /// Member view — list of admins the signed-in member has chatted with,
  /// newest reply first. Also used for admins who have initiated threads.
  static Future<List<DmThread>> myAdminThreads(String memberId) async {
    final rows = await _c
        .from('direct_messages')
        .select(
          'member_id,admin_id,body,audio_url,created_at,members!direct_messages_admin_id_fkey(name)',
        )
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    final seen = <String>{};
    final threads = <DmThread>[];
    for (final r in rows as List) {
      final aid = r['admin_id'] as String;
      if (seen.contains(aid)) continue;
      seen.add(aid);
      final admin = r['members'] as Map<String, dynamic>?;
      final body =
          (r['body'] as String?) ??
          ((r['audio_url'] as String?) != null ? '🎙 Voice message' : '');
      threads.add(
        DmThread(
          memberId: memberId,
          memberName: AppState.instance.currentMember?.name ?? 'You',
          adminId: aid,
          adminName: (admin?['name'] as String?) ?? 'Admin',
          lastBody: body,
          lastAt: DateTime.parse(r['created_at'] as String).toLocal(),
          iAmOnMemberSide: true,
        ),
      );
    }
    return threads;
  }

  /// Combined inbox + outgoing threads for an admin — shows both
  /// conversations they received and threads they initiated to other admins.
  static Future<List<DmThread>> inboxAndOutboxForAdmin(String adminId) async {
    final results = await Future.wait([
      inboxForAdmin(adminId),
      myAdminThreads(adminId),
    ]);
    final seen = <String>{};
    final merged = <DmThread>[];
    for (final t in [...results[0], ...results[1]]) {
      final key = '${t.memberId}:${t.adminId}';
      if (seen.add(key)) merged.add(t);
    }
    merged.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return merged;
  }

  /// The full list of admins (branch admins + Maestro) available to message,
  /// excluding the current user.
  static Future<List<AdminContact>> listAdmins() async {
    final me = _c.auth.currentUser?.id;
    final rows = await _c
        .from('members')
        .select('id,name,role,branch,photo_url')
        .inFilter('role', ['admin', 'superAdmin'])
        .eq('status', 'active')
        .order('role', ascending: false) // superAdmin first
        .order('name');
    return (rows as List)
        .map(
          (r) => AdminContact(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? 'Admin',
            role: r['role'] as String,
            branch: (r['branch'] as String?) ?? '',
            photoUrl: r['photo_url'] as String?,
          ),
        )
        .where((a) => a.id != me)
        .toList();
  }
}
