import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../content/application/content_providers.dart';
import '../../finance/application/finance_providers.dart';
import '../../goals/application/goal_providers.dart';
import '../../google_integrations/application/google_integrations_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../learning/application/learning_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../reports/application/reports_providers.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../tasks/application/task_providers.dart';
import '../../workout/application/workout_providers.dart';

/// Every provider holding data that belongs to one signed-in user.
///
/// [AuthActions.signOut] invalidates all of these so nothing from the
/// previous account survives into the next one. They're listed explicitly
/// rather than discovered, so adding a new user-scoped provider without
/// adding it here is a visible omission in one place instead of a silent
/// data-bleed bug spread across screens.
///
/// Keep in sync when adding a provider that reads `currentUidProvider`.
final List<ProviderOrFamily> userScopedProviders = [
  profileProvider,
  subscriptionStatusProvider,
  rawHabitsProvider,
  habitLogsProvider,
  habitsProvider,
  habitFilterProvider,
  tasksProvider,
  goalsProvider,
  financeTransactionsProvider,
  savingsGoalsProvider,
  workoutsProvider,
  exerciseLogsProvider,
  learningItemsProvider,
  contentItemsProvider,
  reportsProvider,
  googleCalendarStatusProvider,
  googleSheetsStatusProvider,
  googleDriveStatusProvider,
  googleDocsStatusProvider,
];
