/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/utils/platform_manager.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/loglevel.dart';
import 'package:newrelic_mobile/network_failure.dart';
import 'package:newrelic_mobile/metricunit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock the platform channel to handle all method calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('newrelic_mobile'),
      (MethodCall methodCall) async {
        // Return appropriate mock responses for different methods
        switch (methodCall.method) {
          case 'startInteraction':
            return 'mock_interaction_id';
          case 'currentSessionId':
            return 'mock_session_id';
          case 'noticeDistributedTrace':
            return <String, dynamic>{};
          case 'getHTTPHeadersTrackingFor':
            return <String>[];
          // Methods that return bool
          case 'setAttribute':
          case 'removeAttribute':
          case 'incrementAttribute':
          case 'recordCustomEvent':
          case 'recordBreadcrumb':
          case 'recordMetric':
          case 'noticeNetworkFailure':
          case 'noticeHttpTransaction':
            return true;
          // Methods that return void or don't need a specific return value
          case 'startAgent':
          case 'setUserId':
          case 'logAttributes':
          case 'endInteraction':
          case 'setMaxEventPoolSize':
          case 'setMaxEventBufferTime':
          case 'setMaxOfflineStorageSize':
          case 'addHTTPHeadersTrackingFor':
          case 'recordError':
          case 'shutDown':
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    // Clean up the mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('newrelic_mobile'),
      null,
    );
  });

  group('Web stub methods return appropriate defaults', () {
    test('PlatformManager returns bool values', () {
      // On web, these should always return false
      // On native, they return true/false based on platform
      final isAndroid = PlatformManager.instance.isAndroid();
      final isIOS = PlatformManager.instance.isIOS();

      expect(isAndroid, isA<bool>());
      expect(isIOS, isA<bool>());
    });

    test('NewrelicMobile methods complete without throwing', () async {
      final config = Config(accessToken: 'test-token');

      // All these methods should complete without errors
      expect(() => NewrelicMobile.instance.setAgentConfiguration(config),
          returnsNormally);
      await NewrelicMobile.instance.setUserId('user123');
      await NewrelicMobile.instance.setAttribute('key', 'value');
      await NewrelicMobile.instance.removeAttribute('key');
      await NewrelicMobile.instance.recordBreadcrumb('test breadcrumb');
    });

    test('NewrelicMobile logging methods work without errors', () async {
      // Test all logging methods - these are void methods
      NewrelicMobile.instance.logInfo('info message');
      NewrelicMobile.instance.logError('error message');
      NewrelicMobile.instance.logWarning('warning message');
      NewrelicMobile.instance.logDebug('debug message');
      NewrelicMobile.instance.logVerbose('verbose message');
      NewrelicMobile.instance.log(LogLevel.INFO, 'log message');

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('NewrelicMobile metric methods work without errors', () async {
      await NewrelicMobile.instance.recordMetric('metric', 'category');
      await NewrelicMobile.instance.recordMetric(
        'metric',
        'category',
        value: 100,
        valueUnit: MetricUnit.BYTES,
        countUnit: MetricUnit.PERCENT,
      );
      await NewrelicMobile.instance.incrementAttribute('counter');
    });

    test('NewrelicMobile network methods work without errors', () async {
      await NewrelicMobile.instance.noticeNetworkFailure(
        'https://example.com',
        'GET',
        1000,
        2000,
        NetworkFailure.unknown,
      );
    });

    test('NewrelicMobile interaction tracking methods work without errors',
        () async {
      final interactionId =
          await NewrelicMobile.instance.startInteraction('test interaction');
      expect(interactionId, isNotNull);

      NewrelicMobile.instance.endInteraction(interactionId);

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('NewrelicMobile custom event recording works', () async {
      await NewrelicMobile.instance.recordCustomEvent(
        'TestEvent',
        eventName: 'User Action',
        eventAttributes: {
          'action': 'click',
          'count': 1,
        },
      );
    });
  });

  group('Async methods complete successfully', () {
    test('startAgent completes without errors', () async {
      final config = Config(
        accessToken: 'test-token',
        analyticsEventEnabled: true,
        networkErrorRequestEnabled: true,
      );

      // Should complete without throwing
      await expectLater(
        NewrelicMobile.instance.startAgent(config),
        completes,
      );
    });

    test('currentSessionId returns a value', () async {
      final sessionId = await NewrelicMobile.instance.currentSessionId();
      // Should return some value (string on native, empty/null on web)
      expect(sessionId, isNotNull);
    });

    test('noticeDistributedTrace completes and returns map', () async {
      final traceData =
          await NewrelicMobile.instance.noticeDistributedTrace({});
      expect(traceData, isA<Map>());
    });

    test('noticeHttpTransaction completes', () async {
      await expectLater(
        NewrelicMobile.instance.noticeHttpTransaction(
          'https://api.example.com/data',
          'GET',
          200,
          DateTime.now().millisecondsSinceEpoch - 1000,
          DateTime.now().millisecondsSinceEpoch,
          0,
          1024,
          {},
        ),
        completes,
      );
    });
  });

  group('Configuration and state management', () {
    test('setAgentConfiguration stores config', () {
      final config = Config(
        accessToken: 'test-token-123',
        crashReportingEnabled: false,
        loggingEnabled: true,
      );

      expect(() => NewrelicMobile.instance.setAgentConfiguration(config),
          returnsNormally);
    });

    test('getAgentConfiguration returns valid config', () {
      final config = Config(
        accessToken: 'test-token-456',
        networkRequestEnabled: true,
      );
      NewrelicMobile.instance.setAgentConfiguration(config);

      final retrievedConfig = NewrelicMobile.instance.getAgentConfiguration();
      expect(retrievedConfig, isNotNull);
      expect(retrievedConfig.accessToken, equals('test-token-456'));
    });

    test('setMaxEventPoolSize accepts valid values', () async {
      await NewrelicMobile.instance.setMaxEventPoolSize(1000);
      await NewrelicMobile.instance.setMaxEventPoolSize(5000);
    });

    test('setMaxEventBufferTime accepts valid values', () async {
      await NewrelicMobile.instance.setMaxEventBufferTime(60);
      await NewrelicMobile.instance.setMaxEventBufferTime(300);
    });

    test('setMaxOfflineStorageSize accepts valid values', () async {
      await NewrelicMobile.instance.setMaxOfflineStorageSize(100);
      await NewrelicMobile.instance.setMaxOfflineStorageSize(500);
    });

    test('addHTTPHeadersTrackingFor accepts header list', () async {
      NewrelicMobile.instance.addHTTPHeadersTrackingFor([
        'Content-Type',
        'Authorization',
        'X-Custom-Header',
      ]);

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('getHTTPHeadersTrackingFor returns list', () async {
      final headers = await NewrelicMobile.instance.getHTTPHeadersTrackingFor();
      expect(headers, isA<List>());
    });
  });

  group('Error handling', () {
    test('recordError handles Exception', () async {
      NewrelicMobile.instance.recordError(
        Exception('Test exception'),
        StackTrace.current,
      );

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('recordError handles StateError with attributes', () async {
      NewrelicMobile.instance.recordError(
        StateError('State error'),
        StackTrace.current,
        attributes: {
          'userId': 'user123',
          'screenName': 'Home',
          'errorCode': 500,
        },
      );

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('recordError handles string error as fatal', () async {
      NewrelicMobile.instance.recordError(
        'String error message',
        StackTrace.current,
        isFatal: true,
      );

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('logAll handles error with attributes', () async {
      NewrelicMobile.instance.logAll(
        Exception('Combined log error'),
        {
          'attribute1': 'value1',
          'attribute2': 42,
          'attribute3': true,
        },
      );

      // Give async operations time to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });
  });

  group('Attribute management', () {
    test('setAttribute and removeAttribute work', () async {
      await NewrelicMobile.instance.setAttribute('stringAttr', 'value');
      await NewrelicMobile.instance.setAttribute('numberAttr', 123);
      await NewrelicMobile.instance.setAttribute('boolAttr', true);

      await NewrelicMobile.instance.removeAttribute('stringAttr');
    });

    test('incrementAttribute works with different values', () async {
      await NewrelicMobile.instance.incrementAttribute('counter');
      await NewrelicMobile.instance.incrementAttribute('counter', value: 5.0);
      await NewrelicMobile.instance.incrementAttribute('counter', value: -2.5);
    });
  });

  group('Agent lifecycle', () {
    test('shutDown completes without errors', () {
      expect(() => NewrelicMobile.instance.shutDown(), returnsNormally);
    });
  });
}
