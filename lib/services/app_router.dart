import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:holyher/main.dart';
import 'package:holyher/core/widgets/holy_ui.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appRouterProvider = Provider<GoRouter>((ref) {
  // A stable route owner keeps tab controllers and search state alive while the
  // URL changes. The root gates every destination through account and setup.
  final router = GoRouter(navigatorKey: appNavigatorKey, routes: [
    GoRoute(
        path: '/:location(.*)',
        pageBuilder: (context, state) {
          final path = state.uri.path, parts = state.uri.pathSegments;
          final reading = parts.length == 2 && parts.first == 'reading';
          final tab =
              path == '/saved' || state.uri.queryParameters['from'] == 'saved'
                  ? 1
                  : path == '/profile' ||
                          state.uri.queryParameters['from'] == 'profile'
                      ? 2
                      : 0;
          final valid =
              const ['/', '/saved', '/profile'].contains(path) || reading;
          return NoTransitionPage<void>(
              key: const ValueKey('holyher-app-root'),
              child: valid
                  ? AppRoot(
                      initialTab: tab,
                      requestedDay:
                          reading ? int.tryParse(parts[1]) ?? 0 : null,
                      requestedScripture:
                          state.uri.queryParameters['card'] == 'scripture')
                  : HolyRecovery(
                      message: 'That page is not part of your walk.',
                      onRetry: () => GoRouter.of(context).go('/')));
        }),
  ]);
  ref.onDispose(router.dispose);
  return router;
});
