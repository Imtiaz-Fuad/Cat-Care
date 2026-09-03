import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../repositories/subscription_repository.dart';

enum SubscriptionStage { checking, mobile, otp, blocked, subscribed }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(this._repository, this._preferences);

  final SubscriptionRepository _repository;
  final SharedPreferences _preferences;

  SubscriptionStage _stage = SubscriptionStage.checking;
  String? _mobile;
  String? _referenceNo;
  String? _error;
  bool _busy = false;

  SubscriptionStage get stage => _stage;
  String? get mobile => _mobile;
  String? get error => _error;
  bool get isBusy => _busy;
  bool get hasAccess => _stage == SubscriptionStage.subscribed;

  Future<void> initialize() async {
    _mobile = _preferences.getString(AppConstants.bdappsMobileKey);
    if (_mobile == null || _mobile!.isEmpty) {
      _stage = SubscriptionStage.mobile;
      notifyListeners();
      return;
    }
    await retrySubscriptionCheck();
  }

  Future<void> retrySubscriptionCheck() async {
    final String? number = _mobile;
    if (number == null || number.isEmpty) {
      _stage = SubscriptionStage.mobile;
      _error = null;
      notifyListeners();
      return;
    }
    _stage = SubscriptionStage.checking;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final SubscriptionResult result = await _repository.checkSubscription(
        number,
      );
      _stage = result.isRegistered
          ? SubscriptionStage.subscribed
          : SubscriptionStage.mobile;
      if (!result.isRegistered) {
        _error = 'This number does not have an active subscription.';
      }
    } on AppFailure catch (failure) {
      _stage = SubscriptionStage.blocked;
      _error = failure.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> sendOtp(String input) async {
    late final String normalized;
    try {
      normalized = normalizeBangladeshMobile(input);
    } on ValidationFailure catch (failure) {
      _error = failure.message;
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final OtpRequestResult result = await _repository.sendOtp(normalized);
      _mobile = normalized;
      _referenceNo = result.referenceNo;
      _stage = SubscriptionStage.otp;
    } on AppFailure catch (failure) {
      _error = failure.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String otp) async {
    final String? reference = _referenceNo;
    final String? number = _mobile;
    if (reference == null || number == null) {
      _stage = SubscriptionStage.mobile;
      _error = 'Request a new OTP to continue.';
      notifyListeners();
      return;
    }
    final String code = otp.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      _error = 'Enter the OTP sent to your mobile number.';
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.verifyOtp(otp: code, referenceNo: reference);
      await _preferences.setString(AppConstants.bdappsMobileKey, number);
      _stage = SubscriptionStage.subscribed;
    } on AppFailure catch (failure) {
      _error = failure.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> unsubscribe() async {
    final String? number =
        _mobile ?? _preferences.getString(AppConstants.bdappsMobileKey);
    if (number == null || number.isEmpty) {
      _error = 'No subscribed mobile number was found.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.unsubscribe(number);
      await _preferences.remove(AppConstants.bdappsMobileKey);
      _mobile = null;
      _referenceNo = null;
      _stage = SubscriptionStage.mobile;
      return true;
    } on AppFailure catch (failure) {
      _error = failure.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void useAnotherNumber() {
    _referenceNo = null;
    _stage = SubscriptionStage.mobile;
    _error = null;
    notifyListeners();
  }

  static String normalizeBangladeshMobile(String input) {
    String value = input.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('+')) value = value.substring(1);
    if (value.startsWith('tel:')) value = value.substring(4);
    if (RegExp(r'^01\d{9}$').hasMatch(value)) return '88$value';
    if (RegExp(r'^8801\d{9}$').hasMatch(value)) return value;
    throw const ValidationFailure(
      'Enter a valid Bangladesh mobile number, such as 01XXXXXXXXX.',
      code: 'invalid-mobile',
    );
  }
}
