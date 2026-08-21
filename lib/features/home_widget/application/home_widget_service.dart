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
}
