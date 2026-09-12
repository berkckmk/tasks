import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/google_integration_id.dart';
import 'google_integrations_providers.dart';

class GoogleIntegrationsActions {
  GoogleIntegrationsActions(this._ref);

  final Ref _ref;

  /// Requests exactly one scope — [id]'s — then hands the resulting one-time
  /// server auth code to a Cloud Function to exchange for tokens. No other
  /// integration's permission is touched.
  Future<void> connect(GoogleIntegrationId id) async {
    final authRepository = _ref.read(authRepositoryProvider);
    final authCode = await authRepository.requestServerAuthCode([id.scope]);
    await _ref.read(googleIntegrationsServiceProvider).connect(id, serverAuthCode: authCode);
    await _ref.read(analyticsServiceProvider).logGoogleIntegrationConnected(id.name);
  }

  Future<void> disconnect(GoogleIntegrationId id) {
    return _ref.read(googleIntegrationsServiceProvider).disconnect(id);
  }

  Future<void> syncCalendarNow() {
    return _ref.read(googleIntegrationsServiceProvider).syncCalendarNow();
  }

  Future<String> exportToSheets(List<String> selectedModules) {
    return _ref.read(googleIntegrationsServiceProvider).exportToSheets(selectedModules);
  }

  Future<String> backupToDrive() {
    return _ref.read(googleIntegrationsServiceProvider).backupToDrive();
  }

  Future<String> generateReport({
    required String type,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return _ref.read(googleIntegrationsServiceProvider).generateReport(
          type: type,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
  }
}

final googleIntegrationsActionsProvider =
    Provider<GoogleIntegrationsActions>((ref) => GoogleIntegrationsActions(ref));
