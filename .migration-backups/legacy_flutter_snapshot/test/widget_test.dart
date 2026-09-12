import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:steady_progress/app/app.dart';
import 'package:steady_progress/core/firebase/firebase_providers.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Fakes stand in for real Firebase so this test doesn't need a
          // configured project — same seam `flutterfire configure` fills in
          // for the real app.
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
        child: const SteadyProgressApp(),
      ),
    );
    // Splash is shown immediately...
    await tester.pump();
    expect(find.text('Steady Progress'), findsOneWidget);

    // ...then, once Firebase resolves "signed out", it auto-navigates to
    // onboarding after a short minimum splash delay. Pump past that delay
    // so no timers are left pending when the test ends.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Track habits'), findsOneWidget);
  });
}
