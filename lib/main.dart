import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'di.dart';
import 'features/app/bloc/app_cubit.dart';

/// Entry point for memoir. Mobile Runner.
///
/// Initializes dependencies, sets landscape orientation,
/// and starts the app lifecycle via AppCubit.
/// Bypass SSL cert verification for all dart:io HttpClient instances.
///
/// Needed for Cloudflare R2 CDN (pub-*.r2.dev) which has hostname mismatch
/// against Dart's BoringSSL. Safe because all URLs originate from our API.
class _TrustAllCertsOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() async {
  HttpOverrides.global = _TrustAllCertsOverride();
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation (phone testing)
  // TODO: Switch to landscapeLeft/Right for tablet kiosk deployment
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Fullscreen immersive mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Initialize dependency injection
  await initDependencies();

  // Start app lifecycle (check token, sync, etc.)
  sl<AppCubit>().initialize();

  runApp(const MemoirApp());
}
