import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ElegantCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? background;
  // When true: shadow instead of border (for interactive / floating cards).
  // Default false: border only, no shadow.
  final bool elevated;

  const ElegantCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.background,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: elevated ? null : Border.all(color: AppColors.offWhite),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: AppColors.dark.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
