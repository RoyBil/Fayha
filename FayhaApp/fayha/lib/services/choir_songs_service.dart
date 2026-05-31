import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Voice sections used in the choir, in the column order used by
/// [ChoirSong]. Same labels appear on the compose & detail screens.
const choirVoiceParts = <String>[
  'Soprano 1', 'Soprano 2',
  'Alto 1', 'Alto 2',
  'Tenor 1', 'Tenor 2',
  'Bass 1', 'Bass 2',
];

const choirVoicePartKeys = <String>[
  's1', 's2', 'a1', 'a2', 't1', 't2', 'b1', 'b2',
];

class ChoirSong {
  final String id;
  final String title;
  final String? subtitle;
  final String? composers;
  final String? description;
  final String? lyrics;
  final String? youtubeUrl;
  final String soprano1Url;
  final String soprano2Url;
  final String alto1Url;
  final String alto2Url;
  final String tenor1Url;
  final String tenor2Url;
  final String bass1Url;
  final String bass2Url;
  final DateTime createdAt;

  const ChoirSong({
    required this.id,
    required this.title,
    this.subtitle,
    this.composers,
    this.description,
    this.lyrics,
    this.youtubeUrl,
    required this.soprano1Url,
    required this.soprano2Url,
    required this.alto1Url,
    required this.alto2Url,
    required this.tenor1Url,
    required this.tenor2Url,
    required this.bass1Url,
    required this.bass2Url,
    required this.createdAt,
  });

  /// Audio URL for one of the voice sections, indexed in the order of
  /// [choirVoiceParts] / [choirVoicePartKeys].
  String urlForPart(int i) {
    switch (i) {
      case 0: return soprano1Url;
      case 1: return soprano2Url;
      case 2: return alto1Url;
      case 3: return alto2Url;
      case 4: return tenor1Url;
      case 5: return tenor2Url;
      case 6: return bass1Url;
      case 7: return bass2Url;
    }
    throw RangeError('Invalid voice part index $i');
  }

  factory ChoirSong.fromMap(Map<String, dynamic> r) => ChoirSong(
        id: r['id'] as String,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String?,
        composers: r['composers'] as String?,
        description: r['description'] as String?,
        lyrics: r['lyrics'] as String?,
        youtubeUrl: r['youtube_url'] as String?,
        soprano1Url: (r['soprano1_url'] as String?) ?? '',
        soprano2Url: (r['soprano2_url'] as String?) ?? '',
        alto1Url: (r['alto1_url'] as String?) ?? '',
        alto2Url: (r['alto2_url'] as String?) ?? '',
        tenor1Url: (r['tenor1_url'] as String?) ?? '',
        tenor2Url: (r['tenor2_url'] as String?) ?? '',
        bass1Url: (r['bass1_url'] as String?) ?? '',
        bass2Url: (r['bass2_url'] as String?) ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class ChoirSongsService {
  static final _c = Supabase.instance.client;

  static Future<List<ChoirSong>> fetchAll() async {
    final rows = await _c
        .from('choir_songs')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => ChoirSong.fromMap(r as Map<String, dynamic>))
        .toList();
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
    await _c.storage.from('choir_song_parts').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return _c.storage.from('choir_song_parts').getPublicUrl(path);
  }

  /// Inserts a new choir song. All 8 voice-part URLs are required.
  static Future<void> create({
    required String id,
    required String title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
    required String soprano1Url,
    required String soprano2Url,
    required String alto1Url,
    required String alto2Url,
    required String tenor1Url,
    required String tenor2Url,
    required String bass1Url,
    required String bass2Url,
  }) async {
    final me = _c.auth.currentUser?.id;
    await _c.from('choir_songs').insert({
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'composers': composers,
      'description': description,
      'lyrics': lyrics,
      'youtube_url': youtubeUrl,
      'soprano1_url': soprano1Url,
      'soprano2_url': soprano2Url,
      'alto1_url': alto1Url,
      'alto2_url': alto2Url,
      'tenor1_url': tenor1Url,
      'tenor2_url': tenor2Url,
      'bass1_url': bass1Url,
      'bass2_url': bass2Url,
      'created_by': me,
      'sort_order': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  /// Patches an existing choir song. Pass only the fields you want to
  /// change; null values are ignored.
  static Future<void> update({
    required String id,
    String? title,
    String? subtitle,
    String? composers,
    String? description,
    String? lyrics,
    String? youtubeUrl,
    String? soprano1Url,
    String? soprano2Url,
    String? alto1Url,
    String? alto2Url,
    String? tenor1Url,
    String? tenor2Url,
    String? bass1Url,
    String? bass2Url,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (subtitle != null) patch['subtitle'] = subtitle;
    if (composers != null) patch['composers'] = composers;
    if (description != null) patch['description'] = description;
    if (lyrics != null) patch['lyrics'] = lyrics;
    if (youtubeUrl != null) patch['youtube_url'] = youtubeUrl;
    if (soprano1Url != null) patch['soprano1_url'] = soprano1Url;
    if (soprano2Url != null) patch['soprano2_url'] = soprano2Url;
    if (alto1Url != null) patch['alto1_url'] = alto1Url;
    if (alto2Url != null) patch['alto2_url'] = alto2Url;
    if (tenor1Url != null) patch['tenor1_url'] = tenor1Url;
    if (tenor2Url != null) patch['tenor2_url'] = tenor2Url;
    if (bass1Url != null) patch['bass1_url'] = bass1Url;
    if (bass2Url != null) patch['bass2_url'] = bass2Url;
    if (patch.isEmpty) return;
    await _c.from('choir_songs').update(patch).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _c.from('choir_songs').delete().eq('id', id);
  }
}
