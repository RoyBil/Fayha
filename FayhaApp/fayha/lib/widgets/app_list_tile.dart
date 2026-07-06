import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppListTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? badge;
  final bool destructive;
  final Widget? trailing;

  const AppListTile({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBackground,
    required this.title,
    this.subtitle,
    this.onTap,
    this.badge,
    this.destructive = false,
    this.trailing,
  });

  static const _errorColor = Color(0xFFB23A48);

  @override
  Widget build(BuildContext context) {
    final color = destructive ? _errorColor : (iconColor ?? AppColors.primary);
    final bg =
        iconBackground ??
        (destructive
            ? _errorColor.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.08));

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: destructive ? _errorColor : AppColors.dark,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12))
          : null,
      trailing: (badge != null && badge! > 0)
          ? _Badge(badge!)
          : (trailing ??
                Icon(
                  Icons.chevron_right,
                  color: destructive ? _errorColor : AppColors.gray,
                )),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: AppColors.cream,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
