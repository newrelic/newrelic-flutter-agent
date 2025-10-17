/*
 *
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 *
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
      Future<ConnectionTask<Socket>> Function(
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
      Future<bool> Function(String host, int port, String scheme, String? realm)? f) {
    client.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {
    client.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    client.close(force: force);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return _wrapRequest(
        client.delete(host, port, path), 'DELETE', Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return _wrapRequest(client.deleteUrl(url), 'DELETE', url);
  }

  @override
  set findProxy(String Function(Uri uri)? f) {
    client.findProxy = f;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return _wrapRequest(
        client.get(host, port, path), 'GET', Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return _wrapRequest(client.getUrl(url), 'GET', url);
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return _wrapRequest(
        client.head(host, port, path), 'HEAD', Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return _wrapRequest(client.headUrl(url), 'HEAD', url);
  }

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) {
    return _wrapRequest(
        client.open(method, host, port, path), method, Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return _wrapRequest(client.openUrl(method, url), method, url);
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return _wrapRequest(
        client.patch(host, port, path), 'PATCH', Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return _wrapRequest(client.patchUrl(url), 'PATCH', url);
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return _wrapRequest(
        client.post(host, port, path), 'POST', Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return _wrapRequest(client.postUrl(url), 'POST', url);
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return _wrapRequest(
        client.put(host, port, path), 'PUT', Uri(scheme: 'http', host: host, port: port, path: path));
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return _wrapRequest(client.putUrl(url), 'PUT', url);
  }

  Future<HttpClientRequest> _wrapRequest(Future<HttpClientRequest> futureRequest, String method, Uri uri) async {
    HttpClientRequest actualRequest = await futureRequest;

    Map<String, String?> traceAttributes = await NewRelicDtTrace.getTraceAttributes(uri.toString(), method);
    List<String> availableTraceAttributesHeaders = [];
    for (String header in traceAttributes.keys) {
      availableTraceAttributesHeaders.add(header);
    }

    for (String header in availableTraceAttributesHeaders) {
      final value = traceAttributes[header];
      if (value != null) {
        actualRequest.headers.add(header, value);
      }
    }

    return NewRelicHttpClientRequest(actualRequest, uri, method, Config.getInstance());
  }
}

class NewRelicHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest request;
  final String method;
  final Uri uri;
  final Config config;
  String? contentType;
  int? contentLength;
  List<int>? bodyData;

  NewRelicHttpClientRequest(this.request, this.uri, this.method, this.config);

  @override
  bool get bufferOutput => request.bufferOutput;

  @override
  set bufferOutput(bool bufferOutput) => request.bufferOutput = bufferOutput;

  @override
  int get contentLength => request.contentLength;

  @override
  set contentLength(int contentLength) {
    this.contentLength = contentLength;
    request.contentLength = contentLength;
  }

  @override
  Encoding get encoding => request.encoding;

  @override
  set encoding(Encoding encoding) => request.encoding = encoding;

  @override
  bool get followRedirects => request.followRedirects;

  @override
  set followRedirects(bool followRedirects) => request.followRedirects = followRedirects;

  @override
  HttpHeaders get headers => request.headers;

  @override
  int get maxRedirects => request.maxRedirects;

  @override
  set maxRedirects(int maxRedirects) => request.maxRedirects = maxRedirects;

  @override
  bool get persistentConnection => request.persistentConnection;

  @override
  set persistentConnection(bool persistentConnection) => request.persistentConnection = persistentConnection;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    request.abort(exception, stackTrace);
  }

  @override
  void add(List<int> data) {
    if (bodyData == null) {
      bodyData = [];
    }

    bodyData!.addAll(data);
    request.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    request.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return request.addStream(stream);
  }

  @override
  Future<HttpClientResponse> close() async {
    HttpClientResponse response = await request.close();
    return NewRelicHttpClientResponse(response, this);
  }

  @override
  HttpConnectionInfo? get connectionInfo => request.connectionInfo;

  @override
  List<Cookie> get cookies => request.cookies;

  @override
  Future<HttpClientResponse> done => request.done.then((response) => NewRelicHttpClientResponse(response, this));

  @override
  Future flush() {
    return request.flush();
  }

  @override
  String get method => request.method;

  @override
  Uri get uri => request.uri;

  @override
  void write(Object? obj) {
    var data = obj.toString();
    if (bodyData == null) {
      bodyData = [];
    }

    bodyData!.addAll(utf8.encode(data));
    request.write(obj);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    request.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    request.writeCharCode(charCode);
  }

  @override
  void writeln([Object? obj = ""]) {
    request.writeln(obj);
  }
}

class NewRelicHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final HttpClientResponse response;
  final NewRelicHttpClientRequest request;
  final Config config;
  late int bytesReceived = 0;
  late String? responseBody;
  late List<int> bodyData;
  bool isRedirect = false;

  NewRelicHttpClientResponse(this.response, this.request) : config = request.config {
    isRedirect = response.isRedirect;
  }

  @override
  X509Certificate? get certificate => response.certificate;

  @override
  HttpClientResponseCompressionState get compressionState => response.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => response.connectionInfo;

  @override
  int get contentLength => response.contentLength;

  @override
  List<Cookie> get cookies => response.cookies;

  @override
  Future<Socket> detachSocket() {
    return response.detachSocket();
  }

  @override
  HttpHeaders get headers => response.headers;

  @override
  bool get isRedirect => response.isRedirect;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    bodyData = [];
    return response.listen((data) {
      bodyData.addAll(data);
      bytesReceived += data.length;
      if (onData != null) {
        onData(data);
      }
    }, onError: onError, onDone: () {
      if (bodyData.isNotEmpty) {
        if (headers.contentType != null) {
          try {
            responseBody = utf8.decode(bodyData);
          } catch (e) {
            // ignore
          }
        }
      }

      NewrelicMobile.recordHttpTransaction(
          request.method,
          request.uri.toString(),
          statusCode,
          bytesReceived,
          request.bodyData?.length ?? 0,
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
          responseBody);

      if (onDone != null) {
        onDone();
      }
    }, cancelOnError: cancelOnError);
  }

  @override
  bool get persistentConnection => response.persistentConnection;

  @override
  String get reasonPhrase => response.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) {
    return response.redirect(method, url, followLoops).then((response) => NewRelicHttpClientResponse(response, request));
  }

  @override
  List<RedirectInfo> get redirects => response.redirects;

  @override
  int get statusCode => response.statusCode;
}
