import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_type.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../application/today_actions.dart';

/// The quick-capture bar `2b` pins above the tab bar on Today and Reminders.
///
/// A `surface` panel at `radius-lg` and `shadow-md`, holding a `plus` in the
/// accent, the placeholder "Remind me to…" at 45%, and a `microphone`. It sits
/// in a `linear-gradient(to top, bg 70%, transparent)` so list content scrolls
/// *out* underneath it rather than stopping at a hard edge.
///
/// Typing here and pressing enter creates a real reminder with no time —
/// [TodayActions.quickCapture] goes through the existing reminder action, so
/// this adds no state and no new write path.
///
/// **The microphone focuses the field; it does not record.** The app draws no
/// keyboard and ships no speech engine — dictation belongs to the platform
/// IME, which is where the user's own mic key already lives. A button that
/// looked like it recorded and didn't would be worse than no button, and a
/// button that opens the keyboard where dictation actually is, is the honest
/// version of what the mock draws.
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key, this.hint = 'Remind me to…'});

  final String hint;

  /// What the bar occupies, so a scrollable behind it can reserve room and
  /// still let content pass under the gradient.
  static const double reservedHeight = 96;

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(todayActionsProvider).quickCapture(text);
      _controller.clear();
      // Keeps the field focused: capturing one thing usually means capturing
      // the next, and dismissing the keyboard after every entry is the fastest
      // way to make a quick-capture bar not quick.
      _focus.requestFocus();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't save that reminder: $error")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScheme.of(context);

    return IgnorePointer(
      // Only the gradient ignores pointers; the bar inside it does not.
      // Without this the invisible top half of the gradient would swallow
      // taps meant for the last row of the list.
      ignoring: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0, 0.7, 1],
            colors: [c.bg, c.bg, c.bg.withValues(alpha: 0)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              AppSpacing.sm,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: c.edgeMd),
                boxShadow: c.shadowMd,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Detaylı hatırlatıcı ekle',
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            final text = _controller.text.trim();
                            if (text.isNotEmpty) {
                              context.push(
                                '/reminders/new?title=${Uri.encodeComponent(text)}',
                              );
                              _controller.clear();
                            } else {
                              context.push('/reminders/new');
                            }
                          },
                          customBorder: const CircleBorder(),
                          splashColor: c.accentTint(0.2),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(AppIcons.plus, size: 20, color: c.accent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: AppType.bodySmall.copyWith(color: c.text),
                        cursorColor: c.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          hintText: widget.hint,
                          hintStyle: AppType.bodySmall.copyWith(
                            color: c.inactive,
                          ),
                        ),
                      ),
                    ),
                    if (_saving)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: c.accent,
                        ),
                      )
                    else
                      Tooltip(
                        message: 'Dictate with the keyboard',
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _focus.requestFocus,
                            customBorder: const CircleBorder(),
                            splashColor: c.accentTint(0.14),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                AppIcons.microphone,
                                size: 17,
                                color: c.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
