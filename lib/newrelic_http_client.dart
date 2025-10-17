/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/newrelic_dt_trace.dart';

import 'newrelic_mobile.dart';

class NewRelicHttpClient implements HttpClient {
  final HttpClient client;

  NewRelicHttpClient({HttpClient? client}) : client = client ?? HttpClient();

  @override
  set autoUncompress(bool au) => client.autoUncompress = au;

  @override
  set connectionTimeout(Duration? ct) => client.connectionTimeout = ct;

  @override
  set idleTimeout(Duration it) => client.idleTimeout = it;

  @override
  set maxConnectionsPerHost(int? maxConnectionsPerHost) =>
      client.maxConnectionsPerHost = maxConnectionsPerHost;

  @override
  set userAgent(String? ua) => client.userAgent = ua;

  @override
  set connectionFactory(
      Future<ConnectionTask> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {
    client.connectionFactory = f;
  }

  @override
  set keyLog(Function(String line)? callback) {
    client.keyLog = callback;
  }

  @override
  bool get autoUncompress => client.autoUncompress;

  @override
  Duration? get connectionTimeout => client.connectionTimeout;

  @override
  Duration get idleTimeout => client.idleTimeout;

  @override
  int? get maxConnectionsPerHost => client.maxConnectionsPerHost;

  @override
  String? get userAgent => client.userAgent;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {
    client.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    client.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {
    client.authenticate = f;
  }

  @override
  set authenticateProxy(
      Future<bool> Function(
              String host, int port, String scheme, String? realm)?
          f) {
    client.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {
    client.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    client.close(force: force);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return _wrapRequest(() => client.delete(host, port, path));
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return _wrapRequest(() => client.deleteUrl(url));
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    client.findProxy = f;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return _wrapRequest(() => client.get(host, port, path));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return _wrapRequest(() => client.getUrl(url));
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return _wrapRequest(() => client.head(host, port, path));
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return _wrapRequest(() => client.headUrl(url));
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return _wrapRequest(() => client.open(method, host, port, path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return _wrapRequest(() => client.openUrl(method, url));
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return _wrapRequest(() => client.patch(host, port, path));
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return _wrapRequest(() => client.patchUrl(url));
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return _wrapRequest(() => client.post(host, port, path));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return _wrapRequest(() => client.postUrl(url));
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return _wrapRequest(() => client.put(host, port, path));
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return _wrapRequest(() => client.putUrl(url));
  }

  Future<HttpClientRequest> _wrapRequest(
      Future<HttpClientRequest> Function() requestFunction) async {
    HttpClientRequest request = await requestFunction();

    var traceAttributes = await NewrelicMobile.instance
        .getTraceAttributes(request.uri.toString(), request.method);

    if (traceAttributes != null) {
      if (traceAttributes['traceparent'] != null) {
        request.headers.add('traceparent', traceAttributes['traceparent']!);
      }

      if (traceAttributes['tracestate'] != null) {
        request.headers.add('tracestate', traceAttributes['tracestate']!);
      }

      if (traceAttributes['newrelic'] != null) {
        request.headers.add('newrelic', traceAttributes['newrelic']!);
      }
    }

    return request;
  }
}
