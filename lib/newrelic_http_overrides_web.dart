/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/// Web stub implementation of NewRelicHttpOverrides
/// HttpOverrides is not available on web platforms
class NewRelicHttpOverrides {
  final String Function(Uri? url, Map<String, String>? environment)?
      findProxyFromEnvironmentFn;
  final dynamic Function(dynamic context)? createHttpClientFn;
  final dynamic current;

  NewRelicHttpOverrides({
    this.current,
    this.findProxyFromEnvironmentFn,
    this.createHttpClientFn,
  });
}
