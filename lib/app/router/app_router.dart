import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/widgets/responsive_scaffold.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/content/presentation/content_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/goals/presentation/add_edit_goal_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/google_integrations/presentation/google_integrations_screen.dart';
import '../../features/habits/presentation/add_edit_habit_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
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

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes reachable without being signed in. Everything else is the
/// "protected app shell" — the redirect below sends anonymous visitors to
/// `/auth` and signed-in visitors away from `/auth`.
const _publicPaths = {'/splash', '/onboarding', '/auth'};

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(ref.read(firebaseAuthProvider).authStateChanges()),
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);

      // Auth state hasn't resolved yet (very first frame) — let the splash
      // screen show instead of guessing.
      if (authState.isLoading && !authState.hasValue) return null;

      final isSignedIn = authState.valueOrNull != null;
      final isPublic = _publicPaths.contains(state.matchedLocation);

      if (!isSignedIn && !isPublic) return '/auth';
      if (isSignedIn && state.matchedLocation == '/auth') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/pricing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PricingScreen(),
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AnalyticsScreen(),
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
        builder: (context, state, navigationShell) => _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
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
                    builder: (context, state) =>
                        AddEditHabitScreen(habitId: state.pathParameters['habitId']),
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
                    builder: (context, state) =>
                        AddEditTaskScreen(taskId: state.pathParameters['taskId']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AddEditGoalScreen(),
                  ),
                  GoRoute(
                    path: ':goalId/edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        AddEditGoalScreen(goalId: state.pathParameters['goalId']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges a [Stream] (Firebase auth state changes) to a [Listenable] so
/// go_router's `refreshListenable` re-runs `redirect` whenever auth state
/// changes on its own — not just when the user taps something that
/// triggers navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
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
    NavDestinationItem(icon: Icons.spa_outlined, selectedIcon: Icons.spa, label: 'Habits'),
    NavDestinationItem(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Tasks',
    ),
    NavDestinationItem(icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: 'Goals'),
    NavDestinationItem(
      icon: Icons.widgets_outlined,
      selectedIcon: Icons.widgets,
      label: 'More',
    ),
    NavDestinationItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentIndex: navigationShell.currentIndex,
      destinations: _destinations,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      child: navigationShell,
    );
  }
}
