import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';

class JoinRequest {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String village;
  final String? branch;
  final String? notes;
  final String status; // new | contacted | dismissed
  final DateTime createdAt;
  final String? handledById;
  final DateTime? handledAt;
  const JoinRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.village,
    this.branch,
    this.notes,
    required this.status,
    required this.createdAt,
    this.handledById,
    this.handledAt,
  });

  factory JoinRequest.fromMap(Map<String, dynamic> r) => JoinRequest(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        email: (r['email'] as String?) ?? '',
        phone: (r['phone'] as String?) ?? '',
        village: (r['village'] as String?) ?? '',
        branch: r['branch'] as String?,
        notes: r['notes'] as String?,
        status: (r['status'] as String?) ?? 'new',
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        handledById: r['handled_by'] as String?,
        handledAt: r['handled_at'] != null
            ? DateTime.parse(r['handled_at'] as String).toLocal()
            : null,
      );
}

class JoinRequestsService {
  static final _c = Supabase.instance.client;

  /// Public — anyone (no auth needed) can submit a request.
  static Future<void> submit({
    required String name,
    required String email,
    required String phone,
    required String village,
    required String branch,
    String? notes,
  }) async {
    await _c.from('join_requests').insert({
      'name': name,
      'email': email,
      'phone': phone,
      'village': village,
      'branch': branch,
      'notes': notes,
    });
  }

  /// Admin-only: all requests, newest first.
  static Future<List<JoinRequest>> fetchAll() async {
    final rows = await _c
        .from('join_requests')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => JoinRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> setStatus(String id, String status) async {
    final me = AppState.instance.currentMember;
    await _c.from('join_requests').update({
      'status': status,
      'handled_by': me?.id,
      'handled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> remove(String id) async {
    await _c.from('join_requests').delete().eq('id', id);
  }
}
