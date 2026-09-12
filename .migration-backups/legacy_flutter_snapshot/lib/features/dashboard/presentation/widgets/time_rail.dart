import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_type.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/nocturne.dart';
import '../../application/today_providers.dart';

/// Geometry of the `2b` time rail. These four numbers are the design, and
/// they are related — changing one without the others breaks the alignment
/// the rail exists for.
class RailMetrics {
  RailMetrics._();

  /// The vertical hairline sits at this x, measured from the start of the
  /// screen's content box.
  static const double lineX = 47;

  /// The time column: right-aligned, tabular, fixed width. Fixed because a
  /// proportional column ragged-edges by a pixel or two per row, which is
  /// invisible in a plain list and obvious against a vertical line.
  static const double gutterWidth = 40;

  /// Where an entry's own content starts. Clear of both the gutter and the
  /// toggle glyph.
  static const double contentX = 66;

  /// How far the line fades in at the top and out at the bottom, so it reads
  /// as a continuing day rather than a bar with two hard ends.
  static const double fade = 24;

  /// The check circle in the rail — small, because the line is the structure
  /// and the toggle sits on it rather than leading it.
  static const double toggleGlyph = 15;
}

/// The rail's vertical hairline.
///
/// A `1px column at x = 47 fading to transparent at both ends over 24px`. Sits
/// behind the rows in a [Stack] and stretches to whatever the column's final
/// height turns out to be.
class RailLine extends StatelessWidget {
  const RailLine({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Positioned(
      left: RailMetrics.lineX,
      top: 0,
      bottom: 0,
      width: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The fade is a fixed 24px, so as a gradient stop it has to be
          // expressed against the actual height rather than as a constant
          // fraction — otherwise a short day fades the whole line away.
          final height = constraints.maxHeight;
          final stop = height <= 0
              ? 0.0
              : (RailMetrics.fade / height).clamp(0.0, 0.5);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, stop, 1 - stop, 1],
                colors: [
                  c.divider.withValues(alpha: 0),
                  c.divider,
                  c.divider,
                  c.divider.withValues(alpha: 0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One entry on the rail.
///
/// Everything is flush text against the line; only the next-up entry is raised
/// into a card (see [RailNextUpCard]). That contrast is what makes "next" read
/// as next without a badge or a colour.
class RailEntry extends StatelessWidget {
  const RailEntry({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onTap,
  });

  final TodayEntry entry;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return CompletedRow(
      completed: entry.done,
      child: _RailRow(
        time: entry.time,
        onTap: onTap,
        checked: entry.done,
        onToggle: onToggle,
        semanticLabel: entry.title,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: AppType.title.copyWith(
                  color: c.text,
                  decoration: entry.done ? TextDecoration.lineThrough : null,
                  decorationColor: c.text,
                ),
              ),
              // The note, inline. Not truncated to a single line and not
              // hidden behind a tap — surfacing these is the point.
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                NoteText(entry.note),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The next incomplete entry, raised out of the rail.
///
/// A `surface` card at `shadow-md`, offset −8px so it visibly breaks the
/// column, carrying the only two actions on the screen: Done and Snooze.
/// [onSnooze] is null for a task or a habit — neither has an instant to move —
/// and the button is simply absent rather than present and inert.
class RailNextUpCard extends StatelessWidget {
  const RailNextUpCard({
    super.key,
    required this.entry,
    required this.onDone,
    required this.onSnooze,
    required this.onTap,
  });

  final TodayEntry entry;
  final VoidCallback onDone;
  final VoidCallback? onSnooze;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return _RailRow(
      time: entry.time,
      onTap: onTap,
      checked: false,
      onToggle: (_) => onDone(),
      semanticLabel: entry.title,
      child: Transform.translate(
        offset: const Offset(0, -8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: c.edgeMd),
              boxShadow: c.shadowMd,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: AppType.h5.copyWith(fontSize: 16, color: c.text),
                  ),
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    NoteText(entry.note),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _CardAction(
                        label: 'Done',
                        accent: true,
                        onPressed: onDone,
                      ),
                      if (onSnooze != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _CardAction(label: 'Snooze', onPressed: onSnooze!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final tone = accent ? c.accent : c.muted;
    final radius = BorderRadius.circular(AppSpacing.radiusSm);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: accent ? c.accent : c.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          splashColor: c.accentTint(0.14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: AppType.meta.copyWith(
                fontSize: 12.5,
                color: tone,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The now-line: where the current moment falls on the rail.
///
/// An accent dot with a `0 0 0 4px accent@22%` halo sitting on the line, and a
/// hairline fading away to the right. It is inserted immediately above the
/// next incomplete entry, which is exactly where "now" is — everything above
/// it has passed.
class RailNowLine extends StatelessWidget {
  const RailNowLine({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Semantics(
      label: 'Now, ${DateFormat.jm().format(now)}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 1,
                child: TimeGutter(
                  DateFormat.jm().format(now),
                  width: RailMetrics.gutterWidth,
                  color: c.accent,
                ),
              ),
              // The hairline runs from the dot to the right edge and fades
              // out — it marks the moment, it doesn't rule the row off.
              Positioned(
                left: RailMetrics.lineX + 5,
                right: 0,
                top: 6.5,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.accent.withValues(alpha: 0.55),
                        c.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: RailMetrics.lineX - 3,
                top: 4,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.22),
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group heading on the rail — "Anytime", or a date on the Reminders
/// screen. Sits in the content column, clear of the line.
class RailGroupHeading extends StatelessWidget {
  const RailGroupHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: RailMetrics.contentX,
        bottom: AppSpacing.sm,
      ),
      child: Kicker(label),
    );
  }
}

/// The shared row skeleton: time on the left, toggle on the line, content to
/// the right.
///
/// A [Stack] rather than a [Row] because the toggle's ≥44dp hit target is
/// wider than the 7px of space between the gutter and the line. Laying it out
/// in flow would push the content column right and break the alignment; here
/// the glyph stays centred on the line and only the touch area overhangs.
class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.time,
    required this.child,
    required this.onTap,
    required this.checked,
    required this.onToggle,
    required this.semanticLabel,
  });

  final DateTime? time;
  final Widget child;
  final VoidCallback onTap;
  final bool checked;
  final ValueChanged<bool> onToggle;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: RailMetrics.contentX),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              splashColor: c.accentTint(0.10),
              highlightColor: c.accentTint(0.05),
              child: child,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 1,
          child: TimeGutter(
            time == null ? '' : DateFormat.jm().format(time!),
            width: RailMetrics.gutterWidth,
          ),
        ),
        Positioned(
          // Centres the 44dp hit box on the line.
          left: RailMetrics.lineX - CheckCircle.hitTarget / 2,
          top: -11,
          child: CheckCircle(
            checked: checked,
            onChanged: onToggle,
            size: RailMetrics.toggleGlyph,
            semanticLabel: semanticLabel,
            // Punches a ring of the page ground through the line so the
            // toggle sits *on* the rail rather than being crossed by it.
            punchThrough: true,
          ),
        ),
      ],
    );
  }
}
