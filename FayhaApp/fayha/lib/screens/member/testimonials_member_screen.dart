import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';

class TestimonialsMemberScreen extends StatelessWidget {
  const TestimonialsMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approved = MockData.testimonials
        .where((t) => t.status == TestimonialStatus.approved)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Testimonials')),
      body: approved.isEmpty
          ? const Center(child: Text('No testimonials yet.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: approved.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TestimonialCard(t: approved[i]),
            ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final Testimonial t;
  const _TestimonialCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: t.author, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.author, style: theme.textTheme.titleMedium),
                    Text(
                      t.voiceSection,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 3),
              ),
            ),
            child: Text(
              t.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
