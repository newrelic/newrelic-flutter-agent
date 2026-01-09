/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/utils/platform_manager.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/loglevel.dart';
import 'package:newrelic_mobile/network_failure.dart';
import 'package:newrelic_mobile/metricunit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web stub methods return appropriate defaults', () {
    test('PlatformManager returns bool values', () {
      // On web, these should always return false
      // On native, they return true/false based on platform
      final isAndroid = PlatformManager.instance.isAndroid();
      final isIOS = PlatformManager.instance.isIOS();

      expect(isAndroid, isA<bool>());
      expect(isIOS, isA<bool>());
    });

    test('NewrelicMobile methods complete without throwing', () {
      final config = Config(accessToken: 'test-token');

      // All these methods should complete without errors
      expect(() => NewrelicMobile.instance.setAgentConfiguration(config),
          returnsNormally);
      expect(
          () => NewrelicMobile.instance.setUserId('user123'), returnsNormally);
      expect(() => NewrelicMobile.instance.setAttribute('key', 'value'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.removeAttribute('key'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.recordBreadcrumb('test breadcrumb'),
          returnsNormally);
    });

    test('NewrelicMobile logging methods work without errors', () {
      // Test all logging methods
      expect(() => NewrelicMobile.instance.logInfo('info message'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.logError('error message'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.logWarning('warning message'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.logDebug('debug message'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.logVerbose('verbose message'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.log(LogLevel.INFO, 'log message'),
          returnsNormally);
    });

    test('NewrelicMobile metric methods work without errors', () {
      expect(() => NewrelicMobile.instance.recordMetric('metric', 'category'),
          returnsNormally);
      expect(
          () => NewrelicMobile.instance.recordMetric(
                'metric',
                'category',
                value: 100,
                valueUnit: MetricUnit.BYTES,
                countUnit: MetricUnit.PERCENT,
              ),
          returnsNormally);
      expect(() => NewrelicMobile.instance.incrementAttribute('counter'),
          returnsNormally);
    });

    test('NewrelicMobile network methods work without errors', () {
      expect(
          () => NewrelicMobile.instance.noticeNetworkFailure(
                'https://example.com',
                'GET',
                1000,
                2000,
                NetworkFailure.unknown,
              ),
          returnsNormally);
    });

    test('NewrelicMobile interaction tracking methods work without errors',
        () async {
      final interactionId =
          await NewrelicMobile.instance.startInteraction('test interaction');
      expect(interactionId, isNotNull);

      expect(() => NewrelicMobile.instance.endInteraction(interactionId),
          returnsNormally);
    });

    test('NewrelicMobile custom event recording works', () {
      expect(
          () => NewrelicMobile.instance.recordCustomEvent(
                'TestEvent',
                eventName: 'User Action',
                eventAttributes: {
                  'action': 'click',
                  'count': 1,
                },
              ),
          returnsNormally);
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

    test('setMaxEventPoolSize accepts valid values', () {
      expect(() => NewrelicMobile.instance.setMaxEventPoolSize(1000),
          returnsNormally);
      expect(() => NewrelicMobile.instance.setMaxEventPoolSize(5000),
          returnsNormally);
    });

    test('setMaxEventBufferTime accepts valid values', () {
      expect(() => NewrelicMobile.instance.setMaxEventBufferTime(60),
          returnsNormally);
      expect(() => NewrelicMobile.instance.setMaxEventBufferTime(300),
          returnsNormally);
    });

    test('setMaxOfflineStorageSize accepts valid values', () {
      expect(() => NewrelicMobile.instance.setMaxOfflineStorageSize(100),
          returnsNormally);
      expect(() => NewrelicMobile.instance.setMaxOfflineStorageSize(500),
          returnsNormally);
    });

    test('addHTTPHeadersTrackingFor accepts header list', () {
      expect(
          () => NewrelicMobile.instance.addHTTPHeadersTrackingFor([
                'Content-Type',
                'Authorization',
                'X-Custom-Header',
              ]),
          returnsNormally);
    });

    test('getHTTPHeadersTrackingFor returns list', () async {
      final headers = await NewrelicMobile.instance.getHTTPHeadersTrackingFor();
      expect(headers, isA<List>());
    });
  });

  group('Error handling', () {
    test('recordError handles Exception', () {
      expect(
          () => NewrelicMobile.instance.recordError(
                Exception('Test exception'),
                StackTrace.current,
              ),
          returnsNormally);
    });

    test('recordError handles StateError with attributes', () {
      expect(
          () => NewrelicMobile.instance.recordError(
                StateError('State error'),
                StackTrace.current,
                attributes: {
                  'userId': 'user123',
                  'screenName': 'Home',
                  'errorCode': 500,
                },
              ),
          returnsNormally);
    });

    test('recordError handles string error as fatal', () {
      expect(
          () => NewrelicMobile.instance.recordError(
                'String error message',
                StackTrace.current,
                isFatal: true,
              ),
          returnsNormally);
    });

    test('logAll handles error with attributes', () {
      expect(
          () => NewrelicMobile.instance.logAll(
                Exception('Combined log error'),
                {
                  'attribute1': 'value1',
                  'attribute2': 42,
                  'attribute3': true,
                },
              ),
          returnsNormally);
    });
  });

  group('Attribute management', () {
    test('setAttribute and removeAttribute work', () {
      expect(() => NewrelicMobile.instance.setAttribute('stringAttr', 'value'),
          returnsNormally);
      expect(() => NewrelicMobile.instance.setAttribute('numberAttr', 123),
          returnsNormally);
      expect(() => NewrelicMobile.instance.setAttribute('boolAttr', true),
          returnsNormally);

      expect(() => NewrelicMobile.instance.removeAttribute('stringAttr'),
          returnsNormally);
    });

    test('incrementAttribute works with different values', () {
      expect(() => NewrelicMobile.instance.incrementAttribute('counter'),
          returnsNormally);
      expect(
          () =>
              NewrelicMobile.instance.incrementAttribute('counter', value: 5.0),
          returnsNormally);
      expect(
          () => NewrelicMobile.instance
              .incrementAttribute('counter', value: -2.5),
          returnsNormally);
    });
  });

  group('Agent lifecycle', () {
    test('shutDown completes without errors', () {
      expect(() => NewrelicMobile.instance.shutDown(), returnsNormally);
    });
  });
}
