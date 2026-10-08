/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

// Regression coverage for the unhandled `HttpException: Request has been
// aborted` that reached the zone error handler (PlatformDispatcher.onError in
// an app) when a request was aborted before response headers arrived, e.g. a
// Dio cancel or receiveTimeout.
//
// Like newrelic_http_client_headers_test.dart, this drives a real loopback
// HttpServer through a real HttpClient (flutter_test's stub HttpClient never
// aborts), so setUp clears HttpOverrides.global.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/newrelic_http_client.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

/// What one aborted request did, split by propagation path.
class Outcome {
  /// Error that rejected the Future the caller awaited.
  final Object? callerError;

  /// Errors that leaked as unhandled async errors -- in a real app these reach
  /// PlatformDispatcher.onError.
  final List<Object> zoneErrors;

  Outcome(this.callerError, this.zoneErrors);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late Completer<void> requestReceived;
  HttpOverrides? savedOverrides;
  final List<MethodCall> log = <MethodCall>[];

  setUpAll(() {
    NewrelicMobile.instance.setAgentConfiguration(Config(accessToken: ''));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('newrelic_mobile'),
            (MethodCall call) async {
      log.add(call);
      switch (call.method) {
        case 'getHTTPHeadersTrackingFor':
          return <Object?>[];
        case 'noticeDistributedTrace':
          return <String, dynamic>{};
        default:
          return true;
      }
    });
  });

  setUp(() async {
    log.clear();
    requestReceived = Completer<void>();

    savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;

    // Accepts the request but never sends response headers, so the client is
    // left waiting for headers until it aborts.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest req) {
      if (!requestReceived.isCompleted) requestReceived.complete();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    HttpOverrides.global = savedOverrides;
  });

  /// Starts an instrumented GET, aborts it while waiting for response headers,
  /// and reports caller-visible vs leaked (unhandled) errors separately.
  Future<Outcome> abortWhileWaiting() async {
    final zoneErrors = <Object>[];
    Object? callerError;

    final finished = Completer<void>();
    runZonedGuarded(() async {
      try {
        final client = NewRelicHttpClient(client: HttpClient());
        final request =
            await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/'));
        final response = request.close();
        await requestReceived.future;
        request.abort();
        await response;
      } catch (e) {
        callerError = e;
      }
      if (!finished.isCompleted) finished.complete();
    }, (e, _) => zoneErrors.add(e));

    await finished.future;
    // Let any leaked async error surface before we assert on it.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return Outcome(callerError, zoneErrors);
  }

  int recordErrorCalls() => log.where((c) => c.method == 'recordError').length;

  group('abort before response headers', () {
    test('reaches the caller but leaks no unhandled error', () async {
      final r = await abortWhileWaiting();

      expect(r.callerError, isA<HttpException>(),
          reason: 'the caller must still see the abort');
      expect(r.zoneErrors, isEmpty,
          reason: 'instrumentation must not leak an extra unhandled error');
    });

    test('records the failure with the agent exactly once', () async {
      await abortWhileWaiting();

      expect(recordErrorCalls(), 1);
    });
  });
}
