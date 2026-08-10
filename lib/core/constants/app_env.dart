import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-flavor keys and runtime environment helpers.
///
/// Values are loaded from `.env` at startup via `flutter_dotenv`. The
/// loader is explicit (`AppEnv.load`) so callers can fail fast when the
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

  /// Reads `.env` and captures the active flavor from `--dart-define`.
  /// Call this from `main()` before `runApp`.
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    const String fromDefine =
        String.fromEnvironment('FLAVOR', defaultValue: flavorDev);
    _flavor = _normalizeFlavor(fromDefine);
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

  /// Returns the Firebase project id for the active flavor.
  static String get firebaseProjectId {
    switch (_flavor) {
      case flavorProd:
        return get('FIREBASE_PROJECT_ID_PROD',
            fallback: get('FIREBASE_PROJECT_ID'));
      case flavorStaging:
        return get('FIREBASE_PROJECT_ID_STAGING',
            fallback: get('FIREBASE_PROJECT_ID'));
      case flavorDev:
      default:
        return get('FIREBASE_PROJECT_ID');
    }
  }
}
