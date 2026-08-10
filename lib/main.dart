import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/services/app_logger.dart';
import 'core/services/auth_service.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/authentication/repositories/auth_repository.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.i('CatCare starting…');
  await FirebaseBootstrap.start();
  runApp(const CatCareApp());
}

/// Root widget. Wires:
///   * [AuthService] (platform singleton)
///   * [AuthRepository] (auth-service → auth-state)
///   * [AuthProvider] (ChangeNotifier consumed by go_router +
///     screens)
/// then hands the [AuthProvider] to [AppRouter.build] so go_router
/// can listen to its state machine.
class CatCareApp extends StatefulWidget {
  const CatCareApp({super.key});

  @override
  State<CatCareApp> createState() => _CatCareAppState();
}

class _CatCareAppState extends State<CatCareApp> {
  late final AuthService _authService;
  late final AuthRepository _authRepository;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authRepository = AuthRepository(service: _authService);
    _authProvider = AuthProvider(repository: _authRepository);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        // Repositories first so providers can depend on them.
        Provider<AuthRepository>.value(value: _authRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
      ],
      child: _AppRouterHost(authProvider: _authProvider),
    );
  }
}

class _AppRouterHost extends StatelessWidget {
  const _AppRouterHost({required this.authProvider});
  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.build(authProvider: authProvider),
    );
  }
}
