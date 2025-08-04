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
import 'package:newrelic_mobile/loglevel.dart';
import 'package:newrelic_mobile/metricunit.dart';
import 'package:newrelic_mobile/network_failure.dart';
import 'package:newrelic_mobile/newrelic_dt_trace.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/newrelic_navigation_observer.dart';
import 'package:newrelic_mobile/utils/platform_manager.dart';

import 'newrelic_mobile_test.mocks.dart';

@GenerateMocks([
  PlatformManager,
])
void main() {
  PageRoute route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  const MethodChannel channel = MethodChannel('newrelic_mobile');
  const name = 'test';
  const value = 'val';
  const category = 'category';
  const dValue = 20.0;
  const breadcrumb = 'button Pressed';
  const customEvent = 'custom Event';
  const eventName = 'eventName';
  const actionName = 'action';
  const interActionId = 'interActionId';
  const interActionName = 'interActionName';
  const url = 'https://www.google.com';
  const httpMethod = 'get';
  const statusCode = 200;
  const startTime = 0;
  const endTime = 200;
  const bytesSent = 200;
  const bytesReceived = 200;
  const responseBody = 'test';
  const maxSize = 10000;
  const megaBytes = 100;
  const maxBufferTime = 300;
  const metricUnitBytes = "bytes";
  const agentVersion = "1.1.13";
  const traceData = {
    "id": "1",
    "guid": "2",
    "trace.id": "3",
    "newrelic": "yyyyyryyryr",
    "tracestate": "testtststst",
    "traceparent": "rereteutueyuyeuyeuye"
  };
  const message = 'test';

  const httpParams = {"Car": "Honda", "Music": "Jazz"};
  const dartError =
      '#0      Page2Screen.bar.<anonymous closure> (package:newrelic_mobile_example/main.dart:185:17)\n'
      '#1      new Future.<anonymous closure> (dart:async/future.dart:252:37)\n#2      _rootRun (dart:async/zone.dart:1418:47)\n#3      _CustomZone.run (dart:async/zone.dart:1328:19)\n#4      _CustomZone.runGuarded (dart:async/zone.dart:1236:7)\n#5      _CustomZone.bindCallbackGuarded.<anonymous closure> (dart:async/zone.dart:1276:23)';
  const obfuscateDartError =
      'Warning: This VM has been configured to produce stack traces that violate the Dart standard.\n'
      '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***\n'
      'pid: 7240, tid: 7263, name 1.ui\n'
      'build_id: 8deece9b2984d05823bbe9244ff89140\nisolate_dso_base: 6f15a4b000, vm_dso_base: 6f15a4b000\nisolate_instructions: 6f15b277f0, vm_instructions: 6f15b23000\n  '
      '  #00 abs 0000006f15c3bd27 virt 00000000001f0d27 _kDartIsolateSnapshotInstructions+0x114537\n   '
      ' #01 abs 0000006f15d22a9b virt 00000000002d7a9b _kDartIsolateSnapshotInstructions+0x1fb2ab\n   '
      ' #02 abs 0000006f15d1b177 virt 00000000002d0177 _kDartIsolateSnapshotInstructions+0x1f3987\n   '
      ' #03 abs 0000006f15b2a817 virt 00000000000df817 _kDartIsolateSnapshotInstructions+0x3027\n   '
      ' #04 abs 0000006f15cd3ecf virt 0000000000288ecf _kDartIsolateSnapshotInstructions+0x1ac6df\n';

  const appToken = "123456";
  const currentRouteName = 'Current Route';
  const oldRouteName = 'Old Route';
  const nextRouteName = 'Next Route';
  NewRelicNavigationObserver navigationObserver = NewRelicNavigationObserver();
  final Map<String, dynamic> params = <String, dynamic>{
    'applicationToken': appToken,
    'dartVersion': Platform.version,
    'webViewInstrumentation': true,
    'analyticsEventEnabled': true,
    'crashReportingEnabled': true,
    'interactionTracingEnabled': true,
    'networkRequestEnabled': true,
    'networkErrorRequestEnabled': true,
    'httpResponseBodyCaptureEnabled': true,
    'loggingEnabled': true,
    'fedRampEnabled': false,
    'offlineStorageEnabled': true,
    'backgroundReportingEnabled': false,
    'newEventSystemEnabled': false,
    'distributedTracingEnabled': true,
    'collectorAddress': '',
    'crashCollectorAddress': '',
    'logLevel': 'DEBUG'
  };

  const boolValue = false;
  final List<MethodCall> methodCalLogs = <MethodCall>[];

  TestWidgetsFlutterBinding.ensureInitialized();

  NewrelicMobile.instance.setAgentConfiguration(Config(accessToken: ''));
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      methodCalLogs.add(methodCall);
      switch (methodCall.method) {
        case 'getTags':
          return <String>['tag1', 'tag2'];
        case 'setUserId':
          return true;
        case 'setAttribute':
          return true;
        case 'removeAttribute':
          return false;
        case 'getPlatformVersion':
          return '42';
        case 'startInteraction':
          return '42';
        case 'currentSessionId':
          return '123456';
        case 'noticeDistributedTrace':
          Map<String, dynamic> map = {'test': 'test1', 'test1': 'test3'};
          return map;
        case 'getHTTPHeadersTrackingFor':
          return <String>['Car', 'Music'];
        default:
          return true;
      }
    });
  });

  setUp(() {});

  tearDown(() {
    methodCalLogs.clear();
    // channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await NewrelicMobile.instance.platformVersion, '42');
  });

  test(
      'test setUserId should be called with a String argument and return a bool',
      () async {
    final result = await NewrelicMobile.instance.setUserId(name);
    final Map<String, dynamic> params = <String, dynamic>{
      'userId': name,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setUserId',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test(
      'test setAttribute should be called with a String Attribute and return a bool',
      () async {
    final result = await NewrelicMobile.instance.setAttribute(name, value);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'value': value
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setAttribute',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test(
      'test setAttribute should be called with a Boolean Attribute and return a bool',
      () async {
    final result = await NewrelicMobile.instance.setAttribute(name, boolValue);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'value': boolValue
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setAttribute',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test(
      'test removeAttribute should be called with a String Arguments and return a bool',
      () async {
    final result = await NewrelicMobile.instance.removeAttribute(name);
    final Map<String, dynamic> params = <String, dynamic>{'name': name};
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'removeAttribute',
        arguments: params,
      )
    ]);
    expect(result, false);
  });

  test(
      'test record BreadCrumb should be called with a Map Arguments and return a bool',
      () async {
    final Map<String, dynamic> eventAttributes = <String, dynamic>{
      'name': name,
      'value;': value
    };

    final result = await NewrelicMobile.instance
        .recordBreadcrumb(breadcrumb, eventAttributes: eventAttributes);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': breadcrumb,
      'eventAttributes': eventAttributes
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordBreadcrumb',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test(
      'test record CustomEvent should be called with a Map Arguments,eventType and return a bool',
      () async {
    final Map<String, dynamic> eventAttributes = <String, dynamic>{
      'name': name,
      'value;': value
    };

    final result = await NewrelicMobile.instance
        .recordCustomEvent(customEvent, eventAttributes: eventAttributes);
    final Map<String, dynamic> params = <String, dynamic>{
      'eventType': customEvent,
      'eventName': '',
      'eventAttributes': eventAttributes
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordCustomEvent',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test(
      'test record CustomEvent should be called with a Map Arguments,eventType,eventName and return a bool',
      () async {
    final Map<String, dynamic> eventAttributes = <String, dynamic>{
      'name': name,
      'value;': value
    };

    final result = await NewrelicMobile.instance.recordCustomEvent(customEvent,
        eventName: eventName, eventAttributes: eventAttributes);
    final Map<String, dynamic> params = <String, dynamic>{
      'eventType': customEvent,
      'eventName': eventName,
      'eventAttributes': eventAttributes
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordCustomEvent',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test(
      'test startInteraction should be called with a action Name and Return interactionId ',
      () async {
    final result = await NewrelicMobile.instance.startInteraction(actionName);
    final Map<String, dynamic> params = <String, dynamic>{
      'actionName': actionName,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startInteraction',
        arguments: params,
      )
    ]);
    expect(result, '42');
  });

  test(
      'test noticeDistributedTrace should be called and Return map with trace Attributes ',
      () async {
    final result = await NewrelicMobile.instance.noticeDistributedTrace({});
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeDistributedTrace',
        arguments: null,
      )
    ]);
    expect(result.keys.length, 2);
  });

  test(
      'test getHTTPHeadersTrackingFor should be called and Return List with Headers ',
      () async {
    final List<Object?> result =
        await NewrelicMobile.instance.getHTTPHeadersTrackingFor();
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'getHTTPHeadersTrackingFor',
        arguments: null,
      )
    ]);
    expect(result.length, 2);
  });

  test('test addHTTPHeadersTrackingFor should be called with parameters ',
      () async {
    List<String> list = ["Car", "Music"];
    final Map<String, dynamic> params = <String, dynamic>{
      'headers': list,
    };

    NewrelicMobile.instance.addHTTPHeadersTrackingFor(list);
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'addHTTPHeadersTrackingFor',
        arguments: params,
      )
    ]);
  });
  test('test endInteraction should be called with interActionId ', () async {
    NewrelicMobile.instance.endInteraction(interActionId);
    final Map<String, dynamic> params = <String, dynamic>{
      'interactionId': interActionId,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'endInteraction',
        arguments: params,
      )
    ]);
  });

  test('test setMaxEventPoolSize should be called with maxSize', () async {
    NewrelicMobile.instance.setMaxEventPoolSize(maxSize);
    final Map<String, dynamic> params = <String, dynamic>{
      'maxSize': maxSize,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setMaxEventPoolSize',
        arguments: params,
      )
    ]);
  });

  test('test setMaxOfflineStorageSize should be called with megaBytes',
      () async {
    NewrelicMobile.instance.setMaxOfflineStorageSize(megaBytes);
    final Map<String, dynamic> params = <String, dynamic>{
      'megaBytes': megaBytes,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setMaxOfflineStorageSize',
        arguments: params,
      )
    ]);
  });

  test('test setMaxEventBufferTime should be called with maxBufferTime',
      () async {
    NewrelicMobile.instance.setMaxEventBufferTime(maxBufferTime);
    final Map<String, dynamic> params = <String, dynamic>{
      'maxBufferTimeInSec': maxBufferTime,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setMaxEventBufferTime',
        arguments: params,
      )
    ]);
  });

  test(
      'test interactionName should be called with interActionName on Android Platform ',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);
    NewrelicMobile.instance.setInteractionName(interActionName);
    final Map<String, dynamic> params = <String, dynamic>{
      'interactionName': interActionName,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'setInteractionName',
        arguments: params,
      )
    ]);
  });

  test('test interactionName should not be called on iOS Platform ', () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => false);
    NewrelicMobile.instance.setInteractionName(interActionName);

    expect(methodCalLogs, <Matcher>[]);
  });

  test('test noticeHttpTransaction should be called on Android Platform',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);

    var traceAttributes = {
      DTTraceTags.id: traceData[DTTraceTags.id],
      DTTraceTags.guid: traceData[DTTraceTags.guid],
      DTTraceTags.traceId: traceData[DTTraceTags.traceId]
    };
    await NewrelicMobile.instance.noticeHttpTransaction(url, httpMethod,
        statusCode, startTime, endTime, bytesSent, bytesReceived, traceData,
        responseBody: responseBody, httpParams: httpParams);
    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': endTime,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'responseBody': responseBody,
      'traceAttributes': traceAttributes,
      'params': httpParams
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeHttpTransaction',
        arguments: params,
      )
    ]);
  });

  test(
      'test noticeHttpTransaction should be called on Android Platform when traceAttributes is null and params is null',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);

    await NewrelicMobile.instance.noticeHttpTransaction(url, httpMethod,
        statusCode, startTime, endTime, bytesSent, bytesReceived, null,
        responseBody: responseBody);

    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': endTime,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'responseBody': responseBody,
      'traceAttributes': null,
      'params': null
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeHttpTransaction',
        arguments: params,
      )
    ]);
  });

  test('test noticeHttpTransaction should be called on iOS Platform', () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => false);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => true);

    var traceAttributes = {
      DTTraceTags.newrelic: traceData[DTTraceTags.newrelic],
      DTTraceTags.traceState: traceData[DTTraceTags.traceState],
      DTTraceTags.traceParent: traceData[DTTraceTags.traceParent]
    };
    await NewrelicMobile.instance.noticeHttpTransaction(url, httpMethod,
        statusCode, startTime, endTime, bytesSent, bytesReceived, traceData,
        responseBody: responseBody, httpParams: httpParams);
    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': endTime,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'responseBody': responseBody,
      'traceAttributes': traceAttributes,
      'params': httpParams
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeHttpTransaction',
        arguments: params,
      )
    ]);
  });

  test(
      'test noticeHttpTransaction should be called on iOS Platform when traceAttributes is null and httpParams is null',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => false);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => true);

    await NewrelicMobile.instance.noticeHttpTransaction(url, httpMethod,
        statusCode, startTime, endTime, bytesSent, bytesReceived, null,
        responseBody: responseBody);

    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': endTime,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'responseBody': responseBody,
      'traceAttributes': null,
      'params': null
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeHttpTransaction',
        arguments: params,
      )
    ]);
  });

  test('test noticeNetworkFailure should be called with NetworkFailure Enum',
      () async {
    await NewrelicMobile.instance.noticeNetworkFailure(
        url, httpMethod, startTime, endTime, NetworkFailure.unknown);

    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'startTime': startTime,
      'endTime': endTime,
      'errorCode': NetworkFailure.unknown.code,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeNetworkFailure',
        arguments: params,
      )
    ]);
  });

  test('test incrementAttribute should be called with name', () async {
    final result = await NewrelicMobile.instance.incrementAttribute(name);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'value': null
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'incrementAttribute',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test('crashNow should be called', () async {
    NewrelicMobile.instance.crashNow();
    final Map<String, dynamic> params = <String, dynamic>{
      'name': 'NewRelic Demo Crash',
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'crashNow',
        arguments: params,
      )
    ]);
  });

  test('crashNow should be called with Name Parameter', () async {
    NewrelicMobile.instance.crashNow(name: "This is Example Crash");
    final Map<String, dynamic> params = <String, dynamic>{
      'name': 'This is Example Crash',
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'crashNow',
        arguments: params,
      )
    ]);
  });

  test('test incrementAttribute should be called with name and value',
      () async {
    final result =
        await NewrelicMobile.instance.incrementAttribute(name, value: dValue);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'value': dValue
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'incrementAttribute',
        arguments: params,
      )
    ]);
    expect(result, true);
  });

  test('test recordMetric should be called with name and category', () async {
    await NewrelicMobile.instance.recordMetric(name, category);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'category': category,
      'value': null,
      'countUnit': null,
      'valueUnit': null,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordMetric',
        arguments: params,
      )
    ]);
  });

  test('test recordMetric should be called with name,category,value', () async {
    await NewrelicMobile.instance.recordMetric(name, category, value: dValue);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'category': category,
      'value': dValue,
      'countUnit': null,
      'valueUnit': null,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordMetric',
        arguments: params,
      )
    ]);
  });

  test(
      'test recordMetric should be called with name,category,value and valueUnit on IOS Platform',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => false);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => true);
    await NewrelicMobile.instance.recordMetric(name, category,
        value: dValue, valueUnit: MetricUnit.BYTES);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'category': category,
      'value': dValue,
      'countUnit': null,
      'valueUnit': metricUnitBytes,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordMetric',
        arguments: params,
      )
    ]);
  });

  test(
      'test recordMetric should be called with name,category,value and valueUnit on Android Platform',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => false);
    await NewrelicMobile.instance.recordMetric(name, category,
        value: dValue, valueUnit: MetricUnit.BYTES);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'category': category,
      'value': dValue,
      'countUnit': null,
      'valueUnit': MetricUnit.BYTES.label,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordMetric',
        arguments: params,
      )
    ]);
  });

  test(
      'test recordMetric should be called with name,category,value, valueUnit and countUnit',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => false);
    await NewrelicMobile.instance.recordMetric(name, category,
        value: dValue,
        valueUnit: MetricUnit.BYTES,
        countUnit: MetricUnit.SECONDS);
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'category': category,
      'value': dValue,
      'countUnit': MetricUnit.SECONDS.label,
      'valueUnit': MetricUnit.BYTES.label,
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordMetric',
        arguments: params,
      )
    ]);
  });

  test('test MetricUnit label for Android Platform', () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => false);
    expect(MetricUnit.BYTES.label, "BYTES");
    expect(MetricUnit.PERCENT.label, "PERCENT");
    expect(MetricUnit.BYTES_PER_SECOND.label, "BYTES_PER_SECOND");
    expect(MetricUnit.OPERATIONS.label, "OPERATIONS");
    expect(MetricUnit.SECONDS.label, "SECONDS");
  });

  test('test MetricUnit label for iOS Platform', () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => false);
    when(platformManger.isIOS()).thenAnswer((realInvocation) => true);
    expect(MetricUnit.BYTES.label, "bytes");
    expect(MetricUnit.PERCENT.label, "%");
    expect(MetricUnit.BYTES_PER_SECOND.label, "bytes/second");
    expect(MetricUnit.OPERATIONS.label, "op");
    expect(MetricUnit.SECONDS.label, "sec");
  });

  test('test CurrentSession should be called', () async {
    await NewrelicMobile.instance.currentSessionId();

    expect(methodCalLogs,
        <Matcher>[isMethodCall('currentSessionId', arguments: null)]);

    expect(await NewrelicMobile.instance.currentSessionId(), '123456');
  });

  test('test shutdown should be called', () async {
    await NewrelicMobile.instance.shutDown();
    expect(methodCalLogs, <Matcher>[isMethodCall('shutDown', arguments: null)]);
  });

  test('test incrementAttribute should be called ', () async {
    await NewrelicMobile.instance.shutDown();
    expect(methodCalLogs, <Matcher>[isMethodCall('shutDown', arguments: null)]);
  });

  test('should return 6 elements', () {
    StackTrace stackTrace = StackTrace.fromString(dartError);

    List<Map<String, String>> elements =
        NewrelicMobile.getStackTraceElements(stackTrace);

    expect(6, elements.length);
  });

  test('obfuscate error should return 5 elements', () {
    StackTrace stackTrace = StackTrace.fromString(obfuscateDartError);

    List<Map<String, String>> elements =
        NewrelicMobile.getStackTraceElements(stackTrace);

    expect(11, elements.length);
  });

  test('agent should start with AppToken', () async {
    Config config = Config(accessToken: appToken);
    await NewrelicMobile.instance.startAgent(config);

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);
  });

  test('agent should start with AppToken with network disabled', () async {
    Config config = Config(
        accessToken: appToken,
        networkRequestEnabled: false,
        networkErrorRequestEnabled: false);
    await NewrelicMobile.instance.startAgent(config);

    params['networkRequestEnabled'] = false;
    params['networkErrorRequestEnabled'] = false;

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);

    params['networkRequestEnabled'] = true;
    params['networkErrorRequestEnabled'] = true;
  });

  test('agent should start with AppToken with analytics disabled', () async {
    Config config = Config(accessToken: appToken, analyticsEventEnabled: false);
    await NewrelicMobile.instance.startAgent(config);

    params['analyticsEventEnabled'] = false;

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);

    params['analyticsEventEnabled'] = true;
  });

  test('agent should start with AppToken with fedRamp disabled', () async {
    Config config = Config(accessToken: appToken);
    await NewrelicMobile.instance.startAgent(config);

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);
  });

  test(
      'agent should start with AppToken with  backgroundReporting Enabled and newEventSystem Disabled',
      () async {
    Config config = Config(
        accessToken: appToken,
        backgroundReportingEnabled: true,
        newEventSystemEnabled: false);
    await NewrelicMobile.instance.startAgent(
      config,
    );

    params['backgroundReportingEnabled'] = true;

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);

    params['backgroundReportingEnabled'] = false;
    params['newEventSystemEnabled'] = false;
  });

  test('agent should start with AppToken with fedRamp Enabled', () async {
    Config config = Config(accessToken: appToken, fedRampEnabled: true);
    await NewrelicMobile.instance.startAgent(config);

    params['fedRampEnabled'] = true;

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);

    params['fedRampEnabled'] = false;
  });

  test('agent should start with AppToken with offlineStorage disabled',
      () async {
    Config config = Config(accessToken: appToken, offlineStorageEnabled: false);
    await NewrelicMobile.instance.startAgent(
      config,
    );

    params['offlineStorageEnabled'] = false;

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      )
    ]);

    params['offlineStorageEnabled'] = true;
  });

  test('test RecordError should be called', () async {
    var error = Exception("test");

    StackTrace stackTrace = StackTrace.fromString(dartError);

    NewrelicMobile.instance.recordError(error, stackTrace);

    final Map<String, dynamic> params = <String, dynamic>{
      'exception': error.toString(),
      'reason': error.toString(),
      'stackTrace': stackTrace.toString(),
      'stackTraceElements': NewrelicMobile.getStackTraceElements(stackTrace),
      'fatal': false
    };

    final Map<String, dynamic> eventParams = Map<String, dynamic>.from(params);
    eventParams.remove('stackTraceElements');

    final Map<String, dynamic> customEventParams = <String, dynamic>{
      'eventType': 'Mobile Dart Errors',
      'eventName': '',
      'eventAttributes': eventParams
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'recordCustomEvent',
        arguments: customEventParams,
      ),
      isMethodCall(
        'recordError',
        arguments: params,
      )
    ]);
  });

  test('test Record DebugPrint method', () {
    Config config =
        Config(accessToken: appToken, printStatementAsEventsEnabled: false);
    NewrelicMobile.instance.startAgent(config);
    debugPrint(name);

    expect(
      methodCalLogs[0],
      isMethodCall(
        'startAgent',
        arguments: params,
      ),
    );
  });

  test('test Record DebugPrint method as Log Attributes', () {
    Config config =
        Config(accessToken: appToken, printStatementAsEventsEnabled: true);
    NewrelicMobile.instance.startAgent(config);
    debugPrint(name);
    expect(methodCalLogs[1].method, 'logAttributes');
  });
  test('test Start of Agent should also start method with logging disabled ',
      () async {
    Config config = Config(accessToken: appToken, loggingEnabled: false);

    Function fun = () {
      print('test');
    };

    await NewrelicMobile.instance.start(config, fun);

    params['loggingEnabled'] = false;

    final Map<String, dynamic> logParams = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.INFO.name,
        'message': message,
      }
    };

    final Map<String, dynamic> attributeParams = <String, dynamic>{
      'name': 'Flutter Agent Version',
      'value': agentVersion,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      ),
      isMethodCall(
        'logAttributes',
        arguments: logParams,
      ),
      isMethodCall(
        'setAttribute',
        arguments: attributeParams,
      ),
    ]);
    params['loggingEnabled'] = true;
  });

  test(
      'test Start of Agent should also start method with print statement as custom Events disabled ',
      () async {
    Config config =
        Config(accessToken: appToken, printStatementAsEventsEnabled: false);

    Function fun = () {
      print('test');
    };

    await NewrelicMobile.instance.start(config, fun);

    final Map<String, dynamic> attributeParams = <String, dynamic>{
      'name': 'Flutter Agent Version',
      'value': agentVersion,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      ),
      isMethodCall(
        'setAttribute',
        arguments: attributeParams,
      )
    ]);
  });

  test(
      'test Start of Agent should also start method and also record error if run app throw error ',
      () async {
    Config config = Config(accessToken: appToken);

    Function fun = () {
      print('test');
      throw Exception('test');
    };

    await NewrelicMobile.instance.start(config, fun);

    expect(
        methodCalLogs[0],
        isMethodCall(
          'startAgent',
          arguments: params,
        ));

    expect(methodCalLogs[1].method, 'logAttributes');

    expect(methodCalLogs[2].method, 'recordCustomEvent');

    expect(methodCalLogs[3].method, 'recordError');
  });

  test('test onError should called record error and record error as Fatal', () {
    const exception = 'foo exception';
    const exceptionReason = 'bar reason';
    const exceptionLibrary = 'baz library';
    const exceptionFirstMessage = 'first message';
    const exceptionSecondMessage = 'second message';
    final stack = StackTrace.current;
    final FlutterErrorDetails details = FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: exceptionLibrary,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsNode.message(exceptionFirstMessage),
        DiagnosticsNode.message(exceptionSecondMessage),
      ],
      context: ErrorDescription(exceptionReason),
    );

    NewrelicMobile.onError(details);

    final Map<String, dynamic> params = <String, dynamic>{
      'exception': exception,
      'reason': exception,
      'stackTrace': stack.toString(),
      'stackTraceElements': NewrelicMobile.getStackTraceElements(stack),
      'fatal': true
    };

    final Map<String, dynamic> eventParams = Map<String, dynamic>.from(params);
    eventParams.remove('stackTraceElements');

    final Map<String, dynamic> customEventParams = <String, dynamic>{
      'eventType': 'Mobile Dart Errors',
      'eventName': '',
      'eventAttributes': eventParams
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall('recordCustomEvent', arguments: customEventParams),
      isMethodCall('recordError', arguments: params)
    ]);
  });

  test("test navigation observer did pop method", () {
    final currentRoute = route(const RouteSettings(name: currentRouteName));
    final oldRoute = route(const RouteSettings(name: oldRouteName));

    navigationObserver.didPop(oldRoute, currentRoute);

    Map<String, String?> attributes = <String, String?>{
      'methodType': 'didPop',
      'from': oldRouteName,
      'to': currentRouteName
    };

    final Map<String, dynamic> params = <String, dynamic>{
      'name': breadCrumbName,
      'eventAttributes': attributes
    };

    expect(methodCalLogs,
        <Matcher>[isMethodCall('recordBreadcrumb', arguments: params)]);
  });

  test("test navigation observer did push method", () {
    final currentRoute = route(const RouteSettings(name: currentRouteName));
    final nextRoute = route(const RouteSettings(name: nextRouteName));

    navigationObserver.didPush(nextRoute, currentRoute);

    Map<String, String?> attributes = <String, String?>{
      'methodType': 'didPush',
      'from': currentRouteName,
      'to': nextRouteName
    };

    final Map<String, dynamic> params = <String, dynamic>{
      'name': breadCrumbName,
      'eventAttributes': attributes
    };

    expect(methodCalLogs,
        <Matcher>[isMethodCall('recordBreadcrumb', arguments: params)]);
  });

  test("test navigation observer did replace method", () {
    final currentRoute = route(const RouteSettings(name: currentRouteName));
    final nextRoute = route(const RouteSettings(name: nextRouteName));

    navigationObserver.didReplace(newRoute: nextRoute, oldRoute: currentRoute);

    Map<String, String?> attributes = <String, String?>{
      'methodType': 'didReplace',
      'from': currentRouteName,
      'to': nextRouteName
    };

    final Map<String, dynamic> params = <String, dynamic>{
      'name': breadCrumbName,
      'eventAttributes': attributes
    };

    expect(methodCalLogs,
        <Matcher>[isMethodCall('recordBreadcrumb', arguments: params)]);
  });

  test('test navigation observer from route null name', () {
    final currentRoute = route(const RouteSettings());
    final nextRoute = route(const RouteSettings(name: nextRouteName));

    navigationObserver.didReplace(newRoute: nextRoute, oldRoute: currentRoute);

    Map<String, String?> attributes = <String, String?>{
      'methodType': 'didReplace',
      'from': '/',
      'to': nextRouteName
    };

    final Map<String, dynamic> params = <String, dynamic>{
      'name': breadCrumbName,
      'eventAttributes': attributes
    };

    expect(methodCalLogs,
        <Matcher>[isMethodCall('recordBreadcrumb', arguments: params)]);
  });

  test('test navigation observer to route null name', () {
    final currentRoute = route(const RouteSettings(name: currentRouteName));
    final nextRoute = route(const RouteSettings(name: ''));

    navigationObserver.didReplace(newRoute: nextRoute, oldRoute: currentRoute);

    Map<String, String?> attributes = <String, String?>{
      'methodType': 'didReplace',
      'from': currentRouteName,
      'to': ''
    };

    final Map<String, dynamic> params = <String, dynamic>{
      'name': breadCrumbName,
      'eventAttributes': attributes
    };

    expect(methodCalLogs,
        <Matcher>[isMethodCall('recordBreadcrumb', arguments: params)]);
  });

  test('test logDebug should be called with message', () async {
    NewrelicMobile.instance.logDebug(message);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.DEBUG.name,
        'message': message,
      }
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });
  test('test logInfo should be called with message', () async {
    NewrelicMobile.instance.logInfo(message);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.INFO.name,
        'message': message,
      }
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });

  test('test logVerbose should be called with message and log level Verbose',
      () async {
    NewrelicMobile.instance.logVerbose(message);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.VERBOSE.name,
        'message': message,
      }
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });
  test('test logWarning should be called with message and log level Warning',
      () async {
    NewrelicMobile.instance.logWarning(message);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.WARN.name,
        'message': message,
      }
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });

  test('test logError should be called with message and log level Error',
      () async {
    NewrelicMobile.instance.logError(message);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.ERROR.name,
        'message': message,
      }
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });
  test('test logError should not be called without message ', () async {
    NewrelicMobile.instance.logError("");
    expect(methodCalLogs.length, 0);
  });

  test('test log should be called with message and log level Error', () async {
    NewrelicMobile.instance.log(LogLevel.ERROR, message);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.ERROR.name,
        'message': message,
      }
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });

  test('test logAll should be called with error and attributes', () async {
    final Map<String, dynamic> attributes = <String, dynamic>{
      'logLevel': LogLevel.ERROR.name,
      'action': 'Button Pressed',
    };

    try {
      throw Exception("Error");
    } on Exception catch (e) {
      NewrelicMobile.instance.logAll(e, attributes);
    }

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'message': "Exception: Error",
        'logLevel': LogLevel.ERROR.name,
        'action': 'Button Pressed',
      }
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });

  test('test logAttributes should be called with attributes', () async {
    final Map<String, dynamic> attributes = <String, dynamic>{
      'logLevel': LogLevel.ERROR.name,
      'action': 'Button Pressed',
      'message': message
    };

    NewrelicMobile.instance.logAttributes(attributes);

    final Map<String, dynamic> params = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.ERROR.name,
        'action': 'Button Pressed',
        'message': message
      }
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'logAttributes',
        arguments: params,
      )
    ]);
  });

  test('test logAttributes should not be called without attributes', () async {
    final Map<String, dynamic> attributes = <String, dynamic>{};

    NewrelicMobile.instance.logAttributes(attributes);

    expect(methodCalLogs, <Matcher>[]);
  });

  test(
      'test Start of Agent should also start method with distributedTracing disabled ',
      () async {
    Config config =
        Config(accessToken: appToken, distributedTracingEnabled: false);

    Function fun = () {
      print('test');
    };

    await NewrelicMobile.instance.start(config, fun);

    params['distributedTracingEnabled'] = false;

    final Map<String, dynamic> customParams = <String, dynamic>{
      "attributes": {"logLevel": "INFO", "message": "test"}
    };

    final Map<String, dynamic> attributeParams = <String, dynamic>{
      'name': 'Flutter Agent Version',
      'value': agentVersion,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      ),
      isMethodCall(
        'logAttributes',
        arguments: customParams,
      ),
      isMethodCall(
        'setAttribute',
        arguments: attributeParams,
      )
    ]);

    params['distributedTracingEnabled'] = true;
  });

  test(
      'test noticeHttpTransaction should be called with Empty TraceAttributes if distributedTracing is disabled',
      () async {
    var platformManger = MockPlatformManager();
    PlatformManager.setPlatformInstance(platformManger);
    Config config =
        Config(accessToken: appToken, distributedTracingEnabled: false);
    NewrelicMobile.instance.setAgentConfiguration(config);
    when(platformManger.isAndroid()).thenAnswer((realInvocation) => true);

    await NewrelicMobile.instance.noticeHttpTransaction(url, httpMethod,
        statusCode, startTime, endTime, bytesSent, bytesReceived, {},
        responseBody: responseBody, httpParams: httpParams);
    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': endTime,
      'bytesSent': bytesSent,
      'bytesReceived': bytesReceived,
      'responseBody': responseBody,
      'traceAttributes': null,
      'params': httpParams
    };
    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'noticeHttpTransaction',
        arguments: params,
      )
    ]);
  });

  test(
      'test Start of Agent should also start method with collectorAddress and crashCollectorAddress',
      () async {
    Config config = Config(
        accessToken: appToken,
        loggingEnabled: false,
        collectorAddress: "www.google.com",
        crashCollectorAddress: "www.facebook.com");

    Function fun = () {
      print('test');
    };

    await NewrelicMobile.instance.start(config, fun);

    params['collectorAddress'] = "www.google.com";
    params['crashCollectorAddress'] = "www.facebook.com";
    params['loggingEnabled'] = false;

    final Map<String, dynamic> logParams = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.INFO.name,
        'message': message,
      }
    };

    final Map<String, dynamic> attributeParams = <String, dynamic>{
      'name': 'Flutter Agent Version',
      'value': agentVersion,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      ),
      isMethodCall(
        'logAttributes',
        arguments: logParams,
      ),
      isMethodCall(
        'setAttribute',
        arguments: attributeParams,
      ),
    ]);

    params['collectorAddress'] = "";
    params['crashCollectorAddress'] = "";
    params['loggingEnabled'] = true;
  });

  test('test Start of Agent should also start method with LogLevel Error',
      () async {
    Config config = Config(accessToken: appToken, logLevel: LogLevel.ERROR);

    Function fun = () {
      print('test');
    };

    await NewrelicMobile.instance.start(config, fun);

    params['logLevel'] = 'ERROR';

    final Map<String, dynamic> logParams = <String, dynamic>{
      "attributes": <String, dynamic>{
        'logLevel': LogLevel.INFO.name,
        'message': message,
      }
    };

    final Map<String, dynamic> attributeParams = <String, dynamic>{
      'name': 'Flutter Agent Version',
      'value': agentVersion,
    };

    expect(methodCalLogs, <Matcher>[
      isMethodCall(
        'startAgent',
        arguments: params,
      ),
      isMethodCall(
        'logAttributes',
        arguments: logParams,
      ),
      isMethodCall(
        'setAttribute',
        arguments: attributeParams,
      ),
    ]);
  });

  params['logLevel'] = 'DEBUG';
}
