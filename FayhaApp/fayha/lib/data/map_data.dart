import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BranchLocation {
  final String name;
  final String practiceLocation;
  final String mapUrl;
  final Color color;
  final double lat;
  final double lng;
  final int yearOpened;
  final String conductor;
  final int membersApprox;
  final String rehearsalSchedule;
  final String description;

  const BranchLocation({
    required this.name,
    required this.practiceLocation,
    required this.mapUrl,
    required this.color,
    required this.lat,
    required this.lng,
    required this.yearOpened,
    required this.conductor,
    required this.membersApprox,
    required this.rehearsalSchedule,
    required this.description,
  });
}

class MemberHome {
  final String memberName;
  final String role;
  final String voiceSection;
  final String branchName;
  final int joinYear;
  final String mapUrl;
  final Color color;
  final double lat;
  final double lng;
  final String? bio;

  const MemberHome({
    required this.memberName,
    required this.role,
    required this.voiceSection,
    required this.branchName,
    required this.joinYear,
    required this.mapUrl,
    required this.color,
    required this.lat,
    required this.lng,
    this.bio,
  });
}

class Venue {
  final String city;
  final String country;
  final String date;
  final DateTime sortDate;
  final double lat;
  final double lng;
  final String event;
  final String notes;

  const Venue({
    required this.city,
    required this.country,
    required this.date,
    required this.sortDate,
    required this.lat,
    required this.lng,
    required this.event,
    required this.notes,
  });
}

class MapData {
  static const Color tripoliColor = AppColors.accentDark;
  static const Color beirutColor = AppColors.secondary;
  static const Color aleyColor = AppColors.primary;
  static const Color choufColor = Color(0xFF6B5582);

  static Color colorFor(String branch) {
    switch (branch.toLowerCase()) {
      case 'tripoli': return tripoliColor;
      case 'beirut': return beirutColor;
      case 'aley': return aleyColor;
      case 'chouf': return choufColor;
      default: return AppColors.gray;
    }
  }

  static const List<BranchLocation> branches = [
    BranchLocation(
      name: 'Tripoli',
      practiceLocation: 'Mina, Tripoli',
      mapUrl: 'https://maps.app.goo.gl/4hnRQwq9reAvGjfz6',
      color: tripoliColor,
      lat: 34.4534215,
      lng: 35.8145463,
      yearOpened: 2003,
      conductor: 'Maestro Barkev Taslakian',
      membersApprox: 60,
      rehearsalSchedule: 'Thu · Fri · Sat — 6:00–9:00 PM',
      description:
          'The founding branch. Established by Maestro Barkev Taslakian in 2003, it gave the choir its name — \'Fayha\' meaning fragrant, after the orange groves surrounding the city.',
    ),
    BranchLocation(
      name: 'Beirut',
      practiceLocation: 'American University of Beirut (AUB)',
      mapUrl: 'https://maps.app.goo.gl/n5GwmvnWTEfXaHn38',
      color: beirutColor,
      lat: 33.9024626,
      lng: 35.4821829,
      yearOpened: 2015,
      conductor: 'Maestro Barkev Taslakian',
      membersApprox: 50,
      rehearsalSchedule: 'Mon · Tue · Wed — 6:00–9:00 PM',
      description:
          'Hosted at AUB\'s historic campus. The Beirut branch brought Fayha to the capital and helped expand the choir\'s reach to a younger generation of singers.',
    ),
    BranchLocation(
      name: 'Aley',
      practiceLocation: 'Aley',
      mapUrl: 'https://maps.app.goo.gl/jNeMQbe1MdiLv8Ys9',
      color: aleyColor,
      lat: 33.8027187,
      lng: 35.6095478,
      yearOpened: 2022,
      conductor: 'Section conductor',
      membersApprox: 25,
      rehearsalSchedule: 'Wed · Thu · Fri — 6:00–9:00 PM',
      description:
          'Opened in 2022 as part of the nationwide expansion that earned Fayha its designation as the first Lebanese National Choir.',
    ),
    BranchLocation(
      name: 'Chouf',
      practiceLocation: 'Chouf',
      mapUrl: 'https://maps.app.goo.gl/ZCHSTUepHB87MQVdA',
      color: choufColor,
      lat: 33.6712154,
      lng: 35.5997846,
      yearOpened: 2022,
      conductor: 'Section conductor',
      membersApprox: 20,
      rehearsalSchedule: 'Mon · Tue · Wed — 6:00–9:00 PM',
      description:
          'The Chouf branch, opened alongside Aley in 2022, brings collective singing to the mountains south-east of Beirut.',
    ),
  ];

  static const List<MemberHome> memberHomes = [
    MemberHome(
      memberName: 'Roy Bilain',
      role: 'Member',
      voiceSection: 'Tenor 2',
      branchName: 'Tripoli',
      joinYear: 2019,
      mapUrl: 'https://maps.app.goo.gl/rzHfsQcBwYKWeLjh7',
      color: tripoliColor,
      lat: 34.4516745,
      lng: 35.8121094,
      bio: 'Full-stack developer by day, Tenor 2 in the Tripoli branch by night. Joined Fayha in 2019.',
    ),
    MemberHome(
      memberName: 'Maestro Barkev Taslakian',
      role: 'Founder · Principal Conductor',
      voiceSection: 'Tenor 1',
      branchName: 'Tripoli',
      joinYear: 2003,
      mapUrl: 'https://maps.app.goo.gl/wUGJShgcUzbxnTPa7',
      color: tripoliColor,
      lat: 34.3880239,
      lng: 35.8404634,
      bio: 'Founded Fayha National Choir in 2003. Has shaped Arabic a cappella into an internationally recognized artform and trained dozens of conductors across the Arab region.',
    ),
    MemberHome(
      memberName: 'Amir Chehayeb',
      role: 'Member',
      voiceSection: 'Bass 1',
      branchName: 'Beirut',
      joinYear: 2021,
      mapUrl: 'https://maps.app.goo.gl/pBX8UyupLfrXajEx5',
      color: beirutColor,
      lat: 33.8088361,
      lng: 35.61156,
      bio: 'Bass 1 in the Beirut branch. Joined Fayha in 2021.',
    ),
  ];

  static final List<Venue> venues = [
    Venue(
      city: 'AlUla',
      country: 'Saudi Arabia',
      date: 'April 2025',
      sortDate: DateTime(2025, 4, 1),
      lat: 26.6087,
      lng: 37.9226,
      event: 'Heritage Concert',
      notes:
          'Performance in the UNESCO World Heritage site of AlUla, bringing Arabic a cappella to one of the region\'s most iconic cultural landscapes.',
    ),
    Venue(
      city: 'Doha',
      country: 'Qatar',
      date: 'December 2024',
      sortDate: DateTime(2024, 12, 1),
      lat: 25.2854,
      lng: 51.5310,
      event: 'Doha Cultural Festival',
      notes:
          'Invited performance featuring signature pieces from the choir\'s repertoire of Arabic classics.',
    ),
    Venue(
      city: 'Damascus',
      country: 'Syria',
      date: 'June 2023',
      sortDate: DateTime(2023, 6, 1),
      lat: 33.5138,
      lng: 36.2765,
      event: 'Solidarity Concert',
      notes:
          'Performance in Damascus celebrating shared Arabic musical heritage across the region.',
    ),
    Venue(
      city: 'Istanbul',
      country: 'Turkey',
      date: 'April 2023',
      sortDate: DateTime(2023, 4, 1),
      lat: 41.0082,
      lng: 28.9784,
      event: 'World Symposium on Choral Music',
      notes:
          'Invited choir at the World Symposium on Choral Music, organized by the International Federation for Choral Music — one of the most prestigious gatherings in the choral world.',
    ),
  ];
}
