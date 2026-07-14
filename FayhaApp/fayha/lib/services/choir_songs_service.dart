import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Voice sections used in the choir, in the order they appear in the
/// mixer and compose-song screens.
const choirVoiceParts = <String>[
  'Solo',
  'Soprano',
  'Mezzo Soprano',
  'Alto',
  'Contrary Alto',
  'Tenor I',
  'Tenor II',
  'Baritone',
  'Bass',
];

/// Matching SQL column suffix for each part (`${key}_url`).
const choirVoicePartKeys = <String>[
  'solo',
  'soprano',
  'mezzo_soprano',
  'alto',
  'contrary_alto',
  'tenor_i',
  'tenor_ii',
  'baritone',
  'bass',
];

class ChoirSong {
  final String id;
  final String title;
  final String? subtitle;
  final String? composers;
  final String? description;
  final String? lyrics;
  final String? youtubeUrl;

  /// Audio URLs keyed by [choirVoicePartKeys] entry. Null = part not
  /// uploaded for this song.
  final Map<String, String?> partUrls;

  final DateTime createdAt;

  const ChoirSong({
    required this.id,
    required this.title,
    this.subtitle,
    this.composers,
    this.description,
    this.lyrics,
    this.youtubeUrl,
    required this.partUrls,
    required this.createdAt,
  });

  /// Audio URL for one of the voice sections, indexed in the order
  /// of [choirVoiceParts] / [choirVoicePartKeys]. Returns null if the
  /// admin did not upload that part for this song.
  String? urlForPart(int i) {
    if (i < 0 || i >= choirVoicePartKeys.length) return null;
    return partUrls[choirVoicePartKeys[i]];
  }

  bool hasPart(int i) {
    final u = urlForPart(i);
    return u != null && u.isNotEmpty;
  }

  factory ChoirSong.fromMap(Map<String, dynamic> r) {
    final urls = <String, String?>{};
    for (final key in choirVoicePartKeys) {
      final col = '${key}_url';
      urls[key] = r[col] as String?;
    }
    return ChoirSong(
      id: r['id'] as String,
      title: r['title'] as String,
      subtitle: r['subtitle'] as String?,
      composers: r['composers'] as String?,
      description: r['description'] as String?,
      lyrics: r['lyrics'] as String?,
      youtubeUrl: r['youtube_url'] as String?,
      partUrls: urls,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }
}

class ChoirSongsService {
  static final _c = Supabase.instance.client;

  static List<ChoirSong>? _cache;
  static DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 5);

  static Future<List<ChoirSong>> fetchAll({bool forceRefresh = false}) async {
    final cached = _cache;
    final at = _cacheAt;
    if (!forceRefresh &&
        cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheTtl) {
      return cached;
    }
    final rows = await _c
        .from('choir_songs')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    final result = (rows as List)
        .map((r) => ChoirSong.fromMap(r as Map<String, dynamic>))
        .toList();
    _cache = result;
    _cacheAt = DateTime.now();
    return result;
  }

  static void invalidateCache() {
    _cache = null;
    _cacheAt = null;
  }

  /// Uploads a single voice-part audio file and returns its public URL.
  /// Path: {songId}/{partKey}.{ext}
  static Future<String> uploadPart({
    required String songId,
    required String partKey,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'm4a' : fileExtension;
    final path = '$songId/$partKey.$ext';
    final contentType = switch (ext) {
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'audio/$ext',
    };
    await _c.storage
        .from('choir_song_parts')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return _c.storage.from('choir_song_parts').getPublicUrl(path);
  }

  /// Inserts a new choir song. Pass any number of voice-part URLs;
  /// missing parts are stored as NULL (the song just won't have audio
  /// for those sections).
  static Future<void> create({
    required String id,
    required String title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
    required Map<String, String?> partUrls,
  }) async {
    final me = _c.auth.currentUser?.id;
    final row = <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'composers': composers,
      'description': description,
      'lyrics': lyrics,
      'youtube_url': youtubeUrl,
      'created_by': me,
      'sort_order': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    for (final key in choirVoicePartKeys) {
      row['${key}_url'] = partUrls[key];
    }
    await _c.from('choir_songs').insert(row);
  }

  /// Patches an existing choir song. Pass only the fields / parts you
  /// want to change. Pass an entry in [partUrls] for any voice section
  /// you want to replace (null = clear that part).
  static Future<void> update({
    required String id,
    String? title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
    Map<String, String?>? partUrls,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (subtitle != null) patch['subtitle'] = subtitle;
    if (composers != null) patch['composers'] = composers;
    if (description != null) patch['description'] = description;
    if (lyrics != null) patch['lyrics'] = lyrics;
    if (youtubeUrl != null) patch['youtube_url'] = youtubeUrl;
    if (partUrls != null) {
      for (final e in partUrls.entries) {
        patch['${e.key}_url'] = e.value;
      }
    }
    if (patch.isEmpty) return;
    await _c.from('choir_songs').update(patch).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _c.from('choir_songs').delete().eq('id', id);
  }
}
