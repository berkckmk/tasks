import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/responsive_scaffold.dart';

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../debug/dev_seed_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/content/presentation/content_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/google_integrations/presentation/google_integrations_screen.dart';
import '../../features/habits/presentation/add_edit_habit_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/home_widget/presentation/home_widget_sync.dart';
import '../../features/reminders/presentation/reminders_screen.dart';
import '../../features/reminders/presentation/add_edit_reminder_screen.dart';
import '../../features/learning/presentation/learning_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/pricing/presentation/pricing_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/tasks/presentation/add_edit_task_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/workout/presentation/workout_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable without being signed in. Everything else is the
/// "protected app shell" — the redirect below sends anonymous visitors to
/// `/auth` and signed-in visitors away from `/auth`.
const _publicPaths = {'/splash', '/onboarding', '/auth'};

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    // Driven by authStateChangesProvider itself (not a second, independent
    // subscription to FirebaseAuth.authStateChanges() — see the fixed bug
    // this used to have, below) so `redirect` always reads the exact state
    // that just triggered the refresh.
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);

      // Auth state hasn't resolved yet (very first frame) — let the splash
      // screen show instead of guessing.
      if (authState.isLoading && !authState.hasValue) return null;

      final user = authState.valueOrNull;
      final isSignedIn = user != null;
      final isPublic = _publicPaths.contains(state.matchedLocation);
      // Google accounts arrive pre-verified, so this only ever gates the
      // email/password path — see AuthRepository.signUpWithEmail.
      final needsVerification = isSignedIn && !user.emailVerified;
      final onVerifyScreen = state.matchedLocation == '/verify-email';

      if (!isSignedIn && !isPublic) return '/auth';
      if (isSignedIn && needsVerification && !onVerifyScreen)
        return '/verify-email';
      if (isSignedIn && !needsVerification && onVerifyScreen)
        return '/dashboard';
      if (isSignedIn && state.matchedLocation == '/auth') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/pricing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PricingScreen(),
      ),
      // Debug-only seed route. Only registered in debug builds so it doesn't
      // appear in production releases.
      if (kDebugMode)
        GoRoute(
          path: '/dev-seed',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const DevSeedScreen(),
        ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/google-integrations',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GoogleIntegrationsScreen(),
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/finance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FinanceScreen(),
      ),
      GoRoute(
        path: '/workout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WorkoutScreen(),
      ),
      GoRoute(
        path: '/learning',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LearningScreen(),
      ),
      GoRoute(
        path: '/content',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ContentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/habits',
                builder: (context, state) => const HabitsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddEditHabitScreen(),
                  ),
                  GoRoute(
                    path: ':habitId/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AddEditHabitScreen(
                      habitId: state.pathParameters['habitId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddEditTaskScreen(),
                  ),
                  GoRoute(
                    path: ':taskId/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AddEditTaskScreen(
                      taskId: state.pathParameters['taskId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reminders',
                builder: (context, state) => const RemindersScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddEditReminderScreen(),
                  ),
                  GoRoute(
                    path: ':reminderId/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AddEditReminderScreen(
                      reminderId: state.pathParameters['reminderId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges [authStateChangesProvider] to a [Listenable] so go_router's
/// `refreshListenable` re-runs `redirect` whenever auth state changes on
/// its own — not just when the user taps something that triggers
/// navigation.
///
/// This used to independently `.listen()` to
/// `FirebaseAuth.authStateChanges()` directly, as a *second* subscription
/// alongside the one backing `authStateChangesProvider`. That was a real
/// bug: on sign-in, this notifier could fire (queuing a `redirect` re-run)
/// *before* `authStateChangesProvider`'s own subscription had processed
/// the same event — `redirect()` reads that provider via `ref.read`, so it
/// would see the stale pre-sign-in value (still signed out), decide
/// there's nothing to do, and never get asked again until some *other*
/// navigation happened to trigger a fresh `redirect` call. From the user's
/// side this looked exactly like "the backend account gets created but
/// the app just sits on the sign-in screen" — sign-in had genuinely
/// succeeded, the router just never found out in time to act on it.
///
/// Listening to the provider itself instead of a second raw stream fixes
/// this categorically: `ref.listen`'s callback only ever fires *after*
/// Riverpod has already updated the provider's cached value, so by the
/// time `redirect()` reads it via `ref.read`, it's never stale.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<User?>>(
      authStateChangesProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavDestinationItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    NavDestinationItem(
      icon: Icons.spa_outlined,
      selectedIcon: Icons.spa,
      label: 'Habits',
    ),
    NavDestinationItem(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Tasks',
    ),
    NavDestinationItem(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Reminders',
    ),
    NavDestinationItem(
      icon: Icons.widgets_outlined,
      selectedIcon: Icons.widgets,
      label: 'More',
    ),
    NavDestinationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // HomeWidgetSync adds no UI — it's here because the shell is the one
    // widget mounted for the whole signed-in session, so the home-screen
    // widget stays current no matter which tab the change happened on.
    return HomeWidgetSync(
      child: ResponsiveScaffold(
        currentIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        child: navigationShell,
      ),
    );
  }
}
