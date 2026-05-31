import 'package:flutter/material.dart';

/// A subtle Fayha-logo watermark behind the screen content.
///
/// Drop this around any `Scaffold` body that would otherwise have a
/// blank cream/white background. The logo sits centered, low-opacity,
/// and never intercepts taps.
class BrandedBackground extends StatelessWidget {
  final Widget child;

  /// Watermark opacity. The default is gentle enough to stay tasteful.
  final double opacity;

  /// Watermark width as a fraction of the available width.
  final double widthFraction;

  /// Maximum absolute width in logical pixels (caps the watermark on
  /// tablets / desktop windows).
  final double maxWidth;

  const BrandedBackground({
    super.key,
    required this.child,
    this.opacity = 0.08,
    this.widthFraction = 0.72,
    this.maxWidth = 460,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w =
                    (constraints.maxWidth * widthFraction).clamp(120.0, maxWidth);
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Image.asset(
                      'assets/logo/logo_light.png',
                      width: w,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}
