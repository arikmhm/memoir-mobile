import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/routes.dart';
import 'di.dart';
import 'features/app/bloc/app_cubit.dart';
import 'features/pairing/bloc/pairing_cubit.dart';
import 'features/session/bloc/session_cubit.dart';
import 'shared/core/theme/app_theme.dart';

/// Root widget for memoir. Mobile Runner.
///
/// Provides BLoC instances and configures Material 3 dark theme.
class MemoirApp extends StatelessWidget {
  const MemoirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppCubit>.value(value: sl<AppCubit>()),
        BlocProvider<PairingCubit>(create: (_) => sl<PairingCubit>()),
        BlocProvider<SessionCubit>(create: (_) => sl<SessionCubit>()),
      ],
      child: MaterialApp.router(
        title: 'memoir. Mobile Runner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: sl<AppRouter>().router,
      ),
    );
  }
}
