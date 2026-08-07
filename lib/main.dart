import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/services/app_logger.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.i('CatCare starting…');
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
