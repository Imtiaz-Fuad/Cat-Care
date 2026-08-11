import 'package:logger/logger.dart';

/// App-wide logger. Use ONLY this — never `print` (analysis_options.yaml).
///
/// Architecture rule: print/log goes through this service so future crash-
/// reporting hooks (e.g. Crashlytics) can be wired in one place without
/// sprinkling `print`/log calls across the codebase.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 6,
      lineLength: 100,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void d(Object? message, [Object? error, StackTrace? stack]) {
    _logger.d(message, error: error, stackTrace: stack);
  }

  static void i(Object? message, [Object? error, StackTrace? stack]) {
    _logger.i(message, error: error, stackTrace: stack);
  }

  static void w(Object? message, [Object? error, StackTrace? stack]) {
    _logger.w(message, error: error, stackTrace: stack);
  }

  static void e(Object? message, [Object? error, StackTrace? stack]) {
    _logger.e(message, error: error, stackTrace: stack);
  }
}
