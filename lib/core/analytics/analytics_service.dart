import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';

/// A small, typed wrapper around FirebaseAnalytics so the rest of the app
/// logs events by calling a named method instead of sprinkling raw
/// `logEvent(name: '...')` string literals through feature code — keeps
/// event names consistent and greppable from one place.
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> setUserId(String? uid) => _analytics.setUserId(id: uid);

  Future<void> logSignUp(String method) => _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogin(String method) => _analytics.logLogin(loginMethod: method);

  Future<void> logHabitCompleted() => _analytics.logEvent(name: 'habit_completed');

  Future<void> logTaskCompleted() => _analytics.logEvent(name: 'task_completed');

  Future<void> logGoalCreated() => _analytics.logEvent(name: 'goal_created');

  Future<void> logPlanUpgradeAttempted(String planId) =>
      _analytics.logEvent(name: 'plan_upgrade_attempted', parameters: {'plan_id': planId});

  Future<void> logPlanUpgraded(String planId) =>
      _analytics.logEvent(name: 'plan_upgraded', parameters: {'plan_id': planId});

  Future<void> logGoogleIntegrationConnected(String integration) => _analytics.logEvent(
        name: 'google_integration_connected',
        parameters: {'integration': integration},
      );
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(firebaseAnalyticsProvider));
});
