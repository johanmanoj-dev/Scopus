import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/semester_provider.dart';
import '../../ui/layouts/shell_layout.dart';
import '../../ui/screens/dashboard_screen.dart';
import '../../ui/screens/subjects_screen.dart';
import '../../ui/screens/assignments_screen.dart';
import '../../ui/screens/settings_screen.dart';
import '../../ui/screens/subject_details_screen.dart';
import '../../ui/screens/no_semester_screen.dart';
import '../../ui/screens/login_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Factory — called once from [ScopusApp] in main.dart.
  /// [refreshListenable] is notified by [ScopusApp] whenever auth or
  /// semester state changes, causing GoRouter to re-evaluate its redirect.
  static GoRouter create(Listenable refreshListenable) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        // Read Riverpod providers via ProviderScope — context is always
        // within ProviderScope since ScopusApp is the root widget.
        final container = ProviderScope.containerOf(context);

        // ── Auth check ───────────────────────────────────────────────
        final isLoggedIn =
            container.read(authStateProvider).valueOrNull != null;
        final isGoingToLogin = state.matchedLocation == '/login';

        if (!isLoggedIn) return isGoingToLogin ? null : '/login';
        if (isGoingToLogin) return '/';

        // ── Semester loading check ───────────────────────────────────
        // Don't redirect while semesters are still loading from Firestore.
        // Without this, the router would flash /no-semester on every startup.
        final semestersAsync = container.read(semestersProvider);
        if (semestersAsync.isLoading) return null;

        // ── Semester check ───────────────────────────────────────────
        final hasActiveSemester =
            container.read(activeSemesterProvider) != null;
        final goingToGate = state.matchedLocation == '/no-semester';

        if (!hasActiveSemester && !goingToGate) return '/no-semester';
        if (hasActiveSemester && goingToGate) return '/';

        return null;
      },
      routes: [
        // ── Login ─────────────────────────────────────────────────────
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => _fade(context, state,
              const LoginScreen()),
        ),
        // ── No-semester gate ─────────────────────────────────────────
        GoRoute(
          path: '/no-semester',
          pageBuilder: (context, state) => _fade(context, state,
              const NoSemesterScreen()),
        ),
        // ── Main shell (sidebar + content) ───────────────────────────
        StatefulShellRoute(
          navigatorContainerBuilder: (context, navigationShell, children) {
            if (Platform.isAndroid) {
              return AndroidSwipeShell(navigationShell: navigationShell, children: children);
            }
            return children[navigationShell.currentIndex];
          },
          builder: (context, state, navigationShell) => ShellLayout(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  pageBuilder: (context, state) => _fade(context, state, const DashboardScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/subjects',
                  pageBuilder: (context, state) => _fade(context, state, const SubjectsScreen()),
                  routes: [
                    GoRoute(
                      path: ':id',
                      pageBuilder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return _fade(context, state, SubjectDetailsScreen(subjectId: id));
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/assignments',
                  pageBuilder: (context, state) => _fade(context, state, const AssignmentsScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  pageBuilder: (context, state) => _fade(context, state, const SettingsScreen()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static CustomTransitionPage<T> _fade<T>(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
          ),
        );
        final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
          ),
        );
        return FadeTransition(
          opacity: fadeOut,
          child: FadeTransition(opacity: fadeIn, child: child),
        );
      },
    );
  }
}
