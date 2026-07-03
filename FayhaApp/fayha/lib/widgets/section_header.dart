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
    final titleColor = light ? AppColors.cream : AppColors.dark;
    final subtitleColor = light ? AppColors.lightGray : AppColors.gray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: eyebrowColor),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: titleColor, height: 1.15),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: subtitleColor, height: 1.5),
          ),
        ],
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(top: 10),
          height: 2,
          width: 48,
          color: AppColors.accent,
        ),
      ],
    );
  }
}
