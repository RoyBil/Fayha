import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool light;

  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final eyebrowColor = light ? AppColors.accentLight : AppColors.accentDark;
    final eyebrowBg = light
        ? AppColors.accentLight.withValues(alpha: 0.15)
        : AppColors.accent.withValues(alpha: 0.12);
    final titleColor = light ? AppColors.cream : AppColors.dark;
    final subtitleColor = light ? AppColors.lightGray : AppColors.gray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow pill replaces the old plain text + 2px bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: eyebrowBg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: eyebrowColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: titleColor, height: 1.15),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: subtitleColor, height: 1.5),
          ),
        ],
      ],
    );
  }
}
