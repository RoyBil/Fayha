import 'choir_data.dart';
import '../state/app_state.dart';

class SongPart {
  final String section;
  final String type;
  const SongPart({required this.section, required this.type});
}

class RepertoireSong {
  final String id;
  final String title;
  final String subtitle;
  final String composers;
  final String lyrics;
  final List<SongPart> parts;
  final bool hasSheetMusic;
  const RepertoireSong({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.composers,
    required this.lyrics,
    this.parts = const _StandardParts(),
    this.hasSheetMusic = true,
  });
}

class _StandardParts implements List<SongPart> {
  const _StandardParts();
  static const _list = [
    SongPart(section: 'Soprano', type: 'Vocal'),
    SongPart(section: 'Mezzo-Soprano', type: 'Vocal'),
    SongPart(section: 'Alto', type: 'Vocal'),
    SongPart(section: 'Contralto', type: 'Vocal'),
    SongPart(section: 'Tenor 1', type: 'Vocal'),
    SongPart(section: 'Tenor 2', type: 'Vocal'),
    SongPart(section: 'Bass 1', type: 'Vocal'),
    SongPart(section: 'Bass 2', type: 'Vocal'),
  ];
  @override SongPart operator [](int index) => _list[index];
  @override int get length => _list.length;
  @override Iterator<SongPart> get iterator => _list.iterator;
  @override List<R> cast<R>() => _list.cast<R>();
  @override SongPart get first => _list.first;
  @override SongPart get last => _list.last;
  @override bool get isEmpty => _list.isEmpty;
  @override bool get isNotEmpty => _list.isNotEmpty;
  @override SongPart get single => _list.single;
  @override SongPart elementAt(int index) => _list.elementAt(index);
  @override bool contains(Object? e) => _list.contains(e);
  @override Iterable<T> map<T>(T Function(SongPart e) f) => _list.map(f);
  @override Iterable<SongPart> where(bool Function(SongPart e) f) => _list.where(f);
  @override Iterable<T> whereType<T>() => _list.whereType<T>();
  @override Iterable<T> expand<T>(Iterable<T> Function(SongPart e) f) => _list.expand(f);
  @override void forEach(void Function(SongPart e) f) => _list.forEach(f);
  @override SongPart reduce(SongPart Function(SongPart, SongPart) f) => _list.reduce(f);
  @override T fold<T>(T initial, T Function(T, SongPart) f) => _list.fold(initial, f);
  @override bool every(bool Function(SongPart e) f) => _list.every(f);
  @override String join([String s = '']) => _list.join(s);
  @override bool any(bool Function(SongPart e) f) => _list.any(f);
  @override List<SongPart> toList({bool growable = true}) => _list.toList(growable: growable);
  @override Set<SongPart> toSet() => _list.toSet();
  @override Iterable<SongPart> take(int n) => _list.take(n);
  @override Iterable<SongPart> takeWhile(bool Function(SongPart e) f) => _list.takeWhile(f);
  @override Iterable<SongPart> skip(int n) => _list.skip(n);
  @override Iterable<SongPart> skipWhile(bool Function(SongPart e) f) => _list.skipWhile(f);
  @override SongPart firstWhere(bool Function(SongPart) test, {SongPart Function()? orElse}) => _list.firstWhere(test, orElse: orElse);
  @override SongPart lastWhere(bool Function(SongPart) test, {SongPart Function()? orElse}) => _list.lastWhere(test, orElse: orElse);
  @override SongPart singleWhere(bool Function(SongPart) test, {SongPart Function()? orElse}) => _list.singleWhere(test, orElse: orElse);
  @override Iterable<SongPart> followedBy(Iterable<SongPart> other) => _list.followedBy(other);
  @override Iterable<SongPart> get reversed => _list.reversed;
  @override List<SongPart> sublist(int start, [int? end]) => _list.sublist(start, end);
  @override Iterable<SongPart> getRange(int start, int end) => _list.getRange(start, end);
  @override int indexOf(SongPart e, [int start = 0]) => _list.indexOf(e, start);
  @override int indexWhere(bool Function(SongPart) test, [int start = 0]) => _list.indexWhere(test, start);
  @override int lastIndexOf(SongPart e, [int? start]) => _list.lastIndexOf(e, start);
  @override int lastIndexWhere(bool Function(SongPart) test, [int? start]) => _list.lastIndexWhere(test, start);
  @override Map<int, SongPart> asMap() => _list.asMap();
  @override List<SongPart> operator +(List<SongPart> other) => _list + other;
  // Unsupported mutating ops
  @override set length(int v) => throw UnsupportedError('const');
  @override set first(SongPart v) => throw UnsupportedError('const');
  @override set last(SongPart v) => throw UnsupportedError('const');
  @override void operator []=(int i, SongPart v) => throw UnsupportedError('const');
  @override void add(SongPart v) => throw UnsupportedError('const');
  @override void addAll(Iterable<SongPart> e) => throw UnsupportedError('const');
  @override void sort([int Function(SongPart, SongPart)? c]) => throw UnsupportedError('const');
  @override void shuffle([random]) => throw UnsupportedError('const');
  @override void clear() => throw UnsupportedError('const');
  @override void insert(int i, SongPart e) => throw UnsupportedError('const');
  @override void insertAll(int i, Iterable<SongPart> e) => throw UnsupportedError('const');
  @override void setAll(int i, Iterable<SongPart> e) => throw UnsupportedError('const');
  @override bool remove(Object? v) => throw UnsupportedError('const');
  @override SongPart removeAt(int i) => throw UnsupportedError('const');
  @override SongPart removeLast() => throw UnsupportedError('const');
  @override void removeWhere(bool Function(SongPart) t) => throw UnsupportedError('const');
  @override void retainWhere(bool Function(SongPart) t) => throw UnsupportedError('const');
  @override void setRange(int s, int e, Iterable<SongPart> i, [int sk = 0]) => throw UnsupportedError('const');
  @override void removeRange(int s, int e) => throw UnsupportedError('const');
  @override void fillRange(int s, int e, [SongPart? v]) => throw UnsupportedError('const');
  @override void replaceRange(int s, int e, Iterable<SongPart> i) => throw UnsupportedError('const');
}

class NewsPost {
  final String title;
  final String body;
  final DateTime postedAt;
  final String? posterLabel;
  final bool isPinned;
  const NewsPost({
    required this.title,
    required this.body,
    required this.postedAt,
    this.posterLabel,
    this.isPinned = false,
  });
}

class SocialPost {
  final String platform;
  final String author;
  final String body;
  final String postedAgo;
  const SocialPost({
    required this.platform,
    required this.author,
    required this.body,
    required this.postedAgo,
  });
}

class AttendanceEntry {
  final String memberName;
  final String voiceSection;
  bool present;
  AttendanceEntry({
    required this.memberName,
    required this.voiceSection,
    this.present = true,
  });
}

class RehearsalRecord {
  final String label;
  final DateTime date;
  final double hours;
  final String type;
  final List<AttendanceEntry> entries;
  RehearsalRecord({
    required this.label,
    required this.date,
    required this.hours,
    required this.type,
    required this.entries,
  });
}

class Poll {
  final String id;
  final String question;
  final String creator;
  final DateTime createdAt;
  final List<String> options;
  final Map<String, int> votes;
  final String? restrictedTo;
  String? myVote;

  Poll({
    required this.id,
    required this.question,
    required this.creator,
    required this.createdAt,
    required this.options,
    Map<String, int>? votes,
    this.restrictedTo,
    this.myVote,
  }) : votes = votes ?? {for (final o in options) o: 0};

  int get totalVotes => votes.values.fold(0, (a, b) => a + b);
}

enum TestimonialStatus { pending, approved, rejected }

class Testimonial {
  final String author;
  final String voiceSection;
  final String body;
  TestimonialStatus status;
  final DateTime submittedAt;
  Testimonial({
    required this.author,
    required this.voiceSection,
    required this.body,
    this.status = TestimonialStatus.pending,
    required this.submittedAt,
  });
}

class DmMessage {
  final String body;
  final DateTime sentAt;
  final bool fromMaestro;
  final bool isVoice;
  final int? voiceSeconds;
  const DmMessage({
    required this.body,
    required this.sentAt,
    this.fromMaestro = false,
    this.isVoice = false,
    this.voiceSeconds,
  });
}

class ClothingItem {
  final String type;
  String size;
  int quantity;
  ClothingItem({required this.type, required this.size, required this.quantity});
}

class AppNotification {
  final String title;
  final String body;
  final DateTime time;
  final String category;
  bool read;
  AppNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    this.read = false,
  });
}

class PendingSignup {
  final String name;
  final String email;
  final String phone;
  final String branch;
  final String voiceSection;
  final DateTime submittedAt;
  const PendingSignup({
    required this.name,
    required this.email,
    required this.phone,
    required this.branch,
    required this.voiceSection,
    required this.submittedAt,
  });
}

class VillagePin {
  final String name;
  final DateTime date;
  final double lat;
  final double lng;
  const VillagePin({
    required this.name,
    required this.date,
    required this.lat,
    required this.lng,
  });
}

class MockData {
  static Member demoMember({bool asMaestro = false}) {
    if (asMaestro) {
      return Member(
        name: 'Barkev Taslakian',
        email: 'maestro@fayhanationalchoir.com',
        phone: '+96176330323',
        joinDate: DateTime(2003, 3, 1),
        branch: 'Tripoli',
        voiceSection: 'Tenor 1',
        isAdmin: true,
        isMaestro: true,
        isPollCreator: true,
      );
    }
    return Member(
      name: 'Roy Bilain',
      email: 'roy@fayhanationalchoir.com',
      phone: '+96171237881',
      joinDate: DateTime(2019, 9, 12),
      branch: 'Beirut',
      voiceSection: 'Tenor 2',
      memorizedSongIds: {'zahrat', 'ahdafi'},
      favoriteSongId: 'an_tuhibba',
      leastFavoriteSongId: 'immi_namit',
    );
  }

  static const List<RepertoireSong> songs = [
    RepertoireSong(
      id: 'zahrat',
      title: 'Zahrat Al Madaen',
      subtitle: 'The Rose of Cities',
      composers: 'Rahbani Brothers · Arr. Edward Torikian',
      lyrics:
          'لأجلك يا مدينة الصلاة أصلي\nلأجلك يا بهية المساكن يا زهرة المدائن\nيا قدس، يا قدس، يا مدينة الصلاة أصلي\nعيوننا إليك ترحل كل يوم\nتدور في أروقة المعابد\nتعانق الكنائس القديمة\nوتمسح الحزن عن المساجد...',
    ),
    RepertoireSong(
      id: 'ahdafi',
      title: 'Ahdafi',
      subtitle: 'My Goals',
      composers: 'Nizar Hindi · Hani Siblini',
      lyrics:
          'أهدافي السبعة عشر\nنحو غدٍ أكثر عدلاً وأماناً\nنزرع السلام، نُنهي الجوع\nنحفظ الأرض، نُعَلِّم الأجيال...',
    ),
    RepertoireSong(
      id: 'asmaa',
      title: 'Asmaa Allah Al Husna',
      subtitle: 'The 99 Names of God',
      composers: 'Islamic Heritage · Arr. Edward Torikian',
      lyrics:
          'هو الله الذي لا إله إلا هو\nالرحمن الرحيم، الملك القدوس\nالسلام المؤمن المهيمن\nالعزيز الجبار المتكبر...',
    ),
    RepertoireSong(
      id: 'an_tuhibba',
      title: 'An Tuhibba',
      subtitle: 'To Love',
      composers: 'Arabic Traditional · Arr. Edward Torikian',
      lyrics:
          'أن تحبَّ يعني أن تعيشَ مرتين\nأن تعرفَ بأنَّ الفجرَ آتٍ\nمهما طالت ليلةُ الانتظار...',
    ),
    RepertoireSong(
      id: 'immi_namit',
      title: 'Immi Namit',
      subtitle: 'My Mother Has Slept',
      composers: 'Lebanese Folk · Arr. Edward Torikian',
      lyrics:
          'إمّي نامت، نامت بلا غناء\nخلّيني أحلم، أحلم بالضياء\nليالي الصيف، نسمة من سماء...',
    ),
    RepertoireSong(
      id: 'fog_el_nakhel',
      title: 'Fog El Nakhel',
      subtitle: 'Above the Palm Trees',
      composers: 'Iraqi Traditional · Arr. Edward Torikian',
      lyrics:
          'فوق النخل فوق يابا فوق النخل فوق\nمدري لمع خدّه يابا مدري القمر فوق\nوالله ما أريده بس هواه شاغلني...',
    ),
  ];

  static final List<NewsPost> privateNews = [
    NewsPost(
      title: 'Spring Recital — Dress Rehearsal Schedule',
      body:
          'Dress rehearsal moved to Friday June 12 at 6 PM at Al Madina Theatre. Please arrive 30 minutes early in full uniform. Bring water and your folders.',
      postedAt: DateTime(2026, 5, 14, 9, 0),
      posterLabel: 'Spring Recital Poster',
      isPinned: true,
    ),
    NewsPost(
      title: 'New piece added to repertoire',
      body:
          'We are adding "Fog El Nakhel" to the program. Tracks and lyrics are now in the Songs tab — please start listening before next rehearsal.',
      postedAt: DateTime(2026, 5, 10, 18, 30),
    ),
    NewsPost(
      title: 'Branch meeting — Beirut',
      body:
          'Beirut branch will hold a coordination meeting Sunday after rehearsal. Section leaders please stay.',
      postedAt: DateTime(2026, 5, 8, 11, 0),
    ),
  ];

  static const List<SocialPost> publicSocialFeed = [
    SocialPost(
      platform: 'Instagram',
      author: '@fayhachoir',
      body: 'Tonight in Tripoli — full house, full hearts. Thank you to everyone who came!',
      postedAgo: '2 days ago',
    ),
    SocialPost(
      platform: 'Facebook',
      author: 'Fayha National Choir',
      body: 'Behind the scenes from the Angham w Salam rehearsal — 200 voices in one hall.',
      postedAgo: '5 days ago',
    ),
    SocialPost(
      platform: 'Instagram',
      author: '@fayhachoir',
      body: 'Workshop with the European Choral Association: a week of exchange in the heart of Beirut.',
      postedAgo: '2 weeks ago',
    ),
  ];

  static final List<RehearsalRecord> rehearsals = [
    RehearsalRecord(
      label: 'Beirut weekly rehearsal',
      date: DateTime(2026, 5, 16, 18, 0),
      hours: 2.5,
      type: 'Rehearsal',
      entries: [
        AttendanceEntry(memberName: 'Roy Bilain', voiceSection: 'Tenor 2', present: true),
        AttendanceEntry(memberName: 'Nour Khoury', voiceSection: 'Soprano', present: true),
        AttendanceEntry(memberName: 'Karim Saade', voiceSection: 'Bass 1', present: false),
        AttendanceEntry(memberName: 'Layla Hadad', voiceSection: 'Alto', present: true),
      ],
    ),
    RehearsalRecord(
      label: 'Sectional — Tenors',
      date: DateTime(2026, 5, 11, 19, 0),
      hours: 1.5,
      type: 'Sectional',
      entries: [
        AttendanceEntry(memberName: 'Roy Bilain', voiceSection: 'Tenor 2', present: true),
        AttendanceEntry(memberName: 'Bassam Faour', voiceSection: 'Tenor 1', present: true),
      ],
    ),
    RehearsalRecord(
      label: 'Full ensemble — Spring program',
      date: DateTime(2026, 5, 4, 18, 0),
      hours: 3,
      type: 'Rehearsal',
      entries: [
        AttendanceEntry(memberName: 'Roy Bilain', voiceSection: 'Tenor 2', present: true),
        AttendanceEntry(memberName: 'Nour Khoury', voiceSection: 'Soprano', present: false),
        AttendanceEntry(memberName: 'Layla Hadad', voiceSection: 'Alto', present: true),
      ],
    ),
  ];

  static final List<Poll> polls = [
    Poll(
      id: 'p1',
      question: 'Encore piece for the spring recital?',
      creator: 'Maestro Barkev',
      createdAt: DateTime(2026, 5, 12),
      options: ['Zahrat Al Madaen', 'Ahdafi', 'Asmaa Allah Al Husna'],
      votes: {'Zahrat Al Madaen': 28, 'Ahdafi': 14, 'Asmaa Allah Al Husna': 22},
    ),
    Poll(
      id: 'p2',
      question: 'Preferred Saturday rehearsal time?',
      creator: 'Roula Abou Baker',
      createdAt: DateTime(2026, 5, 5),
      options: ['10:00 AM', '2:00 PM', '6:00 PM'],
      votes: {'10:00 AM': 9, '2:00 PM': 17, '6:00 PM': 31},
    ),
    Poll(
      id: 'p3',
      question: 'Tenors — should we add a third sectional this month?',
      creator: 'Bassam Faour',
      createdAt: DateTime(2026, 5, 9),
      options: ['Yes', 'No', 'Only if needed'],
      votes: {'Yes': 6, 'No': 2, 'Only if needed': 4},
      restrictedTo: 'Tenor 1, Tenor 2',
    ),
  ];

  static final List<Testimonial> testimonials = [
    Testimonial(
      author: 'Nour Khoury',
      voiceSection: 'Soprano',
      body:
          'Fayha has become my second family. Every rehearsal, every concert — I leave feeling lifted, no matter what kind of week I had. Singing in Arabic with this ensemble has reconnected me with a part of myself I didn\'t know I had lost.',
      status: TestimonialStatus.approved,
      submittedAt: DateTime(2026, 4, 22),
    ),
    Testimonial(
      author: 'Karim Saade',
      voiceSection: 'Bass 1',
      body:
          'Joining the choir was the best decision I made in 2023. The musical depth, the friendship, the discipline — it\'s a craft that has shaped me beyond singing.',
      status: TestimonialStatus.approved,
      submittedAt: DateTime(2026, 3, 30),
    ),
    Testimonial(
      author: 'Layla Hadad',
      voiceSection: 'Alto',
      body:
          'There is something sacred about the moment right before we start a piece. We breathe together, and the room becomes something else.',
      status: TestimonialStatus.pending,
      submittedAt: DateTime(2026, 5, 12),
    ),
  ];

  static final List<DmMessage> maestroDm = [
    DmMessage(
      body: 'Maestro, would it be possible to switch my second tenor part for "Fog El Nakhel"? My range is more comfortable on the lower line.',
      sentAt: DateTime(2026, 5, 13, 21, 14),
    ),
    DmMessage(
      body: 'Of course Roy — try it next rehearsal and we will hear how it sits.',
      sentAt: DateTime(2026, 5, 13, 22, 2),
      fromMaestro: true,
    ),
    DmMessage(
      body: 'Voice note',
      sentAt: DateTime(2026, 5, 14, 8, 30),
      isVoice: true,
      voiceSeconds: 32,
    ),
  ];

  static final List<ClothingItem> clothing = [
    ClothingItem(type: 'Suit', size: 'M', quantity: 1),
    ClothingItem(type: 'Shirt', size: 'M', quantity: 3),
    ClothingItem(type: 'Cap', size: 'One Size', quantity: 1),
  ];

  static final List<AppNotification> notifications = [
    AppNotification(
      title: 'New post: Spring Recital — Dress Rehearsal',
      body: 'Dress rehearsal moved to Friday June 12 at 6 PM.',
      time: DateTime(2026, 5, 14, 9, 1),
      category: 'News',
    ),
    AppNotification(
      title: 'Poll closing soon',
      body: 'Vote on the encore piece for the spring recital.',
      time: DateTime(2026, 5, 13, 19, 0),
      category: 'Poll',
    ),
    AppNotification(
      title: 'Rehearsal tomorrow — Beirut',
      body: '18:00 at the regular hall. Don\'t forget your folder.',
      time: DateTime(2026, 5, 15, 12, 0),
      category: 'Rehearsal',
      read: true,
    ),
    AppNotification(
      title: 'Concert reminder',
      body: 'Spring Recital · June 14 · Al Madina Theatre.',
      time: DateTime(2026, 5, 10, 8, 0),
      category: 'Concert',
      read: true,
    ),
  ];

  static final List<PendingSignup> pendingSignups = [
    PendingSignup(
      name: 'Yara Mansour',
      email: 'yara.m@example.com',
      phone: '+96170555111',
      branch: 'Aley',
      voiceSection: 'Mezzo-Soprano',
      submittedAt: DateTime(2026, 5, 13),
    ),
    PendingSignup(
      name: 'Tarek Awad',
      email: 'tarek.awad@example.com',
      phone: '+96176222999',
      branch: 'Tripoli',
      voiceSection: 'Bass 2',
      submittedAt: DateTime(2026, 5, 14),
    ),
  ];

  static final List<VillagePin> villages = [
    VillagePin(name: 'Tripoli', date: DateTime.utc(2003, 5, 1), lat: 34.4367, lng: 35.8497),
    VillagePin(name: 'Beirut', date: DateTime.utc(2010, 11, 3), lat: 33.8938, lng: 35.5018),
    VillagePin(name: 'Aley', date: DateTime.utc(2022, 7, 12), lat: 33.8000, lng: 35.6000),
    VillagePin(name: 'Chouf', date: DateTime.utc(2022, 9, 8), lat: 33.6900, lng: 35.6900),
    VillagePin(name: 'Saida', date: DateTime.utc(2018, 4, 21), lat: 33.5571, lng: 35.3717),
    VillagePin(name: 'Bekaa', date: DateTime.utc(2014, 6, 15), lat: 33.8463, lng: 35.9019),
    VillagePin(name: 'Byblos', date: DateTime.utc(2016, 8, 19), lat: 34.1232, lng: 35.6519),
    VillagePin(name: 'Nahr El Bared', date: DateTime.utc(2011, 5, 4), lat: 34.5400, lng: 35.9700),
  ];

  static const String maestroBio =
      '${ChoirData.presidentName} — Founder and Principal Conductor of Fayha National Choir. Maestro Taslakian has shaped Arabic a cappella into an internationally recognized artform, training over a hundred amateur singers and dozens of conductors across the Arab region.';

  static const String managerBio =
      '${ChoirData.managerName} — Managing Director. Oversees operations, partnerships, and the choir\'s social and international projects.';

  static int rehearsalsAttended(Member m) {
    return rehearsals
        .where((r) => r.entries.any((e) => e.memberName == m.name && e.present))
        .length;
  }

  static double hoursAttended(Member m) {
    return rehearsals
        .where((r) => r.entries.any((e) => e.memberName == m.name && e.present))
        .fold(0.0, (sum, r) => sum + r.hours);
  }

  static int concertsAttended(Member m) => 14;
}
