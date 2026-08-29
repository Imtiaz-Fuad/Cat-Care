import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/app_logger.dart';

/// Build-flavor keys and runtime environment helpers.
///
/// Values are loaded from `.env` at startup via `flutter_dotenv`. The
/// loader is explicit (`AppEnv.initialize`) so callers can fail fast when the
/// file is missing in development or CI rather than discovering a null
/// value deep in a service.
class AppEnv {
  AppEnv._();

  /// Names of the supported build flavors. Each flavor maps to a different
  /// Firebase project (configured via FlutterFire CLI).
  static const String flavorDev = 'dev';
  static const String flavorStaging = 'staging';
  static const String flavorProd = 'prod';

  static String _flavor = flavorDev;

  /// Current flavor. Defaults to `dev`; overridden at startup via
  /// `--dart-define=FLAVOR=prod` (consumed by `AppEnv.initialize`).
  static String get flavor => _flavor;

  /// True once [initialize] has finished (success or skipped). Used by
  /// `FirebaseBootstrap` to decide whether flavor-aware logging should
  /// fire.
  static bool initialized = false;

  /// Reads `.env` and captures the active flavor from `--dart-define`.
  /// Call this from `main()` before `runApp`.
  ///
  /// The loader is **defensive**: a missing or unreadable `.env` only
  /// logs a warning. It does NOT throw — `main()` has no
  /// `runZonedGuarded` wrapper, so an exception here would kill startup
  /// and the user would be stuck on the native splash forever.
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (error, stack) {
      // `.env` is intentionally not bundled in release builds (see
      // commit e88dbe2 — dropped from flutter assets for CI reasons).
      // `flutter_dotenv` throws when the asset is missing, which used
      // to wedge `main()` on the native splash. Warn and continue with
      // empty values; flavor-aware code paths still work via
      // `--dart-define=FLAVOR=...`.
      AppLogger.w(
        'AppEnv: .env not loaded — falling back to dart-defines + '
        'empty values.',
        error,
        stack,
      );
    }
    const String fromDefine = String.fromEnvironment(
      'FLAVOR',
      defaultValue: flavorDev,
    );
    _flavor = _normalizeFlavor(fromDefine);
    initialized = true;
  }

  static String _normalizeFlavor(String raw) {
    switch (raw) {
      case flavorProd:
        return flavorProd;
      case flavorStaging:
        return flavorStaging;
      case flavorDev:
      default:
        return flavorDev;
    }
  }

  /// Raw key lookup with fallback. Never use this to read secrets that
  /// belong in Cloud Functions (api keys, third-party tokens).
  static String get(String key, {String fallback = ''}) {
    return dotenv.maybeGet(key) ?? fallback;
  }

  /// Gemini API key. The Flutter client talks to the Generative
  /// Language API directly; there is no backend in between. The key
  /// is loaded from `GEMINI_API_KEY` in `.env` and bundled into the
  /// release AAB — see `docs/CLIENT_GEMINI_KEY.md` for the accepted
  /// trade-off and the AI Studio restriction guidance.
  ///
  /// In dev, `.env` is loaded via `flutter_dotenv`. In CI/release
  /// where the asset may be absent, prefer `--dart-define=GEMINI_API_KEY=…`.
  static String get geminiApiKey => get('GEMINI_API_KEY');

  /// Returns the Firebase project id for the active flavor.
  static String get firebaseProjectId {
    switch (_flavor) {
      case flavorProd:
        return get(
          'FIREBASE_PROJECT_ID_PROD',
          fallback: get('FIREBASE_PROJECT_ID'),
        );
      case flavorStaging:
        return get(
          'FIREBASE_PROJECT_ID_STAGING',
          fallback: get('FIREBASE_PROJECT_ID'),
        );
      case flavorDev:
      default:
        return get('FIREBASE_PROJECT_ID');
    }
  }
}
