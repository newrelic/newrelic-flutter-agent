/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/newrelic_http_overrides.dart';

void main() {
  test('findProxyFromEnvironment handles null environment safely', () {
    // This test verifies the null safety fix for environment parameter
    final overrides = NewRelicHttpOverrides(
      findProxyFromEnvironmentFn: (url, environment) {
        // This function expects non-null environment
        expect(environment, isNotNull);
        expect(environment, isA<Map<String, String>>());
        return 'DIRECT';
      },
    );

    // Call with null environment - should convert to empty map
    final result = overrides.findProxyFromEnvironment(
      Uri.parse('https://example.com'),
      null, // Null environment
    );

    expect(result, equals('DIRECT'));
  });

  test('findProxyFromEnvironment handles non-null environment correctly', () {
    final overrides = NewRelicHttpOverrides(
      findProxyFromEnvironmentFn: (url, environment) {
        expect(environment, isNotNull);
        expect(environment?['HTTP_PROXY'], equals('proxy.example.com'));
        return 'PROXY ${environment?['HTTP_PROXY']}';
      },
    );

    final result = overrides.findProxyFromEnvironment(
      Uri.parse('https://example.com'),
      {'HTTP_PROXY': 'proxy.example.com'},
    );

    expect(result, equals('PROXY proxy.example.com'));
  });

  test('findProxyFromEnvironment falls back to super when no custom function',
      () {
    final overrides = NewRelicHttpOverrides();

    // Should not throw with null environment
    expect(
      () => overrides.findProxyFromEnvironment(
        Uri.parse('https://example.com'),
        null,
      ),
      returnsNormally,
    );
  });
}
