import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/app/app.dart';
import 'package:steady_progress/core/firebase/firebase_providers.dart';

/// Exercises the full authenticated shell (Dashboard/Habits/Tasks/Goals/
/// More/Profile + the Complete-plan modules reachable from More) against a
/// fake, pre-seeded Firebase backend — the parts a plain "does it compile"
/// check can't catch, like a typo'd provider or a widget that throws once
/// it's actually built.
void main() {
  testWidgets('Signed-in user on the Complete plan can reach every tab and module',
      (WidgetTester tester) async {
    final mockUser = MockUser(
      uid: 'test-uid',
      email: 'jane@example.com',
      displayName: 'Jane Doe',
    );
    final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    final userDoc = firestore.collection('users').doc('test-uid');
    await userDoc.set({
      'uid': 'test-uid',
      'email': 'jane@example.com',
      'displayName': 'Jane Doe',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'selectedPlan': 'complete',
      'onboardingCompleted': true,
      'timezone': 'UTC',
      'appPreferences': {'notificationsEnabled': true, 'theme': 'system'},
    });
    await userDoc.collection('subscription').doc('status').set({
      'planId': 'complete',
      'status': 'active',
      'startedAt': Timestamp.now(),
      'expiresAt': null,
      'billingProvider': 'none',
      'isTrialActive': false,
      'trialEndsAt': null,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          firestoreProvider.overrideWithValue(firestore),
        ],
        child: const SteadyProgressApp(),
      ),
    );

    // Splash -> (signed in) -> Dashboard.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Dashboard'), findsWidgets);
    expect(tester.takeException(), isNull);

    Future<void> goToTab(String label) async {
      await tester.tap(find.widgetWithText(NavigationDestination, label).first);
      await tester.pumpAndSettle();
    }

    await goToTab('Habits');
    expect(find.text('Habits'), findsWidgets);
    expect(tester.takeException(), isNull);

    await goToTab('Tasks');
    expect(find.text('Tasks'), findsWidgets);
    expect(tester.takeException(), isNull);

    await goToTab('Goals');
    expect(find.text('Goals'), findsWidgets);
    // Complete plan includes the goal planner, so this must NOT be a lock screen.
    expect(find.text('Requires Growth'), findsNothing);
    expect(tester.takeException(), isNull);

    await goToTab('More');
    expect(find.text('More'), findsWidgets);
    expect(tester.takeException(), isNull);

    for (final module in ['Finance tracker', 'Workout tracker', 'Learning tracker', 'Content planner']) {
      await tester.tap(find.text(module));
      await tester.pumpAndSettle();
      // Complete plan unlocks every module, so none of these should show the
      // "Requires Complete" upgrade gate.
      expect(find.text('Requires Complete'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    final moreScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Google Integrations'), 150, scrollable: moreScrollable);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Integrations'));
    await tester.pumpAndSettle();
    expect(find.text('Google Account'), findsOneWidget);
    expect(find.text('Google Calendar Sync'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Scrolling all the way to the last section exercises every
    // IntegrationCard (Sheets/Drive/Docs use the same widget as Calendar).
    await tester.scrollUntilVisible(
      find.text('Google Docs Reports'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Google Docs Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Reports'), 150, scrollable: moreScrollable);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('No reports yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await goToTab('Profile');
    expect(find.text('Complete plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signed-in user on the Starter plan sees upgrade gates', (WidgetTester tester) async {
    final mockUser = MockUser(uid: 'starter-uid', email: 'sam@example.com', displayName: 'Sam');
    final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    final firestore = FakeFirebaseFirestore();

    final userDoc = firestore.collection('users').doc('starter-uid');
    await userDoc.set({
      'uid': 'starter-uid',
      'email': 'sam@example.com',
      'displayName': 'Sam',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'selectedPlan': 'starter',
      'onboardingCompleted': true,
      'timezone': 'UTC',
      'appPreferences': {'notificationsEnabled': true, 'theme': 'system'},
    });
    await userDoc.collection('subscription').doc('status').set({
      'planId': 'starter',
      'status': 'active',
      'startedAt': Timestamp.now(),
      'expiresAt': null,
      'billingProvider': 'none',
      'isTrialActive': false,
      'trialEndsAt': null,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          firestoreProvider.overrideWithValue(firestore),
        ],
        child: const SteadyProgressApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Goals').first);
    await tester.pumpAndSettle();
    expect(find.text('Requires Growth'), findsOneWidget);
    expect(find.text('Upgrade to Growth'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(NavigationDestination, 'More').first);
    await tester.pumpAndSettle();
    // Locked modules stay visible, just marked with their required plan.
    expect(find.text('Finance tracker'), findsOneWidget);
    expect(find.text('Complete'), findsWidgets);

    await tester.tap(find.text('Finance tracker'));
    await tester.pumpAndSettle();
    expect(find.text('Requires Complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
