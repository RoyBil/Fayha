import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class ChoirMessage {
  final String id;
  final String title;
  final String body;
  final String audience;
  final String? branch;
  final String? voiceSection;
  final String? senderName;
  final DateTime createdAt;

  const ChoirMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.branch,
    this.voiceSection,
    this.senderName,
    required this.createdAt,
  });

  factory ChoirMessage.fromMap(Map<String, dynamic> r) => ChoirMessage(
        id: r['id'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        audience: r['audience'] as String,
        branch: r['branch'] as String?,
        voiceSection: r['voice_section'] as String?,
        senderName: r['sender_name'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );

  String get audienceLabel {
    switch (audience) {
      case 'everyone':
        return 'Everyone';
      case 'audience':
        return 'Audience';
      case 'members':
        return 'All members';
      case 'admins':
        return 'Admins';
      case 'superAdmins':
        return 'Super admins';
      case 'branch':
        return '${branch ?? ''} branch';
      case 'voice':
        return '${voiceSection ?? ''} voice section';
      default:
        return audience;
    }
  }
}

class MessagesService {
  static final _c = Supabase.instance.client;

  /// Audience options an admin can pick from.
  static const audiences = [
    ('everyone', 'Everyone (members + audience)'),
    ('audience', 'Audience (public app)'),
    ('members', 'All choir members'),
    ('branch', 'A specific branch'),
    ('voice', 'A specific voice section'),
    ('admins', 'Admins only'),
    ('superAdmins', 'Super admins only'),
  ];

  static Future<void> send({
    required String title,
    required String body,
    required String audience,
    String? branch,
    String? voiceSection,
  }) async {
    final me = AppState.instance.currentMember;
    await _c.from('messages').insert({
      'title': title,
      'body': body,
      'audience': audience,
      if (audience == 'branch') 'branch': branch,
      if (audience == 'voice') 'voice_section': voiceSection,
      'sender_id': me?.id,
      'sender_name': me?.name,
    });
  }

  /// RLS automatically filters to messages the current user may see.
  static Future<List<ChoirMessage>> fetch() async {
    final rows = await _c
        .from('messages')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => ChoirMessage.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> delete(String id) async {
    await _c.from('messages').delete().eq('id', id);
  }
}
