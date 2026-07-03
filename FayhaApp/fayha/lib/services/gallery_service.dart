import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

enum GalleryMediaType { image, video }

const kGalleryCategories = [
  'Concert',
  'Rehearsal',
  'Tour',
  'Social',
  'Behind the Scenes',
  'Other',
];

class GalleryPost {
  final String id;
  final String photoUrl;
  final String? caption;
  final GalleryMediaType mediaType;
  final DateTime createdAt;
  final String? category;
  final bool editorsChoice;

  GalleryPost({
    required this.id,
    required this.photoUrl,
    this.caption,
    required this.mediaType,
    required this.createdAt,
    this.category,
    this.editorsChoice = false,
  });

  factory GalleryPost.fromMap(Map<String, dynamic> m) => GalleryPost(
    id: m['id'] as String,
    photoUrl: m['photo_url'] as String,
    caption: m['caption'] as String?,
    mediaType: (m['media_type'] as String?) == 'video'
        ? GalleryMediaType.video
        : GalleryMediaType.image,
    createdAt: DateTime.parse(m['created_at'] as String),
    category: m['category'] as String?,
    editorsChoice: (m['editors_choice'] as bool?) ?? false,
  );

  bool get isVideo => mediaType == GalleryMediaType.video;
}

class GalleryService {
  static final _c = Supabase.instance.client;

  static Future<List<GalleryPost>> list({int? limit, String? category}) async {
    var q = _c.from('gallery_posts').select();
    if (category != null) q = q.eq('category', category);
    final ordered = q.order('created_at', ascending: false);
    final rows = await (limit != null ? ordered.limit(limit) : ordered);
    return (rows as List)
        .map((r) => GalleryPost.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Publicly readable posts (editors_choice = true). No auth required.
  static Future<List<GalleryPost>> listPublic({int? limit}) async {
    final q = _c
        .from('gallery_posts')
        .select()
        .eq('editors_choice', true)
        .order('created_at', ascending: false);
    final rows = await (limit != null ? q.limit(limit) : q);
    return (rows as List)
        .map((r) => GalleryPost.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<String> uploadMedia({
    required Uint8List bytes,
    required String fileExtension,
    required GalleryMediaType type,
  }) async {
    final ext = fileExtension.isEmpty
        ? (type == GalleryMediaType.video ? 'mp4' : 'jpg')
        : fileExtension;
    final prefix = type == GalleryMediaType.video ? 'vid' : 'gal';
    final path = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = type == GalleryMediaType.video ? 'video/$ext' : 'image/$ext';
    await _c.storage
        .from('gallery_photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: mime),
        );
    return _c.storage.from('gallery_photos').getPublicUrl(path);
  }

  /// Streams a local file to Supabase storage in 64 KB chunks and
  /// reports byte-level progress. Use this for big files (videos):
  /// the file body is read from disk on the fly so the app never
  /// loads the whole thing into RAM.
  static Future<String> uploadFileWithProgress({
    required String localPath,
    required String fileExtension,
    required GalleryMediaType type,
    required void Function(int sent, int total) onProgress,
  }) async {
    final file = File(localPath);
    final total = await file.length();
    final ext = fileExtension.isEmpty
        ? (type == GalleryMediaType.video ? 'mp4' : 'jpg')
        : fileExtension;
    final prefix = type == GalleryMediaType.video ? 'vid' : 'gal';
    final path = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = type == GalleryMediaType.video ? 'video/$ext' : 'image/$ext';
    final accessToken = _c.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw StateError('You must be signed in to upload.');
    }

    final uri = Uri.parse(
      '${SupabaseConfig.url}/storage/v1/object/gallery_photos/$path',
    );
    final req = http.StreamedRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['apikey'] = SupabaseConfig.anonKey
      ..headers['Content-Type'] = mime
      ..headers['x-upsert'] = 'false'
      ..contentLength = total;

    // Pump chunks from disk straight into the request sink, calling
    // [onProgress] as bytes flow out.
    var sent = 0;
    final pump = Future(() async {
      try {
        await for (final chunk in file.openRead()) {
          req.sink.add(chunk);
          sent += chunk.length;
          onProgress(sent, total);
        }
      } finally {
        await req.sink.close();
      }
    });

    final responseFuture = req.send();
    await pump;
    final resp = await responseFuture;
    if (resp.statusCode >= 300) {
      final body = await resp.stream.bytesToString();
      throw StateError(_explainUploadError(resp.statusCode, body, total));
    }
    await resp.stream.drain<void>();
    return _c.storage.from('gallery_photos').getPublicUrl(path);
  }

  static String _explainUploadError(int status, String body, int total) {
    final lower = body.toLowerCase();
    final mb = (total / 1024 / 1024).toStringAsFixed(1);
    if (status == 413 ||
        lower.contains('payload too large') ||
        lower.contains('exceeded') ||
        lower.contains('exceeds') ||
        lower.contains('maximum allowed size')) {
      return 'This file ($mb MB) is over the bucket\'s size limit.\n'
          'Open Supabase → Storage → gallery_photos → Configuration and '
          'raise the "File size limit", then try again.\n\n'
          'Server said: $body';
    }
    if (status == 401 ||
        status == 403 ||
        lower.contains('jwt') ||
        lower.contains('permission')) {
      return 'You don\'t have permission to upload here. '
          'Make sure your role is editor or superAdmin.\n\nServer: $body';
    }
    return 'Upload failed (HTTP $status). Server said: $body';
  }

  /// Same as [uploadMedia], but streams the body and reports byte-level
  /// progress as it goes so a UI can show a real progress bar.
  static Future<String> uploadMediaWithProgress({
    required Uint8List bytes,
    required String fileExtension,
    required GalleryMediaType type,
    required void Function(int sent, int total) onProgress,
  }) async {
    final ext = fileExtension.isEmpty
        ? (type == GalleryMediaType.video ? 'mp4' : 'jpg')
        : fileExtension;
    final prefix = type == GalleryMediaType.video ? 'vid' : 'gal';
    final path = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = type == GalleryMediaType.video ? 'video/$ext' : 'image/$ext';
    final accessToken = _c.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw StateError('You must be signed in to upload.');
    }

    final uri = Uri.parse(
      '${SupabaseConfig.url}/storage/v1/object/gallery_photos/$path',
    );
    final req = http.StreamedRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['apikey'] = SupabaseConfig.anonKey
      ..headers['Content-Type'] = mime
      ..headers['x-upsert'] = 'false'
      ..contentLength = bytes.length;

    // Pump the body into the request sink in chunks so we can update
    // progress as each chunk goes out. 64 KB is a good balance between
    // chatty UI updates and overhead.
    const chunkSize = 64 * 1024;
    final pump = Future(() async {
      var sent = 0;
      while (sent < bytes.length) {
        final end = sent + chunkSize < bytes.length
            ? sent + chunkSize
            : bytes.length;
        req.sink.add(bytes.sublist(sent, end));
        sent = end;
        onProgress(sent, bytes.length);
        await Future.delayed(Duration.zero); // yield to socket / UI
      }
      await req.sink.close();
    });

    final responseFuture = req.send();
    await pump;
    final resp = await responseFuture;
    if (resp.statusCode >= 300) {
      final body = await resp.stream.bytesToString();
      throw StateError('Upload failed (HTTP ${resp.statusCode}): $body');
    }
    // Drain the body to free the connection.
    await resp.stream.drain<void>();
    return _c.storage.from('gallery_photos').getPublicUrl(path);
  }

  static Future<void> addPost({
    required String photoUrl,
    required GalleryMediaType mediaType,
    String? caption,
    String? category,
  }) async {
    await _c.from('gallery_posts').insert({
      'photo_url': photoUrl,
      'caption': caption,
      'media_type': mediaType.name,
      'category': category,
      'editors_choice': false,
      'created_by': _c.auth.currentUser?.id,
    });
  }

  /// Update an existing post. Pass only the fields you want to change.
  static Future<void> updatePost({
    required String id,
    String? caption,
    String? photoUrl,
    GalleryMediaType? mediaType,
    String? category,
  }) async {
    final patch = <String, dynamic>{};
    if (caption != null) patch['caption'] = caption.isEmpty ? null : caption;
    if (photoUrl != null) patch['photo_url'] = photoUrl;
    if (mediaType != null) patch['media_type'] = mediaType.name;
    if (category != null)
      patch['category'] = category.isEmpty ? null : category;
    if (patch.isEmpty) return;
    await _c.from('gallery_posts').update(patch).eq('id', id);
  }

  static Future<void> setEditorsChoice(String id, {required bool value}) async {
    await _c
        .from('gallery_posts')
        .update({'editors_choice': value})
        .eq('id', id);
  }

  static Future<void> deletePost(String id) async {
    await _c.from('gallery_posts').delete().eq('id', id);
  }
}
