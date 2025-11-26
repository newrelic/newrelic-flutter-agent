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

  test('NewrelicMobile methods should be callable without errors', () {
    // These should not throw errors even if they are no-ops on web
    expect(() => NewrelicMobile.instance.setAgentConfiguration(
      Config(accessToken: 'test')
    ), returnsNormally);
    
    expect(() => NewrelicMobile.instance.recordError(
      Exception('test'),
      StackTrace.current,
    ), returnsNormally);
  });

  test('PlatformManager methods should be callable', () {
    // These should not throw errors
    expect(() => PlatformManager.instance.isAndroid(), returnsNormally);
    expect(() => PlatformManager.instance.isIOS(), returnsNormally);
  });
}
