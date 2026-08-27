/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

// Regression coverage for #222: instrumentation must never fail the request it
// is observing when collecting tracked HTTP headers.
//
// These tests drive a real loopback HttpServer through a real HttpClient so the
// real dart:io HttpHeaders is exercised. flutter_test's binding installs a stub
// HttpClient whose _MockHttpHeaders.add() is a no-op and whose operator[]
// returns const [], so the multi-value path cannot reproduce through it --
// setUp clears HttpOverrides.global to get the real implementation back.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/newrelic_http_client.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

/// What one instrumented request did, split by propagation path.
class Outcome {
  /// Error that rejected the Future the caller awaited (close()/done).
  final Object? callerError;

  /// Errors that leaked as unhandled async errors -- in a real app these reach
  /// the zone error handler / FlutterError.onError.
  final List<Object> zoneErrors;
  final int? status;

  Outcome(this.callerError, this.zoneErrors, this.status);

  @override
  String toString() =>
      'status=$status callerError=$callerError zoneErrors=$zoneErrors';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  HttpOverrides? savedOverrides;
  final List<MethodCall> log = <MethodCall>[];

  /// Stands in for what the native agent reports as tracked headers.
  /// Deliberately Object? so tests can inject hostile channel payloads.
  Object? trackedHeaders;

  setUpAll(() {
    NewrelicMobile.instance.setAgentConfiguration(Config(accessToken: ''));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('newrelic_mobile'),
            (MethodCall call) async {
      log.add(call);
      switch (call.method) {
        case 'getHTTPHeadersTrackingFor':
          return trackedHeaders;
        case 'noticeDistributedTrace':
          return <String, dynamic>{};
        default:
          return true;
      }
    });
  });

  setUp(() async {
    log.clear();
    trackedHeaders = <Object?>[];

    savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest req) async {
      req.response.statusCode = 200;
      req.response.write('ok');
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    HttpOverrides.global = savedOverrides;
  });

  Uri uri() => Uri.parse('http://127.0.0.1:${server.port}/');

  /// Issues one instrumented GET, consuming the response body so telemetry is
  /// flushed, and reports caller-visible vs leaked errors separately.
  Future<Outcome> get(
      {void Function(HttpClientRequest)? prepare,
      bool alsoAwaitDone = false}) async {
    final zoneErrors = <Object>[];
    Object? callerError;
    int? status;

    final finished = Completer<void>();
    runZonedGuarded(() async {
      try {
        final client = NewRelicHttpClient(client: HttpClient());
        final request = await client.getUrl(uri());
        if (prepare != null) prepare(request);
        // done only completes once the request has been closed, so a caller
        // using it must still call close().
        final Future<HttpClientResponse>? done =
            alsoAwaitDone ? request.done : null;
        final response = await request.close();
        status = response.statusCode;
        await response.drain();
        if (done != null) await done;
      } catch (e) {
        callerError = e;
      }
      if (!finished.isCompleted) finished.complete();
    }, (e, _) => zoneErrors.add(e));

    await finished.future;
    // Let any leaked async error surface before we assert on it.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return Outcome(callerError, zoneErrors, status);
  }

  List<MethodCall> callsTo(String method) =>
      log.where((c) => c.method == method).toList();

  Map<String, dynamic>? recordedHttpParams() {
    final calls = callsTo('noticeHttpTransaction');
    if (calls.isEmpty) return null;
    final args = Map<String, dynamic>.from(calls.last.arguments as Map);
    final params = args['params'];
    return params == null ? null : Map<String, dynamic>.from(params as Map);
  }

  void expectCleanRequest(Outcome r) {
    expect(r.callerError, isNull,
        reason: 'instrumentation must not fail the caller\'s request');
    expect(r.zoneErrors, isEmpty,
        reason: 'instrumentation must not leak unhandled async errors');
    expect(r.status, 200);
  }

  group('tracked header collection', () {
    test('records a single-valued tracked header', () async {
      trackedHeaders = <Object?>['x-custom'];

      final r = await get(prepare: (req) => req.headers.add('x-custom', 'a'));

      expectCleanRequest(r);
      expect(recordedHttpParams(), containsPair('x-custom', 'a'));
    });

    test('joins a multi-valued tracked header instead of throwing', () async {
      trackedHeaders = <Object?>['x-custom'];

      final r = await get(
          prepare: (req) => req.headers
            ..add('x-custom', 'a')
            ..add('x-custom', 'b'));

      expectCleanRequest(r);
      expect(recordedHttpParams(), containsPair('x-custom', 'a, b'));
    });

    test('omits a tracked header the request does not carry', () async {
      trackedHeaders = <Object?>['x-absent'];

      final r = await get();

      expectCleanRequest(r);
      expect(recordedHttpParams() ?? const {}, isNot(contains('x-absent')));
    });

    test('a caller that also awaits done sees no error or leak', () async {
      trackedHeaders = <Object?>['x-custom'];

      final r = await get(
          alsoAwaitDone: true,
          prepare: (req) => req.headers
            ..add('x-custom', 'a')
            ..add('x-custom', 'b'));

      expectCleanRequest(r);
      expect(recordedHttpParams(), containsPair('x-custom', 'a, b'));
    });
  });

  group('hostile tracked-header input degrades gracefully', () {
    test('invalid header field name does not fail the request', () async {
      // operator[] runs the same _validateField as value(), which throws
      // FormatException -- addHTTPHeadersTrackingFor does not validate input.
      trackedHeaders = <Object?>['x custom'];

      expectCleanRequest(await get());
    });

    test('non-String channel entry does not fail the request', () async {
      trackedHeaders = <Object?>[42];

      expectCleanRequest(await get());
    });

    test('null channel result does not fail the request', () async {
      trackedHeaders = null;

      expectCleanRequest(await get());
    });

    test('non-Iterable channel result does not fail the request', () async {
      trackedHeaders = true;

      expectCleanRequest(await get());
    });

    test('a good header is still captured alongside a bad one', () async {
      trackedHeaders = <Object?>['x custom', 'x-good', 7];

      final r = await get(prepare: (req) => req.headers.add('x-good', 'yes'));

      expectCleanRequest(r);
      expect(recordedHttpParams(), containsPair('x-good', 'yes'));
    });
  });

  group('response wrapping is not duplicated', () {
    test('reports exactly one transaction per request', () async {
      trackedHeaders = <Object?>['x-custom'];

      final r = await get(prepare: (req) => req.headers.add('x-custom', 'a'));

      expectCleanRequest(r);
      expect(callsTo('noticeHttpTransaction'), hasLength(1));
    });

    test('a connection failure is recorded once and surfaced to the caller',
        () async {
      // Point at a port nothing is listening on.
      final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = closed.port;
      await closed.close(force: true);

      final zoneErrors = <Object>[];
      Object? callerError;
      final finished = Completer<void>();

      runZonedGuarded(() async {
        try {
          final client = NewRelicHttpClient(client: HttpClient());
          final request = await client
              .getUrl(Uri.parse('http://127.0.0.1:$deadPort/'));
          await request.close();
        } catch (e) {
          callerError = e;
        }
        if (!finished.isCompleted) finished.complete();
      }, (e, _) => zoneErrors.add(e));

      await finished.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(callerError, isNotNull,
          reason: 'a real connection failure must still reach the caller');
      expect(zoneErrors, isEmpty,
          reason: 'the failure must not also leak as an unhandled async error');
      expect(callsTo('recordError'), hasLength(1),
          reason: 'the failure must be recorded once, not once per wrapper');
    });
  });
}