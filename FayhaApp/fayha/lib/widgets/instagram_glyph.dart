import 'package:flutter/material.dart';

/// Hand-drawn Instagram glyph: rounded square + lens circle + top-right dot.
/// Avoids a 3rd-party icon package dependency.
class InstagramGlyph extends StatelessWidget {
  final Color color;
  final double size;
  const InstagramGlyph({super.key, required this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final stroke = size * 0.09;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              border: Border.all(color: color, width: stroke),
            ),
          ),
          Container(
            width: size * 0.46,
            height: size * 0.46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: stroke),
            ),
          ),
          Positioned(
            top: size * 0.18,
            right: size * 0.18,
            child: Container(
              width: size * 0.11,
              height: size * 0.11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
