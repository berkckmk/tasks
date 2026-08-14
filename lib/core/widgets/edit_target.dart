import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_spacing.dart';
import 'app_button.dart';
import 'error_state.dart';

/// Resolves the single item an "edit X" screen is editing, out of the list
/// stream that screen already watches.
///
/// The problem this exists to prevent: those screens used to scan the list
/// with `maybeWhen(data: ..., orElse: () => const [])`, which collapses
/// *loading* and *error* into "empty list". The item was then not found,
/// `existing` stayed null, and the save button — which passes
/// `id: existing?.id` — silently took the **create** path. The user got an
/// empty form titled "Edit habit", filled it in, and ended up with a second
/// habit (also consuming a plan slot).
///
/// It's reachable in normal use, not just in theory: these routes sit on the
/// root navigator, so a web deep-link or page refresh on `/habits/{id}/edit`
/// builds the screen before the collection stream has emitted anything.
///
/// [EditTarget.resolve] never guesses. It reports loading, missing, or
/// failed, and only hands back an item when there genuinely is one.
sealed class EditTarget<T> {
  const EditTarget();

  /// Resolves [id] against [async]. Pass a null [id] for a create screen.
  static EditTarget<T> resolve<T>({
    required String? id,
    required AsyncValue<List<T>> async,
    required String Function(T item) idOf,
  }) {
    if (id == null) return const EditTargetCreating();

    return async.when(
      data: (items) {
        for (final item in items) {
          if (idOf(item) == id) return EditTargetFound(item);
        }
        return const EditTargetMissing();
      },
      // `skipLoadingOnReload: false` is the default, so a refresh after an
      // edit keeps showing the previous value rather than flashing a
      // spinner — but a genuinely first load still lands here.
      loading: () => const EditTargetLoading(),
      error: (error, _) => EditTargetFailed(error),
    );
  }
}

/// No id was given — this is a "new item" screen.
class EditTargetCreating<T> extends EditTarget<T> {
  const EditTargetCreating();
}

class EditTargetLoading<T> extends EditTarget<T> {
  const EditTargetLoading();
}

class EditTargetFound<T> extends EditTarget<T> {
  const EditTargetFound(this.item);
  final T item;
}

/// Loaded successfully, but nothing with that id — deleted on another
/// device, or a stale/bookmarked link.
class EditTargetMissing<T> extends EditTarget<T> {
  const EditTargetMissing();
}

class EditTargetFailed<T> extends EditTarget<T> {
  const EditTargetFailed(this.error);
  final Object error;
}

/// Full-screen placeholder shown while an edit target is still resolving.
class EditTargetLoadingScreen extends StatelessWidget {
  const EditTargetLoadingScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Full-screen placeholder for an edit target that doesn't exist (or failed
/// to load). Deliberately offers no save action — the whole point is that
/// this screen can't quietly become a create form.
class EditTargetMissingScreen extends StatelessWidget {
  const EditTargetMissingScreen({
    super.key,
    required this.title,
    required this.message,
    this.error,
  });

  final String title;
  final String message;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: error != null
              ? ErrorState(error: error!)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Go back',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
