import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The progress ring — the mark the whole product is built around.
///
/// This is the same arc three times over: here on Today, on the home-screen
/// widget, and as the app icon. Keeping the geometry identical across all
/// three is what makes them read as one thing, so the numbers below are the
/// spec, not defaults to taste: **64px box, r = 27, stroke 6, round cap,
/// rotated −90° so the arc starts at twelve o'clock**, track in `divider`,
/// arc in `accent`.
///
/// Drawn with a painter rather than a `CircularProgressIndicator`: that widget
/// insets its stroke by its own rules, so the radius it actually paints is not
/// the radius you ask for, and the ring stopped matching the icon.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.strokeWidth = 6,
    this.color,
    this.trackColor,
    this.label,
    this.labelStyle,
  });

  /// 0.0 – 1.0.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  /// The mocks put the fraction *beside* the ring rather than inside it, so
  /// this is null in the redesign. Kept for the goal cards, which still
  /// centre a percentage.
  final String? label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: clamped,
          strokeWidth: strokeWidth,
          arc: color ?? c.accent,
          track: trackColor ?? c.divider,
        ),
        child: label == null
            ? null
            : Center(
                child: Text(
                  label!,
                  style:
                      labelStyle ??
                      TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w500,
                        color: c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        decoration: TextDecoration.none,
                      ),
                ),
              ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.arc,
    required this.track,
  });

  final double progress;
  final double strokeWidth;
  final Color arc;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    // r = 27 in a 64 box, i.e. the stroke sits fully inside the box with a
    // 2px margin. Expressed as a ratio so a differently sized ring keeps the
    // same proportions rather than clipping its cap.
    final radius = size.shortestSide * (27 / 64);
    final centre = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;

    canvas.drawCircle(centre, radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arc;

    // −90°: twelve o'clock, not three.
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.arc != arc ||
      old.track != track;
}
