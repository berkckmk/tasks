import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firestore_reports_repository.dart';
import '../domain/report.dart';

final reportsRepositoryProvider = Provider<FirestoreReportsRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreReportsRepository(ref.watch(firestoreProvider), uid);
});

final reportsProvider = StreamProvider<List<Report>>((ref) {
  final repository = ref.watch(reportsRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchReports();
});
