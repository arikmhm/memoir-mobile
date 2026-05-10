import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di.dart';
import '../features/app/bloc/app_cubit.dart';
import '../features/app/bloc/app_state.dart';
import '../features/pairing/view/pairing_screen.dart';
import '../features/session/bloc/processing_cubit.dart';
import '../shared/data/models/template.dart';
import '../features/session/view/screensaver_screen.dart';
import '../features/session/view/photo_session_screen.dart';
import '../features/session/view/preview_screen.dart';
import '../features/session/view/confirmation_screen.dart';
import '../features/session/view/processing_screen.dart';
import '../features/session/view/select_template_screen.dart';
import '../features/session/view/thank_you_screen.dart';
import '../features/home/bloc/home_cubit.dart';
import '../features/home/view/home_screen.dart';
import '../features/startup/bloc/startup_cubit.dart';
import '../features/startup/view/startup_screen.dart';

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

      // If startup in progress, redirect to startup screen
      if (appState is AppStartup) {
        if (location != '/startup') return '/startup';
        return null;
      }

      // If ready, redirect away from pairing/startup to home
      if (appState is AppReady) {
        if (location == '/pairing' || location == '/startup') {
          return '/home';
        }
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
        path: '/startup',
        builder: (context, state) => BlocProvider<StartupCubit>(
          create: (_) => sl<StartupCubit>(),
          child: const StartupScreen(),
        ),
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
        path: '/preview/:templateId',
        builder: (context, state) {
          final photos = state.extra as Map<int, String>? ?? {};
          return PreviewScreen(
            templateId: state.pathParameters['templateId'] ?? '',
            capturedPhotos: photos,
          );
        },
      ),
      GoRoute(
        path: '/confirmation/:templateId',
        builder: (context, state) {
          final photos = state.extra as Map<int, String>? ?? {};
          return ConfirmationScreen(
            templateId: state.pathParameters['templateId'] ?? '',
            capturedPhotos: photos,
          );
        },
      ),
      GoRoute(
        path: '/processing',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BlocProvider<ProcessingCubit>(
            create: (_) {
              final cubit = sl<ProcessingCubit>();
              cubit.startProcessing(
                template: extra['template'] as Template,
                capturedPhotos:
                    extra['capturedPhotos'] as Map<int, String>? ?? {},
                paymentMethod: extra['paymentMethod'] as String? ?? 'CASH',
                printQty: extra['printQty'] as int? ?? 1,
                hasDigitalCopy:
                    extra['hasDigitalCopy'] as bool? ?? false,
                totalAmount: extra['totalAmount'] as int? ?? 0,
              );
              return cubit;
            },
            child: const ProcessingScreen(),
          );
        },
      ),
      GoRoute(
        path: '/thank-you',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ThankYouScreen(
            transactionId: extra['transactionId'] as String?,
            hasDigitalCopy: extra['hasDigitalCopy'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => BlocProvider<HomeCubit>(
          create: (_) => sl<HomeCubit>(),
          child: const HomeScreen(),
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
