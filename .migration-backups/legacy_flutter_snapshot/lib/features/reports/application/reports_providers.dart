import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_reports_repository.dart';
import '../domain/report.dart';

// Module streams below are `autoDispose`: each is watched only by its own
// screen, so the Firestore listener closes when the user navigates away
// instead of staying open for the rest of the session. Nothing outside the
// widget tree watches them, which is what makes this safe — a non-autoDispose
// provider cannot watch an autoDispose one.
final reportsRepositoryProvider = Provider.autoDispose<FirestoreReportsRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreReportsRepository(ref.watch(firestoreProvider), uid);
});

final reportsProvider = StreamProvider.autoDispose<List<Report>>((ref) {
  final repository = ref.watch(reportsRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchReports();
});
