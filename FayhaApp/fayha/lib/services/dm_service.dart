import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

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
  final String lastBody;
  final DateTime lastAt;
  const DmThread({
    required this.memberId,
    required this.memberName,
    required this.lastBody,
    required this.lastAt,
  });
}

class DmService {
  static final _c = Supabase.instance.client;

  /// All messages of one member's thread, oldest first.
  static Future<List<DmMessage>> thread(String memberId) async {
    final rows = await _c
        .from('direct_messages')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => DmMessage(
              id: r['id'] as String,
              body: r['body'] as String?,
              fromMaestro: r['from_maestro'] as bool,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
              audioUrl: r['audio_url'] as String?,
              audioDurationMs: r['audio_duration_ms'] as int?,
            ))
        .toList();
  }

  static Future<void> send({
    required String memberId,
    String? body,
    required bool fromMaestro,
    String? audioUrl,
    int? audioDurationMs,
  }) async {
    await _c.from('direct_messages').insert({
      'member_id': memberId,
      'body': body,
      'from_maestro': fromMaestro,
      'sender_name': AppState.instance.currentMember?.name,
      'audio_url': audioUrl,
      'audio_duration_ms': audioDurationMs,
    });
    AppState.instance.bumpStats();
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
    await _c.storage.from('voice_messages').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    return _c.storage.from('voice_messages').getPublicUrl(path);
  }

  /// Maestro inbox — latest message per member who has a thread.
  static Future<List<DmThread>> inbox() async {
    final rows = await _c
        .from('direct_messages')
        .select('member_id,body,audio_url,created_at,members(name)')
        .order('created_at', ascending: false);
    final seen = <String>{};
    final threads = <DmThread>[];
    for (final r in rows as List) {
      final id = r['member_id'] as String;
      if (seen.contains(id)) continue;
      seen.add(id);
      final member = r['members'] as Map<String, dynamic>?;
      final body = (r['body'] as String?) ??
          ((r['audio_url'] as String?) != null ? '🎙 Voice message' : '');
      threads.add(DmThread(
        memberId: id,
        memberName: (member?['name'] as String?) ?? 'Member',
        lastBody: body,
        lastAt: DateTime.parse(r['created_at'] as String).toLocal(),
      ));
    }
    return threads;
  }
}
