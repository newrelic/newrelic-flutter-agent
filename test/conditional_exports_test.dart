/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/utils/platform_manager.dart';
import 'package:newrelic_mobile/config.dart';

void main() {
  test('NewrelicMobile instance should be accessible', () {
    expect(NewrelicMobile.instance, isNotNull);
  });

  test('PlatformManager instance should be accessible', () {
    expect(PlatformManager.instance, isNotNull);
  });

  test('NewrelicMobile should have Config', () {
    final config = Config(accessToken: 'test-token');
    expect(config, isNotNull);
    expect(config.accessToken, equals('test-token'));
  });

  test('PlatformManager methods should be callable', () {
    // These should not throw errors and return boolean values
    expect(() => PlatformManager.instance.isAndroid(), returnsNormally);
    expect(() => PlatformManager.instance.isIOS(), returnsNormally);

    // Verify they return boolean values
    expect(PlatformManager.instance.isAndroid(), isA<bool>());
    expect(PlatformManager.instance.isIOS(), isA<bool>());
  });

  test('Config can be created with various options', () {
    final config = Config(
      accessToken: 'test-token-123',
      analyticsEventEnabled: true,
      networkErrorRequestEnabled: true,
      networkRequestEnabled: true,
      crashReportingEnabled: false,
      interactionTracingEnabled: true,
      httpResponseBodyCaptureEnabled: false,
      loggingEnabled: true,
      webViewInstrumentation: false,
    );

    expect(config.accessToken, equals('test-token-123'));
    expect(config.analyticsEventEnabled, isTrue);
    expect(config.crashReportingEnabled, isFalse);
  });

  test('NewrelicMobile configuration methods work', () {
    final config = Config(accessToken: 'test');
    expect(() => NewrelicMobile.instance.setAgentConfiguration(config),
        returnsNormally);

    final retrievedConfig = NewrelicMobile.instance.getAgentConfiguration();
    expect(retrievedConfig, isNotNull);
    expect(retrievedConfig.accessToken, equals('test'));
  });
}
