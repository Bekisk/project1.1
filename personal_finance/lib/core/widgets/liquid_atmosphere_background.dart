import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';

/// Atmospheric Screen Background with dark emerald base, soft radial teal glow,
/// and subtle Apple Liquid Glass ambient depth.
class LiquidAtmosphereBackground extends StatelessWidget {
  final Widget child;

  const LiquidAtmosphereBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Container(color: AppTheme.bgLight, child: child);
    }

    return Stack(
      children: [
        // 1. Pure black and subtle secondary black background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.pureBlack,
                AppTheme.secondaryBlack,
                AppTheme.pureBlack,
              ],
            ),
          ),
        ),

        // 2. Subtle decorative geometric grid lines in monochrome
        Positioned.fill(child: CustomPaint(painter: _SubtleGridPainter())),

        // Content
        child,
      ],
    );
  }
}

class _SubtleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF292929).withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 48.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
