class NotablePiece {
  final String title;
  final String subtitle;
  final String composers;
  final String description;
  final String youtubeUrl;
  const NotablePiece({
    required this.title,
    required this.subtitle,
    required this.composers,
    required this.description,
    required this.youtubeUrl,
  });
}

class Achievement {
  final int year;
  final String title;
  final String event;
  const Achievement(this.year, this.title, this.event);
}

class TrainedChoir {
  final String name;
  final String location;
  final String period;
  final String conductor;
  final String note;
  final String instagramUrl;
  const TrainedChoir({
    required this.name,
    required this.location,
    required this.period,
    required this.conductor,
    required this.note,
    required this.instagramUrl,
  });
}

class SocialProject {
  final String name;
  final String period;
  final String description;
  const SocialProject({
    required this.name,
    required this.period,
    required this.description,
  });
}

class NewsItem {
  final String title;
  final String body;
  final String date;
  final String? posterUrl;
  const NewsItem({
    required this.title,
    required this.body,
    required this.date,
    this.posterUrl,
  });
}

class Concert {
  final String? id;
  final String title;
  final String location;
  final DateTime date;
  final String description;
  final String kind; // concert | rehearsal
  final String? posterUrl;
  const Concert({
    this.id,
    required this.title,
    required this.location,
    required this.date,
    required this.description,
    this.kind = 'concert',
    this.posterUrl,
  });
  bool get isRehearsal => kind == 'rehearsal';
}

class ChoirData {
  static const String name = 'Fayha National Choir';
  static const String tagline = 'A mixed Lebanese a cappella choir, revolutionizing Arabic choral music.';
  static const String founded = '2003';
  static const String founder = 'Maestro Barkev Taslakian';

  static const String storyShort =
      'Founded in 2003 by Maestro Barkev Taslakian, Fayha National Choir is a mixed Lebanese a cappella ensemble internationally renowned for revolutionizing Arabic choral music. In 2022, having established branches in Beirut, Aley, and Chouf, the choir was designated the first Lebanese National Choir.';

  static const String storyFull =
      'Fayha National Choir is a mixed Lebanese a cappella choir, internationally renowned for revolutionizing Arabic choral music. It was founded in 2003 by Maestro Barkev Taslakian, who remains its principal conductor and artistic director. The choir was originally based in Tripoli and adopted the city\'s local nickname \'Fayha\', meaning fragrant, due to the orange groves that surround it. In 2022, having established branches across Lebanon in Beirut, Aley, and Chouf, the choir was designated the first Lebanese National Choir.\n\nGlobally recognized as a standard for Arabic a cappella, the choir primarily aims to develop the artform and spread Arabic musical heritage. Its repertoire revives and sustains classics from across the Middle East and North Africa — offering unique interpretations while remaining faithful to Arabic musical tradition. Over the past two decades, we have commissioned choral arrangements for hundreds of pieces, amassing an extensive archive and rendering Fayha National Choir the prime resource for Arabic choral arrangements.\n\nThe choir is a product of Lebanon\'s rich social fabric and consists of around a hundred amateur singers coming from all walks of life, proudly coexisting and thriving despite their diverse religions, nationalities and socioeconomic status.';

  static const String musicIntro =
      'The arrangements are commissioned by the choir from several musicians, most notably Dr. Edward Torikian, Professor of Music at USEK. Despite its young age, the Arabic a cappella artform has quickly matured — garnering an international audience. Our experimentation with Arabic rhythms, microtonal maqams, and unique linguistic textures, combined with songs of resilience, identity, and prayer, makes for a novel, moving, and exciting sonic experience. To date, the choir has been invited to perform in more than 20 countries, from China to Canada.';

  static const List<NotablePiece> notablePieces = [
    NotablePiece(
      title: 'Zahrat Al Madaen',
      subtitle: 'The Rose of Cities',
      composers: 'Rahbani Brothers · Arr. Edward Torikian',
      description:
          'A tribute to the Palestinian cause and the peace that must come, presented as a journey through the different mosques and churches of Jerusalem, the rose of all cities.',
      youtubeUrl: 'https://youtu.be/6IIaNAGL2as',
    ),
    NotablePiece(
      title: 'Ahdafi',
      subtitle: 'My Goals',
      composers: 'Nizar Hindi · Hani Siblini',
      description:
          "The 17 Sustainable Development Goals of the UN's 2030 agenda presented as a choral piece emphasizing the collective voice.",
      youtubeUrl: 'https://youtu.be/A5cW2hefuMY',
    ),
    NotablePiece(
      title: 'Asmaa Allah Al Husna',
      subtitle: 'The 99 Names of God',
      composers: 'Islamic Heritage · Arr. Edward Torikian',
      description:
          'An a cappella prayer reciting the 99 holy names of God in the Islamic faith.',
      youtubeUrl: 'https://youtu.be/gAArwqnML8s',
    ),
  ];

  static const List<Achievement> achievements = [
    Achievement(2007, '1st Prize, Mixed Adult Choirs', 'Warsaw International Choir Festival'),
    Achievement(2005, '2nd Prize, Mixed Adult Choirs', 'Warsaw International Choir Festival'),
    Achievement(2023, 'Invited Choir', 'World Symposium on Choral Music (IFCM)'),
    Achievement(2016, '1st Prize', 'ChoirFest Middle East'),
    Achievement(2018, '2nd Prize', 'ChoirFest Middle East'),
    Achievement(2016, '1st Prize', '"Music and the Sea", International Festival, Greece'),
    Achievement(2015, 'Music Rights Award', 'International Music Council'),
  ];

  static const List<TrainedChoir> trainedChoirs = [
    TrainedChoir(
      name: 'Maqam Choir',
      location: 'Bekaa, Lebanon',
      period: '2023 – Present',
      conductor: 'George Faraj',
      note: 'Studied within one of the choir\'s social projects and proceeded to start his own choir.',
      instagramUrl: 'https://www.instagram.com/maqam.choir/',
    ),
    TrainedChoir(
      name: 'Shaghaf Choir',
      location: 'Cairo, Egypt',
      period: '2024 – Present',
      conductor: 'Islam Saeed',
      note: 'Overseen by Fayha National Choir; conductor studies under Maestro Taslakian\'s leadership.',
      instagramUrl: 'https://www.instagram.com/shaghaf_choir/',
    ),
    TrainedChoir(
      name: 'Najd Choir',
      location: 'Riyadh, Saudi Arabia',
      period: '2019 – Present',
      conductor: 'Adnan Rachid',
      note: 'A previous student and member at Fayha National Choir.',
      instagramUrl: 'https://www.instagram.com/najdchoir_official/',
    ),
    TrainedChoir(
      name: 'Nagham Choir',
      location: 'Tripoli, Lebanon',
      period: '2019 – 2022',
      conductor: 'Mahmoud Mawwas',
      note: 'An assistant conductor at Fayha National Choir.',
      instagramUrl: 'https://www.instagram.com/naghamchoir/',
    ),
    TrainedChoir(
      name: 'Fan Choir',
      location: 'Saida, Lebanon',
      period: '2022 – 2024',
      conductor: 'Roudy Francis',
      note: 'Studied within one of the choir\'s social projects and proceeded to start his own choir.',
      instagramUrl: 'https://www.instagram.com/fanchoirsaida/',
    ),
  ];

  static const List<SocialProject> socialProjects = [
    SocialProject(
      name: 'UNESCO Choir',
      period: '2009 – 2013',
      description:
          'In collaboration with the UNESCO regional office. Targeted more than 10,000 marginalized students in public schools, piloting extracurricular activities as a means to reinsert out-of-school children and retain students at risk of dropping out.',
    ),
    SocialProject(
      name: 'Lebanese Palestinian Chamber Choir',
      period: '2009 – 2011',
      description:
          'In collaboration with UNDP. In the aftermath of the 2011 war at Nahr El Bared camp, it aimed to refoster peaceful relations between Palestinian residents of the camp and the Lebanese villages nearby.',
    ),
    SocialProject(
      name: 'Sonbula Choir',
      period: '2014 – 2022',
      description:
          'In coordination with the Sonbula Association for Syrian Refugees in Lebanon, funded by Nai Association in Austria. Targeted 150 refugee children from camps across the Bekaa region.',
    ),
    SocialProject(
      name: 'Angham w Salam Choir',
      period: '2022 – Present',
      description:
          'In coordination with UNDP, funded by KFW development bank. A nationwide community choir with 150 members and four branches across Lebanese provinces. Currently training 15 conductors; two choirs have already emerged — Maqam Choir and Fan Choir.',
    ),
  ];

  static const List<NewsItem> news = [
    NewsItem(
      title: 'Study Tour with the European Choral Association',
      date: '2025',
      body:
          'In collaboration with the European Choral Association, the choir organized a study tour to Lebanon — welcoming conductors and choral leaders to engage in artistic exchange, workshops on Arabic music, and a culturally immersive experience.',
    ),
    NewsItem(
      title: 'World Symposium on Choral Music',
      date: '2023, Istanbul',
      body:
          'Fayha National Choir performed at the World Symposium on Choral Music in Istanbul, organized by the International Federation for Choral Music.',
    ),
    NewsItem(
      title: 'First Lebanese National Choir',
      date: '2022',
      body:
          'Having established branches in Beirut, Aley, and Chouf — in addition to its original Tripoli home — the choir was designated the first Lebanese National Choir.',
    ),
  ];

  static final List<Concert> upcomingConcerts = [
    Concert(
      title: 'Spring Recital',
      location: 'Al Madina Theatre, Beirut',
      date: DateTime(2026, 6, 14, 20, 0),
      description: 'An evening of Arabic a cappella classics, featuring guest soloists.',
    ),
    Concert(
      title: 'Angham w Salam Community Concert',
      location: 'Cultural Center, Tripoli',
      date: DateTime(2026, 7, 5, 19, 30),
      description: 'A nationwide community choir performance, 200+ voices on stage.',
    ),
  ];

  static const String managerEmail = 'manager@fayhanationalchoir.com';
  static const List<String> phones = ['+96176330323', '+9613330323'];
  static const String websiteUrl = 'https://fayhanationalchoir.com';
  static const String licFestivalUrl = 'https://licfestival.org/2017/';

  static const String presidentName = 'Barkev Taslakian';
  static const String presidentTitle = 'President and Principal Conductor';
  static const String managerName = 'Roula Abou Baker';
  static const String managerTitle = 'Managing Director';

  static const List<String> voiceSections = [
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

  /// Voice-section targets an admin can pick when sending a message —
  /// individual sections + collective groups (e.g. "All Tenors").
  /// The map value lists every individual section the group covers.
  static const Map<String, List<String>> voiceSectionGroups = {
    'All Sopranos': ['Soprano', 'Mezzo Soprano'],
    'All Altos': ['Alto', 'Contrary Alto'],
    'All Tenors': ['Tenor I', 'Tenor II'],
    'All Basses': ['Baritone', 'Bass'],
    'Whole choir': [
      'Solo',
      'Soprano',
      'Mezzo Soprano',
      'Alto',
      'Contrary Alto',
      'Tenor I',
      'Tenor II',
      'Baritone',
      'Bass',
    ],
  };

  /// Flat list of all message-target options: individual sections
  /// first, then collective groups.
  static const List<String> messageVoiceTargets = [
    'Solo',
    'Soprano',
    'Mezzo Soprano',
    'Alto',
    'Contrary Alto',
    'Tenor I',
    'Tenor II',
    'Baritone',
    'Bass',
    'All Sopranos',
    'All Altos',
    'All Tenors',
    'All Basses',
    'Whole choir',
  ];

  static const List<String> branches = [
    'Tripoli',
    'Beirut',
    'Aley',
    'Chouf',
  ];
}
