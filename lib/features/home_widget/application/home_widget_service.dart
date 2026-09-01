import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pushes a snapshot of today's numbers to the Android home-screen widget.
///
/// The widget process can't read Firestore — an `AppWidgetProvider` gets a few
/// seconds of broadcast time and has no auth session — so the app hands it a
/// plain snapshot to render (see
/// `android/.../widget/WidgetDataStore.kt`). Android only; a no-op elsewhere.
class HomeWidgetService {
  const HomeWidgetService();

  static const MethodChannel _channel = MethodChannel(
    'com.steadyprogress/widget',
  );

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sends the current counts and redraws every placed widget.
  ///
  /// Failures are swallowed: the widget is a nice-to-have surface, and a
  /// launcher that rejects the update must never take down the screen that
  /// triggered it.
  Future<void> update({
    required int habitsDone,
    required int habitsTotal,
    required int tasksDone,
    required int tasksTotal,
    required int bestStreak,
    required String itemsJson,
  }) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>('updateWidget', {
        'habitsDone': habitsDone,
        'habitsTotal': habitsTotal,
        'tasksDone': tasksDone,
        'tasksTotal': tasksTotal,
        'bestStreak': bestStreak,
        // The per-section rows travel as one JSON string: SharedPreferences
        // has no list-of-objects type, and a single opaque value is simpler
        // to version than a scatter of indexed keys.
        'items': itemsJson,
      });
    } catch (error) {
      debugPrint('Home widget update failed: $error');
    }
  }

  /// Clears the snapshot on sign-out.
  Future<void> clear() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>('clearWidget');
    } catch (error) {
      debugPrint('Home widget clear failed: $error');
    }
  }

  /// Reads the ticks the widget made while the app wasn't running.
  ///
  /// Returns the queue as a JSON array of
  /// `{id, kind, done, at}` — see `WidgetPendingToggles` on the Android side
  /// for why the widget queues these rather than writing them itself.
  /// Empty (not null) on any failure: a widget that can't hand over its
  /// queue must not stop the app from starting.
  Future<String> readPendingToggles() async {
    if (!_isSupported) return '[]';
    try {
      return await _channel.invokeMethod<String>('readPendingToggles') ?? '[]';
    } catch (error) {
      debugPrint('Home widget pending read failed: $error');
      return '[]';
    }
  }

  /// Drops the queued ticks the app has now written through.
  ///
  /// Takes the ids actually applied rather than clearing wholesale: a tick
  /// made while the drain was in flight has to survive it.
  Future<void> clearPendingToggles(List<String> appliedIds) async {
    if (!_isSupported || appliedIds.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('clearPendingToggles', {
        'ids': appliedIds,
      });
    } catch (error) {
      debugPrint('Home widget pending clear failed: $error');
    }
  }
}
