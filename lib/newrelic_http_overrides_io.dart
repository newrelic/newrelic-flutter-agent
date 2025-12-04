/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:io';

import 'package:newrelic_mobile/newrelic_http_client.dart';

class NewRelicHttpOverrides extends HttpOverrides {
  final String Function(Uri? url, Map<String, String>? environment)?
      findProxyFromEnvironmentFn;
  final HttpClient Function(SecurityContext? context)? createHttpClientFn;
  final HttpOverrides? current;

  NewRelicHttpOverrides({
    this.current,
    this.findProxyFromEnvironmentFn,
    this.createHttpClientFn,
  });

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return NewRelicHttpClient(
        client: createHttpClientFn != null
            ? createHttpClientFn!(context)
            : current?.createHttpClient(context) ??
                super.createHttpClient(context));
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return findProxyFromEnvironmentFn != null
        ? findProxyFromEnvironmentFn!(url, environment ?? {})
        : super.findProxyFromEnvironment(url, environment);
  }
}
