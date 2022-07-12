

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:newrelic_mobile/newrelic_http_client.dart';

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
  const listOfObjects = [
    {'test1': 'test'},
    {'test2': 'test'},
    {'test3': 'test'}
  ];

  late NewRelicHttpClient newRelicHttpClient;
  late NewRelicHttpClientRequest newRelicHttpClientRequest;
  late NewRelicHttpClientResponse newRelicHttpClientResponse;
  late MockHttpClientRequest mockRequest;
  late MockHttpClientResponse mockResponse;
  late MockHttpHeaders mockHttpHeaders;

  setUpAll(() async {
    const MethodChannel('newrelic_mobile')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'noticeDistributedTrace':
          Map<String,dynamic> map = {'id':'test1','newrelic':'test3','guid':'test3','trace.id':'test3','tracestate':'test3','traceparent':'test3'};
          return map;
        default:
          return true;
      }
    });
  });

  setUp(() {
    newRelicHttpClient = NewRelicHttpClient(client:  MockHttpClient());


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
    newRelicHttpClientResponse = NewRelicHttpClientResponse(mockResponse, mockRequest, DateTime.now().millisecond, {});

    when<dynamic>(mockRequest.close()).thenAnswer((_) async => newRelicHttpClientResponse);
    when<dynamic>(mockRequest.done).thenAnswer((_) async => newRelicHttpClientResponse);

    newRelicHttpClientRequest = NewRelicHttpClientRequest(
        mockRequest,DateTime.now().millisecond,{});

    expect(mockRequest, isInstanceOf<HttpClientRequest>());
    expect(mockResponse, isInstanceOf<HttpClientResponse>());

  });

  tearDown(() async {
    log.clear();
  });

  test('expect newrelic custom http client GET URL to return request and log',
          () async {
        when<dynamic>(
            (newRelicHttpClient.client as MockHttpClient).getUrl(any))
            .thenAnswer((_) async => mockRequest);
        // when<Future<HttpClientResponse>>(newRelicHttpClientRequest.done).thenAnswer((_) async => mockResponse);
        when(mockRequest.done).thenAnswer((_) async => newRelicHttpClientResponse);

        await newRelicHttpClient.getUrl(Uri.parse(url));
        await newRelicHttpClientRequest.close();

        expect(log[0].method,'noticeDistributedTrace');

      });

}