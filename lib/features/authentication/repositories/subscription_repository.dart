import '../../../core/errors/app_failure.dart';
import '../services/bdapps_service.dart';

class OtpRequestResult {
  const OtpRequestResult({required this.referenceNo, this.detail});

  final String referenceNo;
  final String? detail;
}

class SubscriptionResult {
  const SubscriptionResult({required this.isRegistered, this.detail});

  final bool isRegistered;
  final String? detail;
}

/// Converts the proxy's JSON responses into subscription domain results.
class SubscriptionRepository {
  const SubscriptionRepository(this._service);

  final BdappsService _service;

  Future<OtpRequestResult> sendOtp(String mobile) async {
    final Map<String, dynamic> response = await _service.sendOtp(mobile);
    final String? reference = _string(response['referenceNo']);
    if (!_requestSucceeded(response) || reference == null) {
      throw UnknownFailure(
        _errorMessage(response, 'Could not send the OTP. Please try again.'),
        code: _string(response['statusCode']) ?? 'otp-request-failed',
      );
    }
    return OtpRequestResult(
      referenceNo: reference,
      detail: _string(response['statusDetail']),
    );
  }

  Future<SubscriptionResult> verifyOtp({
    required String otp,
    required String referenceNo,
  }) async {
    final Map<String, dynamic> response = await _service.verifyOtp(
      otp,
      referenceNo,
    );
    if (!_isRegistered(response)) {
      throw ValidationFailure(
        _errorMessage(response, 'The OTP is invalid or has expired.'),
        code: _string(response['statusCode']) ?? 'otp-verify-failed',
      );
    }
    return SubscriptionResult(
      isRegistered: true,
      detail: _string(response['statusDetail']),
    );
  }

  Future<SubscriptionResult> checkSubscription(String mobile) async {
    final Map<String, dynamic> response = await _service.checkSubscription(
      mobile,
    );
    return SubscriptionResult(
      isRegistered: _isRegistered(response),
      detail: _string(response['statusDetail']),
    );
  }

  Future<SubscriptionResult> unsubscribe(String mobile) async {
    final Map<String, dynamic> response = await _service.unsubscribe(mobile);
    final bool unregistered = _status(response) == 'UNREGISTERED';
    if (!unregistered) {
      throw UnknownFailure(
        _errorMessage(response, 'Could not unsubscribe. Please try again.'),
        code: _string(response['statusCode']) ?? 'unsubscribe-failed',
      );
    }
    return SubscriptionResult(
      isRegistered: false,
      detail: _string(response['statusDetail']),
    );
  }

  static bool _requestSucceeded(Map<String, dynamic> response) {
    return response['success'] == true ||
        _string(response['statusCode'])?.toUpperCase() == 'S1000';
  }

  static bool _isRegistered(Map<String, dynamic> response) =>
      _status(response) == 'REGISTERED';

  static String? _status(Map<String, dynamic> response) {
    final String? value = _string(response['subscriptionStatus']);
    return value?.toUpperCase().replaceAll('.', '').trim();
  }

  static String _errorMessage(Map<String, dynamic> response, String fallback) =>
      _string(response['error']) ??
      _string(response['message']) ??
      _string(response['statusDetail']) ??
      fallback;

  static String? _string(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
