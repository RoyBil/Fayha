import 'package:flutter/material.dart';
import '../data/choir_data.dart';
import '../data/mock_data.dart';
import '../services/audience_data.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late Future<List<Achievement>> _achievements;
  late Future<List<SocialProject>> _projects;

  @override
  void initState() {
    super.initState();
    _achievements = AudienceData.fetchAchievements();
    _projects = AudienceData.fetchSocialProjects();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
        const SectionHeader(
          eyebrow: 'Our Story',
          title: 'Voices of Lebanon',
          subtitle: 'Founded in Tripoli, sung across the world.',
        ),
        const SizedBox(height: 20),
        Text(
          ChoirData.storyFull,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
        ),
        const SizedBox(height: 40),

        const SectionHeader(
          eyebrow: 'Recognition',
          title: 'Achievements',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Achievement>>(
          future: _achievements,
          builder: (context, snap) {
            final items = snap.data ?? const <Achievement>[];
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              children: items.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElegantCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.year.toString(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(a.event, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 40),

        const SectionHeader(
          eyebrow: 'Impact',
          title: 'Our Social Projects',
          subtitle:
              'Building peace and cohesion through collective singing — recognized by the International Music Council\'s Music Rights Award in 2015.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<SocialProject>>(
          future: _projects,
          builder: (context, snap) {
            final items = snap.data ?? const <SocialProject>[];
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              children: items.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElegantCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(p.name, style: theme.textTheme.titleLarge),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p.period,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.secondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(p.description,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                    ],
                  ),
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 40),

        const SectionHeader(
          eyebrow: 'Leadership',
          title: 'Maestro & Management',
        ),
        const SizedBox(height: 16),
        ElegantCard(
          child: Column(
            children: [
              Row(
                children: [
                  Avatar(name: ChoirData.presidentName, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ChoirData.presidentName, style: theme.textTheme.titleLarge),
                        Text(ChoirData.presidentTitle,
                            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(MockData.maestroBio,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElegantCard(
          child: Column(
            children: [
              Row(
                children: [
                  Avatar(name: ChoirData.managerName, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ChoirData.managerName, style: theme.textTheme.titleLarge),
                        Text(ChoirData.managerTitle,
                            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(MockData.managerBio,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
            ],
          ),
        ),
        const SizedBox(height: 40),

        const SectionHeader(
          eyebrow: 'Global',
          title: 'Affiliations',
        ),
        const SizedBox(height: 16),
        ElegantCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AffiliationRow(text: 'Co-founder of the Arab Choral Network'),
              const SizedBox(height: 12),
              _AffiliationRow(text: 'Member of the International Federation for Choral Music'),
              const SizedBox(height: 12),
              _AffiliationRow(text: 'Collaborations with the European Choral Association'),
              const SizedBox(height: 12),
              _AffiliationRow(
                text:
                    'Organizer of the Lebanese International Choir Festival (2015 & 2017) — 1,000+ participants from 8 countries',
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

class _AffiliationRow extends StatelessWidget {
  final String text;
  const _AffiliationRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
