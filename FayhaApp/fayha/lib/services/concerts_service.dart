import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/choir_data.dart';

class ConcertsService {
  static final _client = Supabase.instance.client;

  static Future<List<Concert>> fetchUpcoming() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('concerts')
        .select()
        .gte('starts_at', now)
        .order('starts_at', ascending: true);
    return (rows as List).map(_fromRow).toList();
  }

  /// Upcoming + recently-finished events (concerts + big rehearsals)
  /// within [lookBack] days from today, oldest→newest. Used by the
  /// admin Attendance picker so QR sessions can be opened on event days.
  static Future<List<Concert>> fetchRecentAndUpcoming({
    Duration lookBack = const Duration(days: 14),
  }) async {
    final from = DateTime.now()
        .subtract(lookBack)
        .toUtc()
        .toIso8601String();
    final rows = await _client
        .from('concerts')
        .select()
        .gte('starts_at', from)
        .order('starts_at', ascending: true);
    return (rows as List).map(_fromRow).toList();
  }

  static Concert _fromRow(dynamic row) {
    return Concert(
      id: row['id'] as String?,
      title: row['title'] as String,
      location: row['location'] as String,
      date: DateTime.parse(row['starts_at'] as String).toLocal(),
      description: (row['description'] as String?) ?? '',
      kind: (row['kind'] as String?) ?? 'concert',
      posterUrl: row['poster_url'] as String?,
    );
  }
}
