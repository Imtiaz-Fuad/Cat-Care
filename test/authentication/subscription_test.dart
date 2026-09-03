import 'dart:convert';

import 'package:cat_care/core/constants/app_constants.dart';
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/features/authentication/providers/subscription_provider.dart';
import 'package:cat_care/features/authentication/repositories/subscription_repository.dart';
import 'package:cat_care/features/authentication/screens/subscription_screen.dart';
import 'package:cat_care/features/authentication/services/bdapps_service.dart';
import 'package:cat_care/features/authentication/widgets/subscription_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BdappsService', () {
    test('posts form fields to the OTP proxy endpoint', () async {
      late RequestOptions captured;
      final Dio dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
                captured = options;
                handler.resolve(
                  Response<String>(
                    requestOptions: options,
                    data: jsonEncode(<String, Object>{
                      'success': true,
                      'statusCode': 'S1000',
                      'referenceNo': 'ref-1',
                    }),
                  ),
                );
              },
        ),
      );

      await BdappsService(dio: dio).sendOtp('8801712345678');

      expect(captured.uri.toString(), '${BdappsService.baseUrl}/send_otp.php');
      expect(captured.contentType, Headers.formUrlEncodedContentType);
      expect(captured.data, <String, String>{'user_mobile': '8801712345678'});
    });

    test('rejects malformed proxy responses', () async {
      final Dio dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
                handler.resolve(
                  Response<String>(requestOptions: options, data: 'not-json'),
                );
              },
        ),
      );

      expect(
        () => BdappsService(dio: dio).checkSubscription('8801712345678'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('SubscriptionRepository', () {
    test('does not grant access from generic success alone', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{
          'success': true,
          'statusCode': 'S1000',
        };
      final SubscriptionRepository repository = SubscriptionRepository(service);

      final SubscriptionResult result = await repository.checkSubscription(
        '8801712345678',
      );

      expect(result.isRegistered, isFalse);
    });

    test('accepts REGISTERED with trailing punctuation', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{
          'subscriptionStatus': 'REGISTERED.',
        };
      final SubscriptionRepository repository = SubscriptionRepository(service);

      final SubscriptionResult result = await repository.checkSubscription(
        '8801712345678',
      );

      expect(result.isRegistered, isTrue);
    });
  });

  group('SubscriptionProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('asks for a number when none is stored', () async {
      final SubscriptionProvider provider = await _provider(
        _FakeBdappsService(),
      );

      expect(provider.stage, SubscriptionStage.mobile);
      expect(provider.hasAccess, isFalse);
    });

    test('checks a stored number and grants only registered access', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.bdappsMobileKey: '8801712345678',
      });
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{'subscriptionStatus': 'REGISTERED'};

      final SubscriptionProvider provider = await _provider(service);

      expect(provider.hasAccess, isTrue);
      expect(service.checkedMobile, '8801712345678');
    });

    test('fails closed when the startup check cannot connect', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.bdappsMobileKey: '8801712345678',
      });
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkFailure = const NetworkFailure('Offline');

      final SubscriptionProvider provider = await _provider(service);

      expect(provider.stage, SubscriptionStage.blocked);
      expect(provider.hasAccess, isFalse);
      expect(provider.error, 'Offline');
    });

    test('OTP verification persists the number and unlocks access', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..sendResponse = <String, dynamic>{
          'success': true,
          'referenceNo': 'ref-2',
        }
        ..verifyResponse = <String, dynamic>{
          'subscriptionStatus': 'REGISTERED',
        };
      final SubscriptionProvider provider = await _provider(service);

      await provider.sendOtp('01712345678');
      await provider.verifyOtp('123456');

      expect(provider.hasAccess, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.bdappsMobileKey), '8801712345678');
    });

    test('successful unsubscribe clears access and stored number', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.bdappsMobileKey: '8801712345678',
      });
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{'subscriptionStatus': 'REGISTERED'}
        ..unsubscribeResponse = <String, dynamic>{
          'subscriptionStatus': 'UNREGISTERED',
        };
      final SubscriptionProvider provider = await _provider(service);

      expect(await provider.unsubscribe(), isTrue);

      expect(provider.stage, SubscriptionStage.mobile);
      expect(provider.hasAccess, isFalse);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.bdappsMobileKey), isNull);
    });
  });

  testWidgets(
    'SubscriptionGate does not render protected content without access',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SubscriptionProvider provider = await _provider(
        _FakeBdappsService(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: provider,
          child: const SubscriptionGate(
            child: MaterialApp(home: Text('protected-content')),
          ),
        ),
      );

      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.text('protected-content'), findsNothing);
    },
  );
}

Future<SubscriptionProvider> _provider(_FakeBdappsService service) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final SubscriptionProvider provider = SubscriptionProvider(
    SubscriptionRepository(service),
    preferences,
  );
  await provider.initialize();
  return provider;
}

class _FakeBdappsService extends BdappsService {
  Map<String, dynamic> sendResponse = <String, dynamic>{};
  Map<String, dynamic> verifyResponse = <String, dynamic>{};
  Map<String, dynamic> checkResponse = <String, dynamic>{};
  Map<String, dynamic> unsubscribeResponse = <String, dynamic>{};
  AppFailure? checkFailure;
  String? checkedMobile;

  @override
  Future<Map<String, dynamic>> sendOtp(String mobile) async => sendResponse;

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String otp,
    String referenceNo,
  ) async => verifyResponse;

  @override
  Future<Map<String, dynamic>> checkSubscription(String mobile) async {
    checkedMobile = mobile;
    if (checkFailure case final AppFailure failure) throw failure;
    return checkResponse;
  }

  @override
  Future<Map<String, dynamic>> unsubscribe(String mobile) async =>
      unsubscribeResponse;
}
