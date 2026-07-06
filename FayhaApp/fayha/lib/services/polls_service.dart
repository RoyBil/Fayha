import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/app_state.dart';
import 'push_notification_service.dart';

class PollVoter {
  final String memberId;
  final String name;
  final String? photoUrl;
  final String branch;
  final String voiceSection;
  final String role;
  const PollVoter({
    required this.memberId,
    required this.name,
    this.photoUrl,
    required this.branch,
    required this.voiceSection,
    required this.role,
  });
}

class PollOption {
  final String id;
  final String text;
  final int sortOrder;
  final int voteCount;
  final List<PollVoter> voters;
  const PollOption({
    required this.id,
    required this.text,
    required this.sortOrder,
    this.voteCount = 0,
    this.voters = const [],
  });
}

class Poll {
  final String id;
  final String question;
  final String? description;
  final bool multiChoice;
  final String audience;
  final String? branch;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime? closesAt;
  final List<PollOption> options;
  final Set<String> myVotes; // option_ids the current member voted for
  final int totalVotes;

  const Poll({
    required this.id,
    required this.question,
    this.description,
    required this.multiChoice,
    required this.audience,
    this.branch,
    this.createdByName,
    required this.createdAt,
    this.closesAt,
    required this.options,
    required this.myVotes,
    required this.totalVotes,
  });

  bool get isClosed => closesAt != null && DateTime.now().isAfter(closesAt!);
  bool get hasVoted => myVotes.isNotEmpty;
}

class PollsService {
  static final _c = Supabase.instance.client;

  /// All polls visible to the current member, newest first, with tallies
  /// and the current user's votes pre-loaded.
  static Future<List<Poll>> fetchAll() async {
    final me = AppState.instance.currentMember;
    final userId = _c.auth.currentUser?.id;
    if (me == null || userId == null) return [];

    final pollRows = await _c
        .from('polls')
        .select()
        .order('created_at', ascending: false);
    if ((pollRows as List).isEmpty) return [];

    final pollIds = pollRows.map((r) => r['id'] as String).toList();

    final tallies = await _c
        .from('poll_tallies')
        .select()
        .inFilter('poll_id', pollIds);
    final myVotes = await _c
        .from('poll_votes')
        .select('poll_id, option_id')
        .eq('member_id', userId)
        .inFilter('poll_id', pollIds);
    // All votes with member info, for the per-option voter list.
    final allVotes = await _c
        .from('poll_votes')
        .select(
          'poll_id, option_id, member_id, '
          'members(id,name,photo_url,branch,voice_section,role)',
        )
        .inFilter('poll_id', pollIds);

    final tallyByPoll = <String, List<Map<String, dynamic>>>{};
    for (final t in tallies as List) {
      final m = t as Map<String, dynamic>;
      tallyByPoll.putIfAbsent(m['poll_id'] as String, () => []).add(m);
    }
    final votesByPoll = <String, Set<String>>{};
    for (final v in myVotes as List) {
      final m = v as Map<String, dynamic>;
      votesByPoll
          .putIfAbsent(m['poll_id'] as String, () => <String>{})
          .add(m['option_id'] as String);
    }
    // option_id → list of voters
    final votersByOption = <String, List<PollVoter>>{};
    for (final v in allVotes as List) {
      final m = v as Map<String, dynamic>;
      final memberMap = m['members'] as Map<String, dynamic>?;
      if (memberMap == null) continue;
      final voter = PollVoter(
        memberId: memberMap['id'] as String,
        name: (memberMap['name'] as String?) ?? 'Member',
        photoUrl: memberMap['photo_url'] as String?,
        branch: (memberMap['branch'] as String?) ?? '',
        voiceSection: (memberMap['voice_section'] as String?) ?? '',
        role: (memberMap['role'] as String?) ?? 'member',
      );
      votersByOption
          .putIfAbsent(m['option_id'] as String, () => <PollVoter>[])
          .add(voter);
    }

    return pollRows.map((r) {
      final m = r;
      final id = m['id'] as String;
      final opts = (tallyByPoll[id] ?? <Map<String, dynamic>>[])
        ..sort(
          (a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int),
        );
      final options = opts
          .map(
            (o) => PollOption(
              id: o['option_id'] as String,
              text: (o['option_text'] as String?) ?? '',
              sortOrder: (o['sort_order'] as int?) ?? 0,
              voteCount: (o['vote_count'] as int?) ?? 0,
              voters:
                  votersByOption[o['option_id'] as String] ??
                  const <PollVoter>[],
            ),
          )
          .toList();
      final total = options.fold<int>(0, (s, o) => s + o.voteCount);
      return Poll(
        id: id,
        question: (m['question'] as String?) ?? '',
        description: m['description'] as String?,
        multiChoice: (m['multi_choice'] as bool?) ?? false,
        audience: (m['audience'] as String?) ?? 'members',
        branch: m['branch'] as String?,
        createdByName: m['created_by_name'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        closesAt: m['closes_at'] != null
            ? DateTime.parse(m['closes_at'] as String)
            : null,
        options: options,
        myVotes: votesByPoll[id] ?? <String>{},
        totalVotes: total,
      );
    }).toList();
  }

  static Future<void> createPoll({
    required String question,
    String? description,
    required List<String> options,
    bool multiChoice = false,
    String audience = 'members',
    String? branch,
    DateTime? closesAt,
  }) async {
    final me = AppState.instance.currentMember!;
    final inserted = await _c
        .from('polls')
        .insert({
          'question': question,
          'description': description,
          'multi_choice': multiChoice,
          'audience': audience,
          'branch': branch,
          'created_by': me.id,
          'created_by_name': me.name,
          'closes_at': closesAt?.toUtc().toIso8601String(),
        })
        .select()
        .single();
    final pollId = inserted['id'] as String;
    final optRows = <Map<String, dynamic>>[];
    for (var i = 0; i < options.length; i++) {
      optRows.add({'poll_id': pollId, 'text': options[i], 'sort_order': i});
    }
    if (optRows.isNotEmpty) {
      await _c.from('poll_options').insert(optRows);
    }
    AppState.instance.bumpStats();
    await PushNotificationService.dispatch(
      title: '📊 New poll',
      body: question,
      kind: 'poll',
      sourceId: pollId,
    );
  }

  /// Cast a vote. For single-choice polls this replaces any previous vote
  /// on that poll. For multi-choice, it just inserts.
  static Future<void> vote({
    required String pollId,
    required String optionId,
    required bool multiChoice,
  }) async {
    final userId = _c.auth.currentUser!.id;
    if (!multiChoice) {
      await _c
          .from('poll_votes')
          .delete()
          .eq('poll_id', pollId)
          .eq('member_id', userId);
    }
    await _c.from('poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'member_id': userId,
    });
  }

  static Future<void> unvote({
    required String pollId,
    required String optionId,
  }) async {
    final userId = _c.auth.currentUser!.id;
    await _c
        .from('poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('option_id', optionId)
        .eq('member_id', userId);
  }

  static Future<void> deletePoll(String pollId) async {
    await _c.from('polls').delete().eq('id', pollId);
  }
}
