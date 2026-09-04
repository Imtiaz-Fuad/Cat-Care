import 'dart:convert';

import 'package:cat_care/core/constants/app_constants.dart';
import 'package:cat_care/core/errors/app_failure.dart';
import 'package:cat_care/features/authentication/providers/subscription_provider.dart';
import 'package:cat_care/features/authentication/repositories/subscription_repository.dart';
import 'package:cat_care/features/authentication/screens/subscription_screen.dart';
import 'package:cat_care/features/authentication/services/bdapps_service.dart';
import 'package:cat_care/features/authentication/widgets/subscription_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BdappsService', () {
    test('posts form fields to the OTP proxy endpoint', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'success': true,
            'statusCode': 'S1000',
            'referenceNo': 'ref-1',
          }),
          200,
        );
      });

      await BdappsService(client).sendOtp('8801712345678');

      expect(captured.url.toString(), '${BdappsService.baseUrl}/send_otp.php');
      expect(
        captured.headers['content-type'],
        startsWith('application/x-www-form-urlencoded'),
      );
      expect(captured.bodyFields, <String, String>{
        'user_mobile': '8801712345678',
      });
    });

    test('normalizes a local Bangladesh mobile before sending OTP', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, Object>{
            'success': true,
            'statusCode': 'S1000',
            'referenceNo': 'ref-1',
          }),
          200,
        );
      });

      await BdappsService(client).sendOtp('01712345678');

      expect(captured.bodyFields['user_mobile'], '8801712345678');
    });

    test('rejects malformed proxy responses', () async {
      final MockClient client = MockClient(
        (_) async => http.Response('not-json', 200),
      );

      expect(
        () => BdappsService(client).checkSubscription('8801712345678'),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test(
      'uses the proxy field names for verify, check, and unsubscribe',
      () async {
        final List<http.Request> requests = <http.Request>[];
        final MockClient client = MockClient((http.Request request) async {
          requests.add(request);
          return http.Response('{}', 200);
        });
        final BdappsService service = BdappsService(client);

        await service.verifyOtp('123456', 'reference-1');
        await service.checkSubscription('8801712345678');
        await service.unsubscribe('8801712345678');

        expect(requests[0].url.path, endsWith('/verify_otp.php'));
        expect(requests[0].bodyFields, <String, String>{
          'Otp': '123456',
          'referenceNo': 'reference-1',
        });
        expect(requests[1].url.path, endsWith('/check_subscription.php'));
        expect(requests[1].bodyFields, <String, String>{
          'user_mobile': '8801712345678',
        });
        expect(requests[2].url.path, endsWith('/unsubscribe.php'));
        expect(requests[2].bodyFields, <String, String>{
          'user_mobile': '8801712345678',
        });
      },
    );
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

    test('accepts the proxy isSubscribed flag', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{
          'isSubscribed': true,
          'statusCode': 'S1000',
        };
      final SubscriptionRepository repository = SubscriptionRepository(service);

      final SubscriptionResult result = await repository.checkSubscription(
        '8801712345678',
      );

      expect(result.isRegistered, isTrue);
    });

    test('accepts OTP verification success from statusCode alone', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..verifyResponse = <String, dynamic>{'statusCode': 'S1000'};
      final SubscriptionRepository repository = SubscriptionRepository(service);

      final SubscriptionResult result = await repository.verifyOtp(
        otp: '123456',
        referenceNo: 'reference-1',
      );

      expect(result.isRegistered, isTrue);
    });

    test('accepts unsubscribe success without subscriptionStatus', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..unsubscribeResponse = <String, dynamic>{'success': true};
      final SubscriptionRepository repository = SubscriptionRepository(service);

      final SubscriptionResult result = await repository.unsubscribe(
        '8801712345678',
      );

      expect(result.isRegistered, isFalse);
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

    test(
      'OTP verification checks status before persisting and unlocking',
      () async {
        final _FakeBdappsService service = _FakeBdappsService()
          ..sendResponse = <String, dynamic>{
            'success': true,
            'referenceNo': 'ref-2',
          }
          ..verifyResponse = <String, dynamic>{'statusCode': 'S1000'}
          ..checkResponse = <String, dynamic>{
            'subscriptionStatus': 'REGISTERED',
          };
        final SubscriptionProvider provider = await _provider(service);

        await provider.sendOtp('01712345678');
        await provider.verifyOtp('123456');

        expect(provider.hasAccess, isTrue);
        expect(service.checkedMobile, '8801712345678');
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AppConstants.bdappsMobileKey), '8801712345678');
      },
    );

    test('OTP success does not unlock an unregistered number', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..sendResponse = <String, dynamic>{
          'success': true,
          'referenceNo': 'ref-2',
        }
        ..verifyResponse = <String, dynamic>{'statusCode': 'S1000'}
        ..checkResponse = <String, dynamic>{
          'subscriptionStatus': 'UNREGISTERED',
        };
      final SubscriptionProvider provider = await _provider(service);

      await provider.sendOtp('01712345678');
      await provider.verifyOtp('123456');

      expect(provider.hasAccess, isFalse);
      expect(provider.stage, SubscriptionStage.awaitingConfirmation);
      expect(provider.error, isNull);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.bdappsMobileKey), isNull);
    });

    test('awaiting confirmation can return to subscription check', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..sendResponse = <String, dynamic>{
          'success': true,
          'referenceNo': 'ref-2',
        }
        ..verifyResponse = <String, dynamic>{'statusCode': 'S1000'}
        ..checkResponse = <String, dynamic>{
          'subscriptionStatus': 'UNREGISTERED',
        };
      final SubscriptionProvider provider = await _provider(service);

      await provider.sendOtp('01712345678');
      await provider.verifyOtp('123456');
      provider.returnToSubscriptionCheck();

      expect(provider.stage, SubscriptionStage.mobile);
      expect(provider.mobile, '8801712345678');
      expect(provider.hasAccess, isFalse);
    });

    test('manual check unlocks an externally subscribed number', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{'subscriptionStatus': 'REGISTERED'};
      final SubscriptionProvider provider = await _provider(service);

      await provider.checkMobileSubscription('01712345678');

      expect(provider.hasAccess, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.bdappsMobileKey), '8801712345678');
    });

    test('manual check keeps an unregistered number gated', () async {
      final _FakeBdappsService service = _FakeBdappsService()
        ..checkResponse = <String, dynamic>{
          'subscriptionStatus': 'UNREGISTERED',
        };
      final SubscriptionProvider provider = await _provider(service);

      await provider.checkMobileSubscription('01712345678');

      expect(provider.hasAccess, isFalse);
      expect(provider.error, contains('No active subscription'));
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
      expect(find.text('Not subscribed yet? Tap here'), findsOneWidget);
      expect(find.text('protected-content'), findsNothing);

      await tester.tap(find.text('Not subscribed yet? Tap here'));
      await tester.pump();

      expect(find.text('Send OTP to subscribe'), findsOneWidget);
      expect(
        find.textContaining('Enter a valid Bangladesh mobile number'),
        findsNothing,
      );
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
