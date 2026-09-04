import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_failure.dart';

/// HTTP client for the CatCare BD bdApps proxy.
///
/// The proxy accepts URL-encoded form fields and keeps the bdApps application
/// credentials out of the distributed Flutter application.
class BdappsService {
  BdappsService([this._client]);

  static const String baseUrl =
      'https://www.bdappsdigitalapps.com/NADB26088_Final';

  /// Tests can inject a client. Production uses the top-level [http.post]
  /// helper, matching the known-working bdApps integration and ensuring each
  /// operation gets a fresh client instead of reusing a stale connection.
  final http.Client? _client;

  Future<Map<String, dynamic>> sendOtp(String mobile) =>
      _post('/send_otp.php', <String, String>{
        'user_mobile': _normalizeBangladeshMobile(mobile),
      });

  Future<Map<String, dynamic>> verifyOtp(String otp, String referenceNo) =>
      _post('/verify_otp.php', <String, String>{
        'Otp': otp,
        'referenceNo': referenceNo,
      });

  Future<Map<String, dynamic>> checkSubscription(String mobile) =>
      _post('/check_subscription.php', <String, String>{
        'user_mobile': _normalizeBangladeshMobile(mobile),
      });

  Future<Map<String, dynamic>> unsubscribe(String mobile) =>
      _post('/unsubscribe.php', <String, String>{
        'user_mobile': _normalizeBangladeshMobile(mobile),
      });

  static String _normalizeBangladeshMobile(String input) {
    String value = input.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (value.startsWith('tel:')) value = value.substring(4);
    if (value.startsWith('+')) value = value.substring(1);
    if (RegExp(r'^01\d{9}$').hasMatch(value)) return '88$value';
    if (RegExp(r'^8801\d{9}$').hasMatch(value)) return value;
    return value;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> fields,
  ) async {
    try {
      final Uri uri = Uri.parse('$baseUrl$path');
      final Future<http.Response> request = _client == null
          ? http.post(uri, body: fields)
          : _client.post(uri, body: fields);
      final Stopwatch stopwatch = Stopwatch()..start();
      final http.Response response = await request;
      stopwatch.stop();
      debugPrint(
        'BdappsService response $path: HTTP ${response.statusCode} '
        'after ${stopwatch.elapsedMilliseconds} ms',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NetworkFailure(
          'The subscription service could not complete the request.',
          code: 'bdapps-${response.statusCode}',
        );
      }
      final String body = response.body.trim();
      if (body.isEmpty) {
        throw const UnknownFailure(
          'The subscription service returned an empty response.',
          code: 'empty-response',
        );
      }
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const UnknownFailure(
          'The subscription service returned an unexpected response.',
          code: 'invalid-response',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on AppFailure catch (error) {
      debugPrint(
        'BdappsService raw exception (${error.runtimeType}): $error',
      );
      rethrow;
    } on TimeoutException catch (error) {
      debugPrint(
        'BdappsService raw exception (${error.runtimeType}): $error',
      );
      throw const NetworkFailure(
        'The subscription service timed out. Check your connection and retry.',
        code: 'bdapps-timeout',
      );
    } on http.ClientException catch (error) {
      debugPrint(
        'BdappsService raw exception (${error.runtimeType}): $error',
      );
      throw const NetworkFailure(
        'Could not reach the subscription service. Check your connection and retry.',
        code: 'bdapps-network',
      );
    } on FormatException catch (error) {
      debugPrint(
        'BdappsService raw exception (${error.runtimeType}): $error',
      );
      throw const UnknownFailure(
        'The subscription service returned an unreadable response.',
        code: 'invalid-json',
      );
    }
  }
}
