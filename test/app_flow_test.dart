import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/app/app.dart';
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: backend.overrides,
        child: const SteadyProgressApp(),
      ),
    );
    // Splash -> (signed in) -> Dashboard.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> goToTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('seeded habits, tasks and goals actually render on their tabs',
      (WidgetTester tester) async {
    final backend = await TestBackend.signedIn(planId: 'complete');
    await backend.addHabit('Morning run');
    await backend.addTask('File the tax return');
    await backend.addGoal('Run a half marathon');

    await pumpApp(tester, backend);
    expect(tester.takeException(), isNull);

    await goToTab(tester, 'Habits');
    expect(find.text('Morning run'), findsWidgets);
    expect(tester.takeException(), isNull);

    await goToTab(tester, 'Tasks');
    expect(find.text('File the tax return'), findsWidgets);
    expect(tester.takeException(), isNull);

    await goToTab(tester, 'Goals');
    expect(find.text('Run a half marathon'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every Complete-plan module opens without an upgrade gate',
      (WidgetTester tester) async {
    final backend = await TestBackend.signedIn(planId: 'complete');
    await pumpApp(tester, backend);

    await goToTab(tester, 'More');
    for (final module in ['Finance tracker', 'Workout tracker', 'Learning tracker', 'Content planner']) {
      await tester.tap(find.text(module));
      await tester.pumpAndSettle();
      expect(find.text('Requires Complete'), findsNothing, reason: '$module should be unlocked');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('closed beta unlocks premium modules for a starter account',
      (WidgetTester tester) async {
    // The whole point of kBetaAllAccess: the stored plan stays `starter` (the
    // subscription document is Admin-SDK-only now) while the app behaves as
    // Complete. If the flag is ever turned off, this expectation flips —
    // which is exactly the signal we want at that moment.
    expect(kBetaAllAccess, isTrue,
        reason: 'When the beta ends, replace this with the real gating expectations.');

    final backend = await TestBackend.signedIn(planId: 'starter');
    await pumpApp(tester, backend);

    await goToTab(tester, 'Goals');
    expect(find.text('Requires Growth'), findsNothing);

    await goToTab(tester, 'More');
    await tester.tap(find.text('Finance tracker'));
    await tester.pumpAndSettle();
    expect(find.text('Requires Complete'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
