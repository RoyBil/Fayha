import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? photoUrl;
  const Avatar({
    super.key,
    required this.name,
    this.size = 44,
    this.background,
    this.foreground,
    this.photoUrl,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1)
      return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.4),
          width: 1.5,
        ),
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: foreground ?? AppColors.cream,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.36,
                letterSpacing: 0.5,
              ),
            ),
    );
  }
}
