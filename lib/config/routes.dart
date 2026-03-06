import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di.dart';
import '../features/app/bloc/app_cubit.dart';
import '../features/app/bloc/app_state.dart';
import '../features/pairing/view/pairing_screen.dart';
import '../features/session/view/screensaver_screen.dart';
import '../features/session/view/photo_session_screen.dart';
import '../features/session/view/select_template_screen.dart';
import '../features/settings/bloc/settings_cubit.dart';
import '../features/settings/view/settings_screen.dart';

/// GoRouter route definitions for memoir. Mobile Runner.
///
/// Routing is driven by AppCubit state:
/// - AppPairing → /pairing
/// - AppReady → /screensaver (default)
/// - AppLocked → /locked
///
/// Per PRD-05: GoRouter for declarative routing.
class AppRouter {
  final AppCubit appCubit;

  AppRouter({required this.appCubit});

  late final GoRouter router = GoRouter(
    initialLocation: '/pairing',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final appState = appCubit.state;
      final location = state.uri.path;

      // If not paired, redirect to pairing
      if (appState is AppPairing || appState is AppInitial) {
        if (location != '/pairing') return '/pairing';
        return null;
      }

      // If locked, redirect to locked screen
      if (appState is AppLocked) {
        if (location != '/locked') return '/locked';
        return null;
      }

      // If ready and still on pairing, go to screensaver
      if (appState is AppReady && location == '/pairing') {
        return '/screensaver';
      }

      return null;
    },
    refreshListenable: _GoRouterRefreshStream(appCubit.stream),
    routes: [
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingScreen(),
      ),
      GoRoute(
        path: '/screensaver',
        builder: (context, state) => const ScreensaverScreen(),
      ),
      GoRoute(
        path: '/select-template',
        builder: (context, state) => const SelectTemplateScreen(),
      ),
      GoRoute(
        path: '/photo-session/:templateId',
        builder: (context, state) => PhotoSessionScreen(
          templateId: state.pathParameters['templateId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => BlocProvider<SettingsCubit>(
          create: (_) => sl<SettingsCubit>(),
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/locked',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Device Terkunci',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                if (appCubit.state is AppLocked)
                  Text(
                    (appCubit.state as AppLocked).reason,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Converts a [Stream] into a [ChangeNotifier] for GoRouter refresh.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    // ignore: avoid_dynamic_calls
    _subscription.cancel();
    super.dispose();
  }
}
