import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cases/case_page.dart';
import '../features/chat/chat_page.dart';
import '../features/home/home_page.dart';
import '../features/lesson/lesson_reader_page.dart';
import '../features/modules/module_page.dart';
import '../features/modules/modules_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/onboarding/onboarding_status.dart';
import '../features/profile/profile_page.dart';
import '../features/quiz/quiz_page.dart';
import '../features/profile/download_doctor_page.dart';
import '../features/profile/renderer_preview_page.dart';
import '../features/profile/saved_cards_page.dart';
import '../features/profile/states_demo_page.dart';
import 'app_shell.dart';
import 'splash_page.dart';

int _id(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '') ?? 0;

/// 3 tab branches + onboarding gate. The gate only ever sends you INTO
/// onboarding (or splash while checking); onboarding leaves by itself.
final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final refresh = ValueNotifier<int>(0);
  ref.listen<OnboardingStatus>(
    onboardingStatusProvider,
    (previous, next) => refresh.value++,
  );
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == '/onboarding' || location == '/doctor') return null;
      return switch (ref.read(onboardingStatusProvider)) {
        OnboardingStatus.loading => location == '/splash' ? null : '/splash',
        OnboardingStatus.needed => '/onboarding',
        OnboardingStatus.done => location == '/splash' ? '/home' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/doctor', builder: (_, _) => const DownloadDoctorPage()),
      GoRoute(
        path: '/case/:setId',
        builder: (_, state) =>
            CasePage(setId: state.pathParameters['setId'] ?? ''),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/modules',
                builder: (_, _) => const ModulesPage(),
                routes: [
                  GoRoute(
                    path: ':moduleId',
                    builder: (_, state) =>
                        ModulePage(moduleId: _id(state, 'moduleId')),
                    routes: [
                      GoRoute(
                        path: 'chat',
                        parentNavigatorKey: rootKey,
                        builder: (_, state) =>
                            ChatPage(moduleId: _id(state, 'moduleId')),
                      ),
                      // Full screen (above the tab bar) for reading.
                      GoRoute(
                        path: 'lesson/:lessonId',
                        parentNavigatorKey: rootKey,
                        builder: (_, state) => LessonReaderPage(
                          key: ValueKey<String>(
                            state.pathParameters['lessonId'] ?? '',
                          ),
                          moduleId: _id(state, 'moduleId'),
                          lessonId: _id(state, 'lessonId'),
                        ),
                        routes: [
                          GoRoute(
                            path: 'quiz',
                            parentNavigatorKey: rootKey,
                            builder: (_, state) => QuizPage(
                              moduleId: _id(state, 'moduleId'),
                              lessonId: _id(state, 'lessonId'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfilePage(),
                routes: [
                  // Debug-only page (the button exists only in debug runs).
                  GoRoute(
                    path: 'saved',
                    builder: (_, _) => const SavedCardsPage(),
                  ),
                  GoRoute(
                    path: 'states',
                    builder: (_, _) => const StatesDemoPage(),
                  ),
                  GoRoute(
                    path: 'renderer',
                    builder: (_, _) => const RendererPreviewPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
