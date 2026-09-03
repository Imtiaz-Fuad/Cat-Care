import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';

/// HTTP client for the CatCare BD bdApps proxy.
///
/// The proxy accepts URL-encoded form fields and keeps the bdApps application
/// credentials out of the distributed Flutter application.
class BdappsService {
  BdappsService({Dio? dio}) : _dio = dio ?? Dio();

  static const String baseUrl =
      'https://www.bdappsdigitalapps.com/NADB26088_Final';

  final Dio _dio;

  Future<Map<String, dynamic>> sendOtp(String mobile) =>
      _post('/send_otp.php', <String, String>{'user_mobile': mobile});

  Future<Map<String, dynamic>> verifyOtp(String otp, String referenceNo) =>
      _post('/verify_otp.php', <String, String>{
        'Otp': otp,
        'referenceNo': referenceNo,
      });

  Future<Map<String, dynamic>> checkSubscription(String mobile) =>
      _post('/check_subscription.php', <String, String>{'user_mobile': mobile});

  Future<Map<String, dynamic>> unsubscribe(String mobile) =>
      _post('/unsubscribe.php', <String, String>{'user_mobile': mobile});

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> fields,
  ) async {
    try {
      final Response<String> response = await _dio.post<String>(
        '$baseUrl$path',
        data: fields,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final String body = response.data?.trim() ?? '';
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
    } on AppFailure {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw const NetworkFailure(
          'Could not reach the subscription service. Check your connection and retry.',
          code: 'bdapps-network',
        );
      }
      throw NetworkFailure(
        'The subscription service could not complete the request.',
        code: 'bdapps-${error.response?.statusCode ?? 'request'}',
      );
    } on FormatException {
      throw const UnknownFailure(
        'The subscription service returned an unreadable response.',
        code: 'invalid-json',
      );
    }
  }
}
