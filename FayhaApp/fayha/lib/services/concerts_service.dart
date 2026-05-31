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

  static Concert _fromRow(dynamic row) {
    return Concert(
      title: row['title'] as String,
      location: row['location'] as String,
      date: DateTime.parse(row['starts_at'] as String).toLocal(),
      description: (row['description'] as String?) ?? '',
      kind: (row['kind'] as String?) ?? 'concert',
    );
  }
}
