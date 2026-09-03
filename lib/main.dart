import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_env.dart';
import 'core/services/app_logger.dart';
import 'core/services/auth_service.dart';
import 'core/services/content/asset_content_seed_loader.dart';
import 'core/services/content/content_backend.dart';
import 'core/services/content/content_repository.dart';
import 'core/services/content/firestore_content_backend.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/authentication/repositories/auth_repository.dart';
import 'features/ai/providers/ai_provider.dart';
import 'features/ai/repositories/ai_repository.dart';
import 'features/ai/utils/prompt_templates.dart';
import 'features/ai/utils/weekly_report_cache.dart';
import 'features/ai/utils/cat_summary_builder.dart';
import 'features/cats/providers/cat_provider.dart';
import 'features/cats/repositories/cat_repository.dart';
import 'features/health/providers/behavior_provider.dart';
import 'features/health/providers/health_provider.dart';
import 'features/health/providers/medication_provider.dart';
import 'features/health/providers/vaccination_provider.dart';
import 'features/health/providers/weight_provider.dart';
import 'features/health/repositories/behavior_repository.dart';
import 'features/health/repositories/health_repository.dart';
import 'features/health/repositories/medication_repository.dart';
import 'features/health/repositories/vaccination_repository.dart';
import 'features/health/repositories/weight_repository.dart';
import 'features/health/services/vaccination_manager.dart';
import 'features/notifications/repositories/notification_schedule_repository.dart';
import 'features/notifications/services/medication_reminder_scheduler.dart';
import 'features/notifications/services/notification_scheduler_service.dart';
import 'features/notifications/services/vaccination_reminder_scheduler.dart';
import 'features/nutrition/providers/nutrition_provider.dart';
import 'features/nutrition/repositories/feeding_repository.dart';
import 'features/nutrition/repositories/water_repository.dart';
import 'features/routine/providers/routine_provider.dart';
import 'features/routine/repositories/routine_repository.dart';
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
        storageService: _storageService,
      ),
    );
  }
}

class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost({
    required this.authProvider,
    required this.authRepository,
    required this.catRepository,
    required this.storageService,
  });

  final AuthProvider authProvider;
  final AuthRepository authRepository;
  final CatRepository catRepository;
  final StorageService storageService;

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  late final Future<_Wiring> _wiringFuture;

  @override
  void initState() {
    super.initState();
    _wiringFuture = _buildWiring();
  }

  Future<_Wiring> _buildWiring() async {
    final FirestoreService firestore = FirestoreService();
    final CatProvider catProvider = await CatProvider.create(
      repository: widget.catRepository,
      authProvider: widget.authProvider,
    );

    final RoutineRepository routineRepo = RoutineRepository(
      firestoreService: firestore,
    );
    final RoutineProvider routineProvider = RoutineProvider(
      repository: routineRepo,
      catProvider: catProvider,
    );

    final FeedingRepository feedingRepo = FeedingRepository(
      firestoreService: firestore,
    );
    final WaterRepository waterRepo = WaterRepository(
      firestoreService: firestore,
    );
    final NutritionProvider nutritionProvider = NutritionProvider(
      feedingRepository: feedingRepo,
      waterRepository: waterRepo,
      catProvider: catProvider,
    );

    // Phase 5: content (vaccine info + deworming protocols), health
    // repositories, providers, and reactive notification schedulers.
    final ContentRepository contentRepository = ContentRepository(
      primary: FirestoreContentBackend(firestore: firestore.instance),
      fallback: const SeedContentBackend(seedLoader: AssetContentSeedLoader()),
    );

    final HealthRepository healthRepo = HealthRepository(
      firestoreService: firestore,
      storageService: widget.storageService,
    );
    final VaccinationRepository vaccinationRepo = VaccinationRepository(
      firestoreService: firestore,
    );
    final MedicationRepository medicationRepo = MedicationRepository(
      firestoreService: firestore,
    );
    final BehaviorRepository behaviorRepo = BehaviorRepository(
      firestoreService: firestore,
    );
    final WeightRepository weightRepo = WeightRepository(
      firestoreService: firestore,
    );

    final HealthProvider healthProvider = HealthProvider.create(
      repository: healthRepo,
      authProvider: widget.authProvider,
    );
    final VaccinationProvider vaccinationProvider = VaccinationProvider.create(
      repository: vaccinationRepo,
      authProvider: widget.authProvider,
    );
    final MedicationProvider medicationProvider = MedicationProvider.create(
      repository: medicationRepo,
      authProvider: widget.authProvider,
    );
    final BehaviorProvider behaviorProvider = BehaviorProvider.create(
      repository: behaviorRepo,
      authProvider: widget.authProvider,
    );
    final WeightProvider weightProvider = WeightProvider.create(
      repository: weightRepo,
      authProvider: widget.authProvider,
    );

    final VaccinationManager vaccinationManager = VaccinationManager(
      contentRepository: contentRepository,
    );

    final NotificationScheduleRepository scheduleRepo =
        NotificationScheduleRepository(firestoreService: firestore);
    final NotificationService notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermissions();
    final NotificationSchedulerService scheduler = NotificationSchedulerService(
      repository: scheduleRepo,
      notificationService: notificationService,
      routineProvider: routineProvider,
      catProvider: catProvider,
    );

    // Keep the health providers in sync with the active cat. Each
    // provider has its own auth-listener, but we also want a single
    // chokepoint here so the wiring is testable.
    void rebindHealth(String? catId) {
      if (catId == null) return;
      healthProvider.bindCat(catId);
      vaccinationProvider.bindCat(catId);
      medicationProvider.bindCat(catId);
      behaviorProvider.bindCat(catId);
      weightProvider.bindCat(catId);
    }

    catProvider.addListener(() => rebindHealth(catProvider.activeCatId));
    // Initial rebind in case the active cat is already known.
    if (catProvider.activeCatId != null) {
      rebindHealth(catProvider.activeCatId);
    }

    // Reactive medication reminders (Phase 5). They watch the active
    // cat's medications/vaccinations and upsert schedule docs + local
    // notifications whenever the source list changes.
    final MedicationReminderScheduler medicationReminders =
        MedicationReminderScheduler(
          repository: scheduleRepo,
          notificationService: notificationService,
          provider: medicationProvider,
          catIdProvider: () => catProvider.activeCatId ?? '',
          ownerIdProvider: () => widget.authProvider.profile?.uid ?? '',
        );
    final VaccinationReminderScheduler vaccinationReminders =
        VaccinationReminderScheduler(
          repository: scheduleRepo,
          notificationService: notificationService,
          provider: vaccinationProvider,
          manager: vaccinationManager,
          content: contentRepository,
          catIdProvider: () => catProvider.activeCatId ?? '',
          ownerIdProvider: () => widget.authProvider.profile?.uid ?? '',
        );

    // Phase 7: AI Assistant + reports. The Flutter client talks to
    // the Generative Language API directly with the key from
    // `.env` (see `docs/CLIENT_GEMINI_KEY.md`). The provider caches
    // the chat history and last generated report so screens can be
    // navigated back to without re-hitting the network.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final PromptTemplates promptTemplates =
        await PromptTemplates.loadFromBundle();
    final WeeklyReportCache weeklyReportCache = WeeklyReportCache(prefs: prefs);
    final AiRepository aiRepository = AiRepository(
      apiKey: AppEnv.geminiApiKey,
      prefs: prefs,
      templates: promptTemplates,
      cache: weeklyReportCache,
    );
    final CatSummaryBuilder summaryBuilder = CatSummaryBuilder(
      feedingRepository: feedingRepo,
      waterRepository: waterRepo,
      weightRepository: weightRepo,
    );
    final AiProvider aiProvider = AiProvider(
      repository: aiRepository,
      summaryBuilder: summaryBuilder,
      authProvider: widget.authProvider,
      catProvider: catProvider,
      medicationProvider: medicationProvider,
      vaccinationProvider: vaccinationProvider,
      behaviorProvider: behaviorProvider,
      healthProvider: healthProvider,
      routineProvider: routineProvider,
      preferences: prefs,
    );

    return _Wiring(
      contentRepository: contentRepository,
      catProvider: catProvider,
      routineProvider: routineProvider,
      nutritionProvider: nutritionProvider,
      healthProvider: healthProvider,
      vaccinationProvider: vaccinationProvider,
      medicationProvider: medicationProvider,
      behaviorProvider: behaviorProvider,
      weightProvider: weightProvider,
      scheduler: scheduler,
      medicationReminders: medicationReminders,
      vaccinationReminders: vaccinationReminders,
      aiProvider: aiProvider,
    );
  }

  @override
  void dispose() {
    // Best-effort dispose - the future may not have completed yet.
    _wiringFuture.then((_Wiring w) {
      w.scheduler.dispose();
      w.medicationReminders.dispose();
      w.vaccinationReminders.dispose();
      w.routineProvider.dispose();
      w.nutritionProvider.dispose();
      w.healthProvider.dispose();
      w.vaccinationProvider.dispose();
      w.medicationProvider.dispose();
      w.behaviorProvider.dispose();
      w.weightProvider.dispose();
      w.aiProvider.dispose();
      w.catProvider.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Wiring>(
      future: _wiringFuture,
      builder: (BuildContext context, AsyncSnapshot<_Wiring> snapshot) {
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
            themeMode: ThemeMode.light,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final _Wiring w = snapshot.data!;
        return MultiProvider(
          providers: <SingleChildWidget>[
            Provider<ContentRepository>.value(value: w.contentRepository),
            ChangeNotifierProvider<CatProvider>.value(value: w.catProvider),
            ChangeNotifierProvider<RoutineProvider>.value(
              value: w.routineProvider,
            ),
            ChangeNotifierProvider<NutritionProvider>.value(
              value: w.nutritionProvider,
            ),
            ChangeNotifierProvider<HealthProvider>.value(
              value: w.healthProvider,
            ),
            ChangeNotifierProvider<VaccinationProvider>.value(
              value: w.vaccinationProvider,
            ),
            ChangeNotifierProvider<MedicationProvider>.value(
              value: w.medicationProvider,
            ),
            ChangeNotifierProvider<BehaviorProvider>.value(
              value: w.behaviorProvider,
            ),
            ChangeNotifierProvider<WeightProvider>.value(
              value: w.weightProvider,
            ),
            ChangeNotifierProvider<NotificationSchedulerService>.value(
              value: w.scheduler,
            ),
            ChangeNotifierProvider<MedicationReminderScheduler>.value(
              value: w.medicationReminders,
            ),
            ChangeNotifierProvider<VaccinationReminderScheduler>.value(
              value: w.vaccinationReminders,
            ),
            ChangeNotifierProvider<AiProvider>.value(value: w.aiProvider),
          ],
          child: MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
            routerConfig: AppRouter.build(
              authProvider: widget.authProvider,
              catProvider: w.catProvider,
            ),
          ),
        );
      },
    );
  }
}

class _Wiring {
  const _Wiring({
    required this.contentRepository,
    required this.catProvider,
    required this.routineProvider,
    required this.nutritionProvider,
    required this.healthProvider,
    required this.vaccinationProvider,
    required this.medicationProvider,
    required this.behaviorProvider,
    required this.weightProvider,
    required this.scheduler,
    required this.medicationReminders,
    required this.vaccinationReminders,
    required this.aiProvider,
  });
  final CatProvider catProvider;
  final ContentRepository contentRepository;
  final RoutineProvider routineProvider;
  final NutritionProvider nutritionProvider;
  final HealthProvider healthProvider;
  final VaccinationProvider vaccinationProvider;
  final MedicationProvider medicationProvider;
  final BehaviorProvider behaviorProvider;
  final WeightProvider weightProvider;
  final NotificationSchedulerService scheduler;
  final MedicationReminderScheduler medicationReminders;
  final VaccinationReminderScheduler vaccinationReminders;
  final AiProvider aiProvider;
}
