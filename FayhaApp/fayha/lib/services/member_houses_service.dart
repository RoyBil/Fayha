import 'package:supabase_flutter/supabase_flutter.dart';

class MemberHouse {
  final String id;
  final String name;
  final String branch;
  final String voiceSection;
  final String role;
  final double lat;
  final double lng;
  final String? address;
  final String? photoUrl;

  const MemberHouse({
    required this.id,
    required this.name,
    required this.branch,
    required this.voiceSection,
    required this.role,
    required this.lat,
    required this.lng,
    this.address,
    this.photoUrl,
  });
}

class MemberHousesService {
  static final _c = Supabase.instance.client;

  /// All active members who have set a house location and opted in
  /// to sharing it. Used by the members map.
  static Future<List<MemberHouse>> fetchAll() async {
    final rows = await _c
        .from('members')
        .select(
          'id, name, branch, voice_section, role, photo_url, house_lat, house_lng, house_address, share_location, status',
        )
        .eq('status', 'active')
        .not('house_lat', 'is', null)
        .not('house_lng', 'is', null);
    return (rows as List)
        .map((r) => r as Map<String, dynamic>)
        .where((r) => (r['share_location'] as bool?) ?? true)
        .map(
          (r) => MemberHouse(
            id: r['id'] as String,
            name: (r['name'] as String?) ?? 'Member',
            branch: (r['branch'] as String?) ?? '',
            voiceSection: (r['voice_section'] as String?) ?? '',
            role: (r['role'] as String?) ?? 'member',
            lat: (r['house_lat'] as num).toDouble(),
            lng: (r['house_lng'] as num).toDouble(),
            address: r['house_address'] as String?,
            photoUrl: r['photo_url'] as String?,
          ),
        )
        .toList();
  }
}
