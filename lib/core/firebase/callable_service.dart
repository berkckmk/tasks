import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Thin seam over `FirebaseFunctions.httpsCallable`.
///
/// Exists so repositories depend on an interface that can be faked in tests.
/// `FirebaseFunctions.instance` reaches for `Firebase.app()` the moment it's
/// constructed, which throws `[core/no-app]` in a widget test — and because
/// repositories are built inside providers whose results feed `StreamProvider`s,
/// that throw was being converted into an `AsyncError` and rendered as an
/// `ErrorState`. The habit and task lists were silently erroring in every
/// test while the assertions (which matched nav labels) still passed.
abstract class CallableService {
  /// Invokes callable [name]. Returns its response payload, or null when the
  /// function returns nothing.
  Future<Map<String, dynamic>?> call(String name, [Map<String, dynamic>? data]);
}

class FirebaseCallableService implements CallableService {
  FirebaseCallableService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>?> call(String name, [Map<String, dynamic>? data]) async {
    final result = await _functions.httpsCallable(name).call<Object?>(data);
    final payload = result.data;
    return payload is Map ? Map<String, dynamic>.from(payload) : null;
  }
}

final callableServiceProvider = Provider<CallableService>(
  (ref) => FirebaseCallableService(ref.watch(firebaseFunctionsProvider)),
);
