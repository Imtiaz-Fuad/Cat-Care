/// Domain-level error type. Repositories translate Firebase / network
/// exceptions into `AppFailure` so Providers never expose raw SDK errors.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppFailure($code): $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code});
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code});
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message, {super.code});
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code});
}

class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.code});
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {super.code});
}

/// AI free-tier quota exhausted. Maps to HttpsError('resource-exhausted')
/// in the Cloud Function. UI should show a friendly "limit finished"
/// message and offer to try again later.
class AiQuotaExceededFailure extends AppFailure {
  const AiQuotaExceededFailure(super.message, {super.code});
}
