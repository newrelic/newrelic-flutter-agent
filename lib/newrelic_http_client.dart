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
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String? realm)? f) {
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
    return _wrapRequest(client.delete(host, port, path));
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return _wrapRequest(client.deleteUrl(url));
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    client.findProxy = f as String Function(Uri);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return _wrapRequest(client.get(host, port, path));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return _wrapRequest(client.getUrl(url));
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return _wrapRequest(client.head(host, port, path));
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return _wrapRequest(client.headUrl(url));
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return _wrapRequest(client.open(method, host, port, path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return _wrapRequest(client.openUrl(method, url));
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return _wrapRequest(client.patch(host, port, path));
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return _wrapRequest(client.patchUrl(url));
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return _wrapRequest(client.post(host, port, path));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return _wrapRequest(client.postUrl(url));
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return _wrapRequest(client.put(host, port, path));
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return _wrapRequest(client.putUrl(url));
  }
}

Future<NewRelicHttpClientRequest> _wrapRequest(
    Future<HttpClientRequest> request) async {
  try {
    var timestamp = DateTime.now().millisecondsSinceEpoch;

    Config config = NewrelicMobile.instance.getAgentConfiguration();
    Map<String, dynamic> traceAttributes = {};

    if (config.distributedTracingEnabled) {
      traceAttributes = await NewrelicMobile.instance.noticeDistributedTrace({});
    }

    final actualRequest = await request;
    if (config.distributedTracingEnabled) {
      actualRequest.headers.add(DTTraceTags.traceState, traceAttributes[DTTraceTags.traceState]);
      actualRequest.headers.add(DTTraceTags.newrelic, traceAttributes[DTTraceTags.newrelic]);
      actualRequest.headers.add(DTTraceTags.traceParent, traceAttributes[DTTraceTags.traceParent]);
    }

    final newRelicRequest = NewRelicHttpClientRequest(actualRequest, timestamp, traceAttributes, {});
    newRelicRequest.performRequest().catchError((err, stackTrace) {
    });
    return newRelicRequest;
  } catch (e, stackTrace) {
    NewrelicMobile.instance.recordError(e, stackTrace);
    return Future.error(e, stackTrace);
  }
}

Future<NewRelicHttpClientResponse> _wrapResponse(
    HttpClientResponse response,
    HttpClientRequest request,
    int timestamp,
    Map<String, dynamic> traceData) async {
  if (response is NewRelicHttpClientResponse) {
    return response;
  }

  dynamic headersList =
      await NewrelicMobile.instance.getHTTPHeadersTrackingFor();
  Map<String, String> params = Map();

  for (String header in headersList) {
    if (request.headers.value(header) != null) {
      params.putIfAbsent(header, () => request.headers.value(header)!);
    }
  }

  return NewRelicHttpClientResponse(response, request, timestamp, traceData,
      params: params);
}

class NewRelicHttpClientRequest extends HttpClientRequest {
  final int timestamp;
  final HttpClientRequest _httpClientRequest;
  StringBuffer? _sendBuffer = StringBuffer();
  Map<String, dynamic> traceData;
  Map<String, dynamic>? params;

  NewRelicHttpClientRequest(
      this._httpClientRequest, this.timestamp, this.traceData,
      [this.params]) {}

  Future<void> performRequest() async {
    try {
      final value = await this.done;
      _wrapResponse(
        value,
        this,
        this.timestamp,
        this.traceData,
      );
    } catch (err, stackTrace) {
      NewrelicMobile.instance.recordError(err, stackTrace);
      throw err;
    }
  }

  void _checkAndResetBufferIfRequired() {
    if (_sendBuffer != null && _sendBuffer!.length > 2048) {
      _sendBuffer = null;
    }
  }

  void _addItems(List<int> data) {
    if (this.headers.contentType != ContentType.binary) {
      try {
        _sendBuffer?.write(utf8.decode(data));
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  Stream<List<int>> _readAndRecreateStream(Stream<List<int>> source) async* {
    await for (var chunk in source) {
      _addItems(chunk);
      yield chunk;
    }
  }

  @override
  Encoding get encoding => _httpClientRequest.encoding;

  set encoding(Encoding value) {
    _httpClientRequest.encoding = value;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _httpClientRequest.abort(exception, stackTrace);
  }

  @override
  void add(List<int> data) {
    _addItems(data);
    _httpClientRequest.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _httpClientRequest.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    var newStream = _readAndRecreateStream(stream);
    return _httpClientRequest.addStream(newStream);
  }

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await _httpClientRequest.close();
      return await _wrapResponse(response, _httpClientRequest, this.timestamp, traceData);
    } catch (err, stackTrace) {
      NewrelicMobile.instance.recordError(err, stackTrace);
      return Future<NewRelicHttpClientResponse>.error(err, stackTrace);
    }
  }

  @override
  HttpConnectionInfo? get connectionInfo => _httpClientRequest.connectionInfo;

  @override
  List<Cookie> get cookies => _httpClientRequest.cookies;

  @override
  Future<HttpClientResponse> get done async {
    try {
      final response = await _httpClientRequest.done;
      return _wrapResponse(response, _httpClientRequest, timestamp, traceData);
    } catch (err, stackTrace) {
      NewrelicMobile.instance.recordError(err, stackTrace);
      return Future<NewRelicHttpClientResponse>.error(err, stackTrace);
    }
  }

  @override
  Future flush() {
    return _httpClientRequest.flush();
  }

  @override
  HttpHeaders get headers => _httpClientRequest.headers;

  @override
  String get method => _httpClientRequest.method;

  @override
  Uri get uri => _httpClientRequest.uri;

  @override
  void write(Object? object) {
    _httpClientRequest.write(object);
  }

  @override
  bool get followRedirects => _httpClientRequest.followRedirects;
  @override
  set followRedirects(bool value) => _httpClientRequest.followRedirects = value;

  @override
  bool get bufferOutput => _httpClientRequest.bufferOutput;
  @override
  set bufferOutput(bool value) => _httpClientRequest.bufferOutput = value;

  @override
  int get contentLength => _httpClientRequest.contentLength;
  @override
  set contentLength(int value) => _httpClientRequest.contentLength = value;

  @override
  int get maxRedirects => _httpClientRequest.maxRedirects;
  @override
  set maxRedirects(int value) => _httpClientRequest.maxRedirects = value;

  @override
  bool get persistentConnection => _httpClientRequest.persistentConnection;
  @override
  set persistentConnection(bool value) =>
      _httpClientRequest.persistentConnection = value;

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _httpClientRequest.writeAll(objects);
  }

  @override
  void writeCharCode(int charCode) {
    _httpClientRequest.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = ""]) {
    _httpClientRequest.writeln(object);
  }
}

class NewRelicHttpClientResponse extends HttpClientResponse {
  final HttpClientResponse _httpClientResponse;
  final HttpClientRequest request;
  final int timestamp;
  Stream<List<int>>? _wrapperStream;
  StringBuffer? _receiveBuffer = StringBuffer();
  String? responseData;
  dynamic traceData;
  dynamic params;

  NewRelicHttpClientResponse(
      this._httpClientResponse, this.request, this.timestamp, this.traceData,
      {this.params}) {
    _wrapperStream = _readAndRecreateStream(_httpClientResponse);
  }

  void _checkAndResetBufferIfRequired() {
    if (_receiveBuffer != null && _receiveBuffer!.length > 2048) {
      _receiveBuffer = null;
    }
  }

  void _addItems(List<int> data) {
    if (headers.contentType != ContentType.binary) {
      try {
        _receiveBuffer?.write(utf8.decode(data));
      } catch (ex) {}
      _checkAndResetBufferIfRequired();
    }
  }

  Stream<List<int>> _readAndRecreateStream(Stream<List<int>> source) async* {
    await for (var chunk in source) {
      _addItems(chunk);
      yield chunk;
    }

    if (this.contentLength < 2048) {
      responseData = _receiveBuffer.toString();
    }

    NewrelicMobile.instance.noticeHttpTransaction(
        request.uri.toString(),
        request.method,
        _httpClientResponse.statusCode,
        timestamp,
        DateTime.now().millisecondsSinceEpoch,
        request.contentLength,
        _httpClientResponse.contentLength,
        traceData,
        httpParams: params,
        responseBody: responseData ?? '');
  }

  @override
  Future<bool> any(bool Function(List<int> element) test) {
    return _wrapperStream!.any(test);
  }

  @override
  Stream<List<int>> asBroadcastStream(
      {void Function(StreamSubscription<List<int>> subscription)? onListen,
      void Function(StreamSubscription<List<int>> subscription)? onCancel}) {
    return _wrapperStream!
        .asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) {
    return _wrapperStream!.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) {
    return this._wrapperStream!.asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() {
    return _wrapperStream!.cast();
  }

  @override
  X509Certificate? get certificate => _httpClientResponse.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _httpClientResponse.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => _httpClientResponse.connectionInfo;

  @override
  Future<bool> contains(Object? needle) {
    return _wrapperStream!.contains(needle);
  }

  @override
  int get contentLength => _httpClientResponse.contentLength;

  @override
  List<Cookie> get cookies => _httpClientResponse.cookies;

  @override
  Future<Socket> detachSocket() {
    return _httpClientResponse.detachSocket();
  }

  @override
  Stream<List<int>> distinct(
      [bool Function(List<int> previous, List<int> next)? equals]) {
    return _wrapperStream!.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return _wrapperStream!.drain(futureValue);
  }

  @override
  Future<List<int>> elementAt(int index) {
    return _wrapperStream!.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(List<int> element) test) {
    return _wrapperStream!.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) {
    return _wrapperStream!.expand(convert);
  }

  @override
  Future<List<int>> get first => _wrapperStream!.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return _wrapperStream!.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, List<int> element) combine) {
    return _wrapperStream!.fold(initialValue, combine);
  }

  @override
  Future forEach(void Function(List<int> element) action) {
    return _wrapperStream!.forEach(action);
  }

  @override
  Stream<List<int>> handleError(Function onError, {bool test(error)?}) {
    return _wrapperStream!.handleError(onError, test: test);
  }

  @override
  HttpHeaders get headers => _httpClientResponse.headers;

  @override
  bool get isBroadcast => _wrapperStream!.isBroadcast;

  @override
  Future<bool> get isEmpty => _wrapperStream!.isEmpty;

  @override
  bool get isRedirect => _httpClientResponse.isRedirect;

  @override
  Future<String> join([String separator = ""]) {
    return _wrapperStream!.join(separator);
  }

  @override
  Future<List<int>> get last => _wrapperStream!.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return _wrapperStream!.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => _wrapperStream!.length;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _wrapperStream!.listen(onData, onError: onError, onDone: onDone);
  }

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) {
    return _wrapperStream!.map(convert);
  }

  @override
  bool get persistentConnection => _httpClientResponse.persistentConnection;

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) {
    return _wrapperStream!.pipe(streamConsumer);
  }

  @override
  String get reasonPhrase => _httpClientResponse.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) async {
    return _httpClientResponse.redirect(method, url, followLoops).then(
        (response) {
      return _wrapResponse(response, request, timestamp, traceData);
    }, onError: (dynamic err) {
      NewrelicMobile.instance.recordError(err, StackTrace.current);
      throw err;
    });
  }

  @override
  List<RedirectInfo> get redirects => _httpClientResponse.redirects;

  @override
  Future<List<int>> reduce(
      List<int> Function(List<int> previous, List<int> element) combine) {
    return _wrapperStream!.reduce(combine);
  }

  @override
  Future<List<int>> get single => _wrapperStream!.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return _wrapperStream!.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<List<int>> skip(int count) {
    return _wrapperStream!.skip(count);
  }

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) {
    return _wrapperStream!.skipWhile(test);
  }

  @override
  int get statusCode => _httpClientResponse.statusCode;

  @override
  Stream<List<int>> take(int count) {
    return _wrapperStream!.take(count);
  }

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) {
    return _wrapperStream!.takeWhile(test);
  }

  @override
  Stream<List<int>> timeout(Duration timeLimit,
      {void Function(EventSink<List<int>> sink)? onTimeout}) {
    return _wrapperStream!.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<List<int>>> toList() {
    return _wrapperStream!.toList();
  }

  @override
  Future<Set<List<int>>> toSet() {
    return _wrapperStream!.toSet();
  }

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return _wrapperStream!.transform(streamTransformer);
  }

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) {
    return _wrapperStream!.where(test);
  }
}
