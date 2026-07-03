import 'package:supabase_flutter/supabase_flutter.dart';

class NewsletterSubscriber {
  final String id;
  final String email;
  final DateTime subscribedAt;
  NewsletterSubscriber({
    required this.id,
    required this.email,
    required this.subscribedAt,
  });
  factory NewsletterSubscriber.fromMap(Map<String, dynamic> m) =>
      NewsletterSubscriber(
        id: m['id'] as String,
        email: m['email'] as String,
        subscribedAt: DateTime.parse(m['subscribed_at'] as String).toLocal(),
      );
}

class NewsletterService {
  static final _c = Supabase.instance.client;

  /// Editor / superAdmin only (enforced by RLS).
  static Future<List<NewsletterSubscriber>> list() async {
    final rows = await _c
        .from('newsletter_subscriptions')
        .select()
        .order('subscribed_at', ascending: false);
    return (rows as List)
        .map((r) => NewsletterSubscriber.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> remove(String id) async {
    await _c.from('newsletter_subscriptions').delete().eq('id', id);
  }
}
