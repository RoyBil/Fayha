import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/choir_data.dart';
import '../data/map_data.dart';
import '../data/mock_data.dart';

class AudienceData {
  static final _c = Supabase.instance.client;

  // ===== NEWS =====
  static Future<List<NewsItem>> fetchNews() async {
    final rows = await _c
        .from('news_posts')
        .select()
        .order('sort_date', ascending: false);
    return (rows as List)
        .map((r) => NewsItem(
              date: r['date_label'] as String,
              title: r['title'] as String,
              body: r['body'] as String,
              posterUrl: r['poster_url'] as String?,
            ))
        .toList();
  }

  // ===== SONGS =====
  static Future<List<RepertoireSong>> fetchSongs() async {
    final rows = await _c.from('songs').select().order('sort_order');
    return (rows as List)
        .map((r) => RepertoireSong(
              id: r['id'] as String,
              title: r['title'] as String,
              subtitle: (r['subtitle'] as String?) ?? '',
              composers: (r['composers'] as String?) ?? '',
              lyrics: (r['lyrics'] as String?) ?? '',
            ))
        .toList();
  }

  static Future<List<NotablePiece>> fetchNotablePieces() async {
    final rows = await _c
        .from('songs')
        .select()
        .not('youtube_url', 'is', null)
        .order('sort_order');
    return (rows as List)
        .map((r) => NotablePiece(
              title: r['title'] as String,
              subtitle: (r['subtitle'] as String?) ?? '',
              composers: (r['composers'] as String?) ?? '',
              description: (r['description'] as String?) ?? '',
              youtubeUrl: r['youtube_url'] as String,
            ))
        .toList();
  }

  // ===== BRANCHES =====
  static Future<List<BranchLocation>> fetchBranches() async {
    final rows = await _c.from('branches').select().order('sort_order');
    return (rows as List).map((r) {
      final name = r['name'] as String;
      return BranchLocation(
        name: name,
        practiceLocation: r['practice_location'] as String,
        mapUrl: (r['map_url'] as String?) ?? '',
        color: MapData.colorFor(name),
        lat: (r['lat'] as num).toDouble(),
        lng: (r['lng'] as num).toDouble(),
        yearOpened: r['year_opened'] as int? ?? 0,
        conductor: (r['conductor'] as String?) ?? '',
        membersApprox: r['members_approx'] as int? ?? 0,
        rehearsalSchedule: (r['rehearsal_schedule'] as String?) ?? '',
        description: (r['description'] as String?) ?? '',
      );
    }).toList();
  }

  // ===== VENUES =====
  static Future<List<Venue>> fetchVenues() async {
    final rows = await _c
        .from('venues')
        .select()
        .order('performed_at', ascending: false);
    return (rows as List)
        .map((r) => Venue(
              city: r['city'] as String,
              country: r['country'] as String,
              date: r['date_label'] as String,
              sortDate: DateTime.parse(r['performed_at'] as String),
              lat: (r['lat'] as num).toDouble(),
              lng: (r['lng'] as num).toDouble(),
              event: (r['event'] as String?) ?? '',
              notes: (r['notes'] as String?) ?? '',
            ))
        .toList();
  }

  // ===== TRAINED CHOIRS =====
  static Future<List<TrainedChoir>> fetchTrainedChoirs() async {
    final rows = await _c
        .from('trained_choirs')
        .select()
        .order('sort_order');
    return (rows as List)
        .map((r) => TrainedChoir(
              name: r['name'] as String,
              location: r['location'] as String,
              period: r['period'] as String,
              conductor: r['conductor'] as String,
              note: (r['note'] as String?) ?? '',
              instagramUrl: (r['instagram_url'] as String?) ?? '',
            ))
        .toList();
  }

  // ===== ACHIEVEMENTS =====
  static Future<List<Achievement>> fetchAchievements() async {
    final rows = await _c.from('achievements').select().order('sort_order');
    return (rows as List)
        .map((r) => Achievement(
              r['year'] as int,
              r['title'] as String,
              r['event'] as String,
            ))
        .toList();
  }

  // ===== SOCIAL PROJECTS =====
  static Future<List<SocialProject>> fetchSocialProjects() async {
    final rows = await _c.from('social_projects').select().order('sort_order');
    return (rows as List)
        .map((r) => SocialProject(
              name: r['name'] as String,
              period: r['period'] as String,
              description: r['description'] as String,
            ))
        .toList();
  }

  // ===== TESTIMONIALS (only approved are publicly readable) =====
  static Future<List<Testimonial>> fetchApprovedTestimonials() async {
    final rows = await _c
        .from('testimonials')
        .select()
        .order('submitted_at', ascending: false);
    return (rows as List)
        .map((r) => Testimonial(
              author: r['author'] as String,
              voiceSection: (r['voice_section'] as String?) ?? '',
              body: r['body'] as String,
              status: TestimonialStatus.approved,
              submittedAt: DateTime.parse(r['submitted_at'] as String),
            ))
        .toList();
  }

  static Future<void> submitTestimonial({
    required String author,
    required String voiceSection,
    required String body,
  }) async {
    await _c.from('testimonials').insert({
      'author': author,
      'voice_section': voiceSection,
      'body': body,
      'status': 'pending',
    });
  }

  // ===== SOCIAL POSTS =====
  // RLS limits audience visibility to importance='important' rows.
  static Future<List<SocialPost>> fetchSocialPosts() async {
    final rows = await _c
        .from('social_posts')
        .select()
        .eq('importance', 'important')
        .order('posted_at', ascending: false);
    return (rows as List)
        .map((r) => SocialPost(
              id: r['id'] as String?,
              platform: r['platform'] as String,
              author: r['author'] as String,
              body: (r['body'] as String?) ?? '',
              postedAgo: (r['posted_label'] as String?) ?? '',
              permalink: r['permalink'] as String?,
              mediaUrl: r['media_url'] as String?,
              mediaType: r['media_type'] as String?,
              importance: SocialImportance.important,
            ))
        .toList();
  }

  // ===== NEWSLETTER =====
  static Future<void> subscribeNewsletter(String email) async {
    // Plain insert — `upsert(onConflict: 'email')` needed an UPDATE
    // policy that anon users don't have, which made every signup fail.
    // A duplicate just means "already on the list" → silent success.
    try {
      await _c.from('newsletter_subscriptions').insert({'email': email});
    } on PostgrestException catch (e) {
      // 23505 = unique_violation.
      if (e.code == '23505') return;
      rethrow;
    }
  }
}
