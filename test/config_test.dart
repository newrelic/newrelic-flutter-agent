/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/config.dart';

void main() {
  const accessToken = "12345678";

  test("Test Config Create", () {
    var config = Config(accessToken: accessToken);
    expect(accessToken, config.accessToken);
  });
}
