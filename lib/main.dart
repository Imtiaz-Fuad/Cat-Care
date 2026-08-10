import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/services/app_logger.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.i('CatCare starting…');
  await FirebaseBootstrap.start();
  runApp(const CatCareApp());
}

/// Root widget. Theme and routing are wired here; providers are added in
/// Phase 2 (AuthProvider) and beyond.
class CatCareApp extends StatelessWidget {
  const CatCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.build(),
    );
  }
}
