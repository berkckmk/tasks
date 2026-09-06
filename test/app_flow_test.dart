import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_progress/app/app.dart';
import 'package:steady_progress/core/widgets/responsive_scaffold.dart';
import 'package:steady_progress/features/subscription/domain/beta_access.dart';

import 'support/fakes.dart';

/// Exercises the full authenticated shell against a fake, pre-seeded
/// Firebase backend.
///
/// These assert on *seeded content* — a habit's name, a task's title — not on
/// AppBar/nav labels. The previous version checked `find.text('Habits')`,
/// which matches the navigation destination and so passed even when the list
/// itself had failed to load and rendered an ErrorState.
void main() {
  Future<void> pumpApp(WidgetTester tester, TestBackend backend) async {
    // No wrapper any more. main.dart used to wrap the app in
    // LiquidGlassWidgets.wrap(), so tests had to supply a
    // GlassAccessibilityScope with reduceTransparency (no GPU here to run the
    // shader on) and reduceMotion (so pumpAndSettle terminated against the
    // spring animations). Nocturne draws flat panels — neither applies.
    await tester.pumpWidget(
      ProviderScope(
        overrides: backend.overrides,
        child: const SteadyProgressApp(),
      ),
    );
    // Splash -> (signed in) -> Reminders, which is now tab 0.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  /// Taps one of the four bottom-bar destinations: Reminders, Today, Tasks,
  /// More.
  ///
  /// Scoped to the bar on purpose: several of these labels are also body text
  /// on the screen they open, so a bare find.text would be ambiguous the
  /// moment a tab is already selected.
  Future<void> goToTab(WidgetTester tester, String label) async {
    await tester.tap(
      find
          .descendant(of: find.byType(AppTabBar), matching: find.text(label))
          .first,
    );
    await tester.pumpAndSettle();
  }

  /// Taps a row on the More screen, scrolling to it first.
  ///
  /// More grew when Habits and Profile moved into it, so its last rows are
  /// now below the fold — and a `ListView` doesn't build off-screen children,
  /// so `find.text` returns nothing rather than something off-screen. The
  /// scroll is what makes the row exist.
  Future<void> tapMoreRow(WidgetTester tester, String label) async {
    final rowFinder = find.descendant(
      of: find.byType(ListView),
      matching: find.text(label),
    );
    await tester.scrollUntilVisible(
      rowFinder,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(rowFinder);
    await tester.pumpAndSettle();
  }

  /// Habits and Profile lost their tab slots in the redesign — they are push
  /// routes off More now, so reaching them is two taps rather than one.
  Future<void> goToMoreRow(WidgetTester tester, String label) async {
    await goToTab(tester, 'More');
    await tapMoreRow(tester, label);
  }

  testWidgets(
    'one-week seeded data is stored in the fake database and renders the core tabs',
    (WidgetTester tester) async {
      final backend = await TestBackend.signedIn(planId: 'complete');
      await backend.seedOneWeekPlan();

      final habitDocs = await backend.firestore
          .collection('users')
          .doc(backend.uid)
          .collection('habits')
          .get();
      final taskDocs = await backend.firestore
          .collection('users')
          .doc(backend.uid)
          .collection('tasks')
          .get();
      final reminderDocs = await backend.firestore
          .collection('users')
          .doc(backend.uid)
          .collection('reminders')
          .get();

      expect(habitDocs.docs.length, greaterThanOrEqualTo(3));
      expect(taskDocs.docs.length, greaterThanOrEqualTo(3));
      expect(reminderDocs.docs.length, greaterThanOrEqualTo(3));

      await pumpApp(tester, backend);
      expect(tester.takeException(), isNull);

      await goToTab(tester, 'Habits');
      expect(find.text('Morning run'), findsWidgets);
      expect(tester.takeException(), isNull);

      await goToTab(tester, 'Tasks');
      expect(find.text('Plan the week'), findsWidgets);
      expect(tester.takeException(), isNull);

      await goToTab(tester, 'Reminders');
      expect(find.text('Morning planning'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every Complete-plan module opens without an upgrade gate', (
    WidgetTester tester,
  ) async {
    final backend = await TestBackend.signedIn(planId: 'complete');
    await pumpApp(tester, backend);

    await goToTab(tester, 'More');
    for (final module in [
      'Finance tracker',
      'Workout tracker',
      'Learning tracker',
      'Content planner',
    ]) {
      await tapMoreRow(tester, module);
      expect(
        find.text('Requires Complete'),
        findsNothing,
        reason: '$module should be unlocked',
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('closed beta unlocks premium modules for a starter account', (
    WidgetTester tester,
  ) async {
    // The whole point of kBetaAllAccess: the stored plan stays `starter` (the
    // subscription document is Admin-SDK-only now) while the app behaves as
    // Complete. If the flag is ever turned off, this expectation flips —
    // which is exactly the signal we want at that moment.
    expect(
      kBetaAllAccess,
      isTrue,
      reason:
          'When the beta ends, replace this with the real gating expectations.',
    );

    final backend = await TestBackend.signedIn(planId: 'starter');
    await pumpApp(tester, backend);

    await goToTab(tester, 'Reminders');
    expect(find.text('No reminders yet'), findsOneWidget);

    await goToTab(tester, 'More');
    await tapMoreRow(tester, 'Finance tracker');
    expect(find.text('Requires Complete'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
