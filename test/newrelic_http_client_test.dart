/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/newrelic_http_client.dart';
import 'package:newrelic_mobile/newrelic_http_overrides.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

import 'newrelic_http_client_test.mocks.dart';

@GenerateMocks([
  HttpClient,
  HttpClientRequest,
  HttpClientResponse,
  HttpClientCredentials,
  HttpHeaders,
  NewRelicHttpClientRequest,
  NewRelicHttpClientResponse
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];
  const String url = 'https://jsonplaceholder.typicode.com';
  const int port = 8888;
  const String path = '/posts';
  const body = {'testKey': 'testValue'};
  const defaultTraceAttributes = <String, dynamic>{
    'id': 'test1',
    'newrelic': 'test3',
    'guid': 'test3',
    'trace.id': 'test3',
    'tracestate': 'test3',
    'traceparent': 'test3'
  };
  Map<String, dynamic>? mockTraceAttributes = null;

  late NewRelicHttpClient newRelicHttpClient;
  late NewRelicHttpClientRequest newRelicHttpClientRequest;
  late NewRelicHttpClientResponse newRelicHttpClientResponse;
  late MockHttpClientRequest mockRequest;
  late MockHttpClientResponse mockResponse;
  late MockHttpHeaders mockHttpHeaders;

  setUpAll(() async {
    Config config = Config(accessToken: '');

    NewrelicMobile.instance.setAgentConfiguration(config);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel('newrelic_mobile'),
            (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'noticeDistributedTrace':
          Map<String, dynamic> map =
              mockTraceAttributes ?? defaultTraceAttributes;
          return map;
        default:
          return true;
      }
    });
  });

  setUp(() {
    newRelicHttpClient = NewRelicHttpClient(client: MockHttpClient());

    mockRequest = MockHttpClientRequest();
    mockResponse = MockHttpClientResponse();
    mockHttpHeaders = MockHttpHeaders();

    when(mockRequest.bufferOutput).thenAnswer((_) => true);
    when(mockRequest.contentLength).thenAnswer((_) => 100);
    when(mockRequest.encoding).thenAnswer((_) => systemEncoding);
    when(mockRequest.followRedirects).thenAnswer((_) => true);
    when(mockRequest.maxRedirects).thenAnswer((_) => 5);
    when(mockRequest.persistentConnection).thenAnswer((_) => true);
    when(mockRequest.headers).thenAnswer((_) => mockHttpHeaders);
    when(mockResponse.headers).thenAnswer((_) => mockHttpHeaders);
    when(mockResponse.statusCode).thenAnswer((_) => 0);

    when(mockHttpHeaders.contentType).thenAnswer((_) => ContentType.json);
    newRelicHttpClientResponse = NewRelicHttpClientResponse(
        mockResponse, mockRequest, DateTime.now().millisecond, {});

    when<dynamic>(mockRequest.close())
        .thenAnswer((_) async => newRelicHttpClientResponse);
    when<dynamic>(mockRequest.done)
        .thenAnswer((_) async => newRelicHttpClientResponse);

    newRelicHttpClientRequest =
        NewRelicHttpClientRequest(mockRequest, DateTime.now().millisecond, {});

    expect(mockRequest, isInstanceOf<HttpClientRequest>());
    expect(mockResponse, isInstanceOf<HttpClientResponse>());
  });

  tearDown(() async {
    mockTraceAttributes = null;
    log.clear();
  });

  void testDistributedTraceRequests() {
    test('expect newrelic custom http client GET URL to return request and log',
        () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient).getUrl(any))
          .thenAnswer((_) async => mockRequest);
      // when<Future<HttpClientResponse>>(newRelicHttpClientRequest.done).thenAnswer((_) async => mockResponse);
      when(mockRequest.done)
          .thenAnswer((_) async => newRelicHttpClientResponse);

      await newRelicHttpClient.getUrl(Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client DELETE URL', () async {
      when<dynamic>(
              (newRelicHttpClient.client as MockHttpClient).deleteUrl(any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.deleteUrl(Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client GET', () async {
      when<dynamic>(
              (newRelicHttpClient.client as MockHttpClient).get(any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.get(url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client DELETE', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient)
              .delete(any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.delete(url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client POST URL', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient).postUrl(any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.postUrl(Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client POST ', () async {
      when<dynamic>(
              (newRelicHttpClient.client as MockHttpClient).post(any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.post(url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client WRITE Body', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient).postUrl(any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.postUrl(Uri.parse(url));
      newRelicHttpClientRequest.write(body.toString());
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client PUT URL', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient).putUrl(any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.putUrl(Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client PUT ', () async {
      when<dynamic>(
              (newRelicHttpClient.client as MockHttpClient).put(any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.put(url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client HEAD URL', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient).headUrl(any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.headUrl(Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client HEAD ', () async {
      when<dynamic>(
              (newRelicHttpClient.client as MockHttpClient).head(any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.head(url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client OPEN URL', () async {
      when<dynamic>(
              (newRelicHttpClient.client as MockHttpClient).openUrl(any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.openUrl('GET', Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client OPEN ', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient)
              .open(any, any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.open('GET', url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client PATCH URL', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient).patchUrl(any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.patchUrl(Uri.parse(url));
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });

    test('expect newrelic custom http client HEAD ', () async {
      when<dynamic>((newRelicHttpClient.client as MockHttpClient)
              .patch(any, any, any))
          .thenAnswer((_) async => mockRequest);

      await newRelicHttpClient.patch(url, port, path);
      await newRelicHttpClientRequest.close();

      expect(log[0].method, 'noticeDistributedTrace');
    });
  }

  group('when noticeDistributedTrace returns a empty map', () {
    setUp(() {
      mockTraceAttributes = {};
    });
    tearDown(() {
      mockTraceAttributes = null;
    });

    testDistributedTraceRequests();
  });

  group('when noticeDistributedTrace returns the trace attributes map', () {
    testDistributedTraceRequests();
  });

  test('expect newrelic custom http client to get client autoUncompress',
      () async {
    when((newRelicHttpClient.client as MockHttpClient).autoUncompress)
        .thenReturn(true);
    expect(newRelicHttpClient.autoUncompress, true);
  });

  test('expect newrelic custom http client to set client autoUncompress',
      () async {
    newRelicHttpClient.autoUncompress = false;
    verify((newRelicHttpClient.client as MockHttpClient).autoUncompress = false)
        .called(1);
  });

  test('expect newrelic custom http client to get client connectionTimeout',
      () async {
    when((newRelicHttpClient.client as MockHttpClient).connectionTimeout)
        .thenReturn(const Duration(seconds: 3));
    expect(newRelicHttpClient.connectionTimeout, const Duration(seconds: 3));
  });

  test('expect newrelic custom http client to set client connectionTimeout',
      () async {
    newRelicHttpClient.connectionTimeout = const Duration(seconds: 3);
    verify((newRelicHttpClient.client as MockHttpClient).connectionTimeout =
            const Duration(seconds: 3))
        .called(1);
  });

  test('expect newrelic custom http client to get client idleTimeout',
      () async {
    when((newRelicHttpClient.client as MockHttpClient).idleTimeout)
        .thenReturn(const Duration(seconds: 5));
    expect(newRelicHttpClient.idleTimeout, const Duration(seconds: 5));
  });

  test('expect newrelic custom http client to set client idleTimeout',
      () async {
    newRelicHttpClient.idleTimeout = const Duration(seconds: 5);
    verify((newRelicHttpClient.client as MockHttpClient).idleTimeout =
            const Duration(seconds: 5))
        .called(1);
  });

  test('expect newrelic custom http client to get client maxConnectionsPerHost',
      () async {
    when((newRelicHttpClient.client as MockHttpClient).maxConnectionsPerHost)
        .thenReturn(5);
    expect(newRelicHttpClient.maxConnectionsPerHost, 5);
  });

  test('expect newrelic custom http client to set client maxConnectionsPerHost',
      () async {
    newRelicHttpClient.maxConnectionsPerHost = 5;
    verify((newRelicHttpClient.client as MockHttpClient).maxConnectionsPerHost =
            5)
        .called(1);
  });

  test('expect newrelic custom http client to get client userAgent', () async {
    when((newRelicHttpClient.client as MockHttpClient).userAgent)
        .thenReturn("user agent");
    expect(newRelicHttpClient.userAgent, "user agent");
  });

  test('expect newrelic custom http client to set client userAgent', () async {
    newRelicHttpClient.userAgent = "user agent";
    verify((newRelicHttpClient.client as MockHttpClient).userAgent =
            "user agent")
        .called(1);
  });

  test('expect newrelic custom http client to call client addClientCredentials',
      () async {
    const String realm = 'test realm string';
    final MockHttpClientCredentials clientCredentials =
        MockHttpClientCredentials();
    newRelicHttpClient.addCredentials(Uri.parse(url), realm, clientCredentials);
    verify(newRelicHttpClient.client
            .addCredentials(Uri.parse(url), realm, clientCredentials))
        .called(1);
  });

  test('expect newrelic custom http client to call client addProxyCredentials',
      () async {
    const String realm = 'test realm string';
    final MockHttpClientCredentials clientCredentials =
        MockHttpClientCredentials();
    newRelicHttpClient.addProxyCredentials(url, port, realm, clientCredentials);
    verify(newRelicHttpClient.client
            .addProxyCredentials(url, port, realm, clientCredentials))
        .called(1);
  });

  test('expect newrelic custom http client to set client authenticate',
      () async {
    final Future<bool> Function(Uri url, String scheme, String realm) f =
        (Uri url, String scheme, String? realm) async => true;

    newRelicHttpClient.authenticate =
        f as Future<bool> Function(Uri url, String scheme, String? realm);
    verify((newRelicHttpClient.client as MockHttpClient).authenticate = f)
        .called(1);
  });

  test('expect newrelic custom http client to set client authenticateProxy',
      () async {
    final Future<bool> Function(
            String host, int port, String scheme, String realm) f =
        (String host, int port, String scheme, String? realm) async => true;
    newRelicHttpClient.authenticateProxy = f as Future<bool> Function(
        String host, int port, String scheme, String? realm);
    verify((newRelicHttpClient.client as MockHttpClient).authenticateProxy = f)
        .called(1);
  });

  test(
      'expect newrelic custom http client to set client badCertificateCallback',
      () async {
    final bool Function(X509Certificate cert, String host, int port) f =
        (X509Certificate cert, String host, int port) => true;
    newRelicHttpClient.badCertificateCallback = f;
    verify((newRelicHttpClient.client as MockHttpClient)
            .badCertificateCallback = f)
        .called(1);
  });

  test('expect newrelic custom http client to call client close', () async {
    newRelicHttpClient.close(force: true);
    verify((newRelicHttpClient.client as MockHttpClient).close(force: true))
        .called(1);
  });

  test('expect newrelic custom http client to set client find Proxy', () async {
    final String Function(Uri uri) f = (Uri uri) => "test";
    newRelicHttpClient.findProxy = f;
    verify((newRelicHttpClient.client as MockHttpClient).findProxy = f)
        .called(1);
  });

  test(' Creating Newrelic Http Client Using NewRelicHttpOverrides', () async {
    final httpOverrides = NewRelicHttpOverrides();
    expect(httpOverrides.createHttpClient(SecurityContext()).runtimeType,
        NewRelicHttpClient().runtimeType);
    final httpOverrides2 = NewRelicHttpOverrides(
        createHttpClientFn: (context) => HttpClient(),
        findProxyFromEnvironmentFn: (uri, env) => "");
    expect(httpOverrides2.createHttpClient(SecurityContext()).runtimeType,
        NewRelicHttpClient().runtimeType);
    expect(httpOverrides2.findProxyFromEnvironment(Uri.parse(url), {}), "");
  });
}
