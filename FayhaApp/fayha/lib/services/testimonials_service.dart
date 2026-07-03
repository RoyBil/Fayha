import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart';

class TestimonialsService {
  static final _c = Supabase.instance.client;

  // ===== Reads =====

  /// Publicly visible testimonials (featured + normal).
  /// Featured rows come first, then newest-first.
  static Future<List<Testimonial>> fetchPublic() async {
    final rows = await _c
        .from('testimonials')
        .select()
        .inFilter('importance', ['featured', 'normal'])
        .order('submitted_at', ascending: false);
    final list = (rows as List).map(_fromMap).toList();
    list.sort((a, b) {
      // featured before normal, then newer first
      int rank(TestimonialImportance i) =>
          i == TestimonialImportance.featured ? 0 : 1;
      final r = rank(a.importance).compareTo(rank(b.importance));
      if (r != 0) return r;
      return b.submittedAt.compareTo(a.submittedAt);
    });
    return list;
  }

  /// Editors / super admins see everything, including hidden.
  static Future<List<Testimonial>> fetchAll() async {
    final rows = await _c
        .from('testimonials')
        .select()
        .order('submitted_at', ascending: false);
    return (rows as List).map(_fromMap).toList();
  }

  // ===== Submit (any visitor) =====

  static Future<void> submit({
    required String author,
    required String email,
    required String body,
    String? voiceSection,
    String? photoUrl,
  }) async {
    await _c.from('testimonials').insert({
      'author': author,
      'email': email,
      'body': body,
      'voice_section': voiceSection,
      'photo_url': photoUrl,
      // New submissions land as 'normal' so they appear immediately.
      // Editors can promote (featured) or hide them later.
      'importance': 'normal',
    });
  }

  /// Uploads a photo to the public `testimonial_photos` bucket and
  /// returns its public URL.
  static Future<String> uploadPhoto({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.isEmpty ? 'jpg' : fileExtension;
    final path = 'tm_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage
        .from('testimonial_photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: 'image/$ext'),
        );
    return _c.storage.from('testimonial_photos').getPublicUrl(path);
  }

  // ===== Editor / super admin =====

  static Future<void> setImportance(String id, TestimonialImportance i) async {
    await _c.from('testimonials').update({'importance': i.name}).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _c.from('testimonials').delete().eq('id', id);
  }

  // ===== Mapping =====

  static Testimonial _fromMap(dynamic r) {
    final m = r as Map<String, dynamic>;
    return Testimonial(
      id: m['id'] as String?,
      author: (m['author'] as String?) ?? '',
      voiceSection: (m['voice_section'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      email: m['email'] as String?,
      photoUrl: m['photo_url'] as String?,
      importance: _importanceFrom(m['importance'] as String?),
      submittedAt: DateTime.parse(m['submitted_at'] as String),
    );
  }

  static TestimonialImportance _importanceFrom(String? v) {
    switch (v) {
      case 'featured':
        return TestimonialImportance.featured;
      case 'hidden':
        return TestimonialImportance.hidden;
      default:
        return TestimonialImportance.normal;
    }
  }
}
