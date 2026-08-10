import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../constants/app_env.dart';
import 'app_logger.dart';

/// Wraps the platform-specific Firebase startup. The app calls this from
/// `main()` *before* `runApp` so providers and repositories can assume
/// Firebase is alive.
///
/// Wrapped in a `try/catch` because `Firebase.initializeApp` throws when
/// `firebase_options.dart` has not yet been populated (the maintainer
/// runs `flutterfire configure` to fill `DefaultFirebaseOptions`). In
/// development we still want the rest of the app shell to render so the
/// UI screens and providers can be built and explored without a backing
/// project.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  /// When `true`, `Firebase.initializeApp` succeeded for this run.
  static bool initialized = false;

  /// Active flavor for logging / analytics tagging. Set during [start].
  static String activeFlavor = AppEnv.flavorDev;

  static Future<void> start() async {
    await AppEnv.initialize();
    activeFlavor = AppEnv.flavor;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      initialized = true;
      AppLogger.i('Firebase initialised (flavor=$activeFlavor)');
    } on FirebaseException catch (error, stack) {
      AppLogger.w(
        'Firebase init failed — continuing in offline-only mode. '
        'Run `flutterfire configure` to wire a real project.',
        error,
        stack,
      );
    } catch (error, stack) {
      AppLogger.w(
        'Unexpected error during Firebase init. '
        'Continuing without Firebase.',
        error,
        stack,
      );
    }
  }
}
