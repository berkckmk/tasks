import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_type.dart';
import '../constants/app_icons.dart';
import '../constants/app_spacing.dart';

/// The circle toggle every list item carries on its left — reminder, task,
/// habit alike.
///
/// This is **one interaction shared by the app and the home-screen widget**,
/// which is what makes the two read as the same product. The rules, in full:
///
///  - Unchecked: Phosphor `circle`, `text` at 32%.
///  - Checked: Phosphor `check-circle` **Fill**, `accent`.
///  - A checked row drops to 45% opacity, its title gets a line-through, and
///    it sorts to the bottom of its list until midnight.
///
/// The glyph is 15–20px depending on the list, but the **hit target stays
/// ≥44dp** — that is why this pads out to a fixed box rather than sizing to
/// the icon.
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    this.onChanged,
    this.size = 18,
    this.semanticLabel,

    /// Draws a ring of the page ground behind the glyph, so a toggle sitting
    /// *on* the time rail punches through the line rather than being crossed
    /// by it. `2b` only.
    this.punchThrough = false,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final double size;
  final String? semanticLabel;
  final bool punchThrough;

  static const double hitTarget = 44;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    Widget glyph = Icon(
      checked ? AppIcons.checkCircleFill : AppIcons.circle,
      size: size,
      color: checked ? c.accent : c.unchecked,
    );

    if (punchThrough) {
      glyph = DecoratedBox(
        // A 4px ring of the ground, per the spec — not a border on the glyph.
        decoration: BoxDecoration(
          color: c.bg,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: c.bg, blurRadius: 0, spreadRadius: 4)],
        ),
        child: glyph,
      );
    }

    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: SizedBox(
        width: hitTarget,
        height: hitTarget,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged!(!checked),
            customBorder: const CircleBorder(),
            splashColor: c.accentTint(0.14),
            highlightColor: c.accentTint(0.08),
            child: Center(child: glyph),
          ),
        ),
      ),
    );
  }
}

/// Applies the completed treatment to a row: 45% opacity and a line-through
/// on the title.
///
/// Wrapping rather than restating it per screen is what keeps the three lists
/// consistent — the old app had a different fade on each.
class CompletedRow extends StatelessWidget {
  const CompletedRow({super.key, required this.completed, required this.child});

  final bool completed;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      completed ? Opacity(opacity: 0.45, child: child) : child;
}

/// A section label — `h6` in the design system. 9–11px, uppercase,
/// +0.10–0.13em, in `inkAccent` unless told otherwise.
///
/// Uppercasing happens here because Flutter has no text-transform, and doing
/// it at each call site is how "TODAY" and "Today" end up on the same screen.
class Kicker extends StatelessWidget {
  const Kicker(this.label, {super.key, this.color, this.small = false});

  final String label;
  final Color? color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Text(
      label.toUpperCase(),
      style: (small ? AppType.kickerSmall : AppType.kicker).copyWith(
        color: color ?? c.inkAccent,
      ),
    );
  }
}

/// Nocturne's `.hr`: a hairline that fades out at both ends instead of
/// stopping dead.
///
/// A full-bleed 1px line on a dark ground reads as a hard edge across the
/// screen; fading the last 24px makes it read as a separation. `2b` uses this
/// between profile setting rows and under `2c`'s hero.
class FadingRule extends StatelessWidget {
  const FadingRule({
    super.key,
    this.height = 1,
    this.fade = 0.18,
    this.color,
  });

  final double height;

  /// How much of each end fades, as a fraction of the width.
  final double fade;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final line = color ?? c.divider;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            stops: [0, fade, 1 - fade, 1],
            colors: [line.withValues(alpha: 0), line, line, line.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// A full-width segmented control.
///
/// The selected option is drawn with an **inset 1px accent ring**, not a
/// filled block — the accent is a line. The first and last options take the
/// container's own corner radius, because a square ring painted inside a
/// rounded box shows two mismatched corners at each end; that is a real bug
/// this control had in the mocks before it was specified.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    final outer = BorderRadius.circular(AppSpacing.radiusMd);
    final entries = segments.entries.toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: outer,
        border: Border.all(color: c.divider),
      ),
      child: ClipRRect(
        borderRadius: outer,
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              for (var i = 0; i < entries.length; i++)
                Expanded(
                  child: _Segment(
                    label: entries[i].value,
                    selected: entries[i].key == value,
                    onTap: () => onChanged(entries[i].key),
                    // Only the ends round; the ring on an interior segment is
                    // square on both sides and correct that way.
                    radius: BorderRadius.horizontal(
                      left: i == 0
                          ? const Radius.circular(AppSpacing.radiusMd)
                          : Radius.zero,
                      right: i == entries.length - 1
                          ? const Radius.circular(AppSpacing.radiusMd)
                          : Radius.zero,
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

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.radius,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return InkWell(
      onTap: onTap,
      splashColor: c.accentTint(0.12),
      highlightColor: c.accentTint(0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 1),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: selected ? Border.all(color: c.accent) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppType.meta.copyWith(
            fontSize: 12.5,
            color: selected ? c.inkAccent : c.muted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// The note under a row title — a reminder's `message` or a task's
/// `description`.
///
/// These two fields are the whole point of the redesign ("reminder-first"),
/// and they were previously hidden or truncated to nothing. There is no new
/// Notes feature; "notes" means exactly these.
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key, this.maxLines});

  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: AppType.note.copyWith(color: c.note),
    );
  }
}

/// A right-aligned time in the fixed gutter.
///
/// The width is fixed and the figures are tabular; without both the column
/// ragged-edges by a pixel or two per row, which on a rail with a vertical
/// line running down it is immediately visible.
class TimeGutter extends StatelessWidget {
  const TimeGutter(
    this.label, {
    super.key,
    this.width = 40,
    this.color,
    this.style,
  });

  final String label;
  final double width;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: (style ?? AppType.metaSmall).copyWith(color: color ?? c.caption),
      ),
    );
  }
}

/// A ghost icon button — the search and sign-out affordances beside a screen
/// title. No fill, no edge; the accent ramp carries the pressed state.
class GhostIconButton extends StatelessWidget {
  const GhostIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 20,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: c.accentTint(0.14),
          highlightColor: c.accentTint(0.08),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: size, color: color ?? c.muted),
          ),
        ),
      ),
    );
  }
}
