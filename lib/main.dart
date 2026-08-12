import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/services/app_logger.dart';
import 'core/services/auth_service.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/firestore_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/authentication/repositories/auth_repository.dart';
import 'features/cats/providers/cat_provider.dart';
import 'features/cats/repositories/cat_repository.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.i('CatCare starting...');
  await FirebaseBootstrap.start();
  runApp(const CatCareApp());
}

/// Root widget. Wires:
///   * [AuthService] (platform singleton)
///   * [AuthRepository] (auth-service to auth-state)
///   * [AuthProvider] (ChangeNotifier consumed by go_router +
///     screens)
///   * [CatRepository] (Firestore + Storage facade)
///   * [CatProvider] (ChangeNotifier consumed by go_router +
///     screens)
/// then hands the [AuthProvider] and [CatProvider] to [AppRouter.build]
/// so go_router can listen to their state machines.
class CatCareApp extends StatefulWidget {
  const CatCareApp({super.key});

  @override
  State<CatCareApp> createState() => _CatCareAppState();
}

class _CatCareAppState extends State<CatCareApp> {
  late final AuthService _authService;
  late final AuthRepository _authRepository;
  late final AuthProvider _authProvider;
  late final FirestoreService _firestoreService;
  late final StorageService _storageService;
  late final CatRepository _catRepository;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authRepository = AuthRepository(service: _authService);
    _authProvider = AuthProvider(repository: _authRepository);
    _firestoreService = FirestoreService();
    _storageService = StorageService();
    _catRepository = CatRepository(
      firestoreService: _firestoreService,
      storageService: _storageService,
    );
  }

  @override
  void dispose() {
    _authProvider.dispose();
    // CatProvider is constructed asynchronously via CatProvider.create
    // (it awaits SharedPreferences) and is wired in [_AppRouterHost]
    // below, so we don't dispose it here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        // Repositories first so providers can depend on them.
        Provider<AuthRepository>.value(value: _authRepository),
        Provider<CatRepository>.value(value: _catRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        // CatProvider needs SharedPreferences, so it's created once
        // per app lifetime and supplied via a microtask in [_AppRouterHost].
      ],
      child: _AppRouterHost(
        authProvider: _authProvider,
        authRepository: _authRepository,
        catRepository: _catRepository,
      ),
    );
  }
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost({
    required this.authProvider,
    required this.authRepository,
    required this.catRepository,
  });

  final AuthProvider authProvider;
  final AuthRepository authRepository;
  final CatRepository catRepository;

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  late final Future<CatProvider> _catProviderFuture;

  @override
  void initState() {
    super.initState();
    _catProviderFuture = CatProvider.create(
      repository: widget.catRepository,
      authProvider: widget.authProvider,
    );
  }

  @override
  void dispose() {
    // Best-effort dispose - the future may not have completed yet.
    _catProviderFuture.then((CatProvider p) => p.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatProvider>(
      future: _catProviderFuture,
      builder: (BuildContext context, AsyncSnapshot<CatProvider> snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          // SharedPreferences is local and resolves in <100ms even
          // on cold start; render the app with a placeholder router
          // so the splash stays visible while we wait.
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final CatProvider catProvider = snapshot.data!;
        return MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<CatProvider>.value(value: catProvider),
          ],
          child: MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.build(
              authProvider: widget.authProvider,
              catProvider: catProvider,
            ),
          ),
        );
      },
    );
  }
}
