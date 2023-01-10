/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:async';
import 'dart:io'
    show HttpClientRequest, HttpClientResponse, HttpOverrides, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/newrelic_dt_trace.dart';
import 'package:newrelic_mobile/newrelic_http_overrides.dart';
import 'package:newrelic_mobile/utils/platform_manager.dart';
import 'package:stack_trace/stack_trace.dart';

class NewrelicMobile {
  static final NewrelicMobile instance = NewrelicMobile._();

  NewrelicMobile._();

  static const MethodChannel _channel = MethodChannel('newrelic_mobile');

  static DebugPrintCallback? _originalDebugPrint;

  Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<void> start(Config config, Function runApp) async {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = NewrelicMobile.onError;
      await NewrelicMobile.instance.startAgent(config);
      runApp();
      await NewrelicMobile.instance
          .setAttribute("Flutter Agent Version", "0.0.1-dev.8");
    }, (Object error, StackTrace stackTrace) {
      NewrelicMobile.instance.recordError(error, stackTrace);
      if (kDebugMode) {
        print('$error \n $stackTrace');
      }
    }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
      if (config.printStatementAsEventsEnabled) {
        recordCustomEvent("Mobile Dart Console Events",
            eventAttributes: {"message": line});
      }
      parent.print(zone, line);
    }));
  }

  static void onError(FlutterErrorDetails errorDetails) async {
    FlutterError.presentError(errorDetails);
    NewrelicMobile.instance
        .recordError(errorDetails.exception, errorDetails.stack, isFatal: true);
  }

  void recordError(Object error, StackTrace? stackTrace,
      {Map<String, dynamic>? attributes, bool isFatal = false}) async {
    String stackTraceStr = '';
    if (stackTrace != null) {
      if (stackTrace.toString().length > 4096) {
        stackTraceStr = stackTrace.toString().substring(0, 4094);
      } else {
        stackTraceStr = stackTrace.toString();
      }
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'exception': error.toString(),
      'reason': error.toString(),
      'stackTrace': stackTraceStr,
      'stackTraceElements':
          stackTrace != null ? getStackTraceElements(stackTrace) : null,
      'fatal': isFatal
    };

    if (attributes != null) {
      params['attributes'] = attributes;
    }

    final Map<String, dynamic> eventParams = Map<String, dynamic>.from(params);
    eventParams.remove('stackTraceElements');

    NewrelicMobile.instance
        .recordCustomEvent("Mobile Dart Errors", eventAttributes: eventParams);

    await _channel.invokeMethod('recordError', params);
  }

  redirectDebugPrint() {
    if (_originalDebugPrint != null) return;
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (_originalDebugPrint != null) {
        recordCustomEvent("Mobile Dart Console Events",
            eventAttributes: {"message": message});
        _originalDebugPrint!(message, wrapWidth: wrapWidth);
      }
    };
  }

  Future<void> startAgent(Config config) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'applicationToken': config.accessToken,
      'dartVersion': Platform.version,
      'webViewInstrumentation': config.webViewInstrumentation,
      'analyticsEventEnabled': config.analyticsEventEnabled,
      'crashReportingEnabled': config.crashReportingEnabled,
      'interactionTracingEnabled': config.interactionTracingEnabled,
      'networkRequestEnabled': config.networkRequestEnabled,
      'networkErrorRequestEnabled': config.networkErrorRequestEnabled,
      'httpResponseBodyCaptureEnabled': config.httpResponseBodyCaptureEnabled,
      'loggingEnabled': config.loggingEnabled
    };

    if (config.printStatementAsEventsEnabled) {
      redirectDebugPrint();
    }
    HttpOverrides.global =
        NewRelicHttpOverrides(current: HttpOverrides.current);
    await _channel.invokeMethod('startAgent', params);
  }

  Future<bool?> setUserId(String userId) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'userId': userId,
    };
    final bool? userIdWasSet = await _channel.invokeMethod('setUserId', params);
    return userIdWasSet;
  }

  Future<bool> setAttribute(String name, dynamic value) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'value': value
    };
    final bool result = await _channel.invokeMethod('setAttribute', params);
    return result;
  }

  Future<bool> removeAttribute(String name) async {
    final Map<String, dynamic> params = <String, dynamic>{'name': name};
    final bool attributeIsRemoved =
        await _channel.invokeMethod('removeAttribute', params);
    return attributeIsRemoved;
  }

  Future<bool> recordBreadcrumb(String name,
      {Map<String, dynamic>? eventAttributes}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'eventAttributes': eventAttributes
    };
    final bool eventRecorded =
        await _channel.invokeMethod('recordBreadcrumb', params);
    return eventRecorded;
  }

  Future<bool> recordCustomEvent(String eventType,
      {String eventName = "", Map<String, dynamic>? eventAttributes}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'eventType': eventType,
      'eventName': eventName,
      'eventAttributes': eventAttributes
    };
    final bool eventRecorded =
        await _channel.invokeMethod('recordCustomEvent', params);
    return eventRecorded;
  }

  Future<String> startInteraction(String actionName) async {
    final Map<String, String> params = <String, String>{
      'actionName': actionName
    };
    final String interactionId =
        await _channel.invokeMethod('startInteraction', params);
    return interactionId;
  }

  Future<Map<String, dynamic>> noticeDistributedTrace(
      Map<String, dynamic> requestAttributes) async {
    final dynamic traceAttributes =
        await _channel.invokeMethod('noticeDistributedTrace');
    return Map<String, dynamic>.from(traceAttributes);
  }

  Future<void> setInteractionName(String interactionName) async {
    final Map<String, String> params = <String, String>{
      'interactionName': interactionName
    };
    if (PlatformManager.instance.isAndroid()) {
      await _channel.invokeMethod('setInteractionName', params);
      return;
    } else {
      return;
    }
  }

  Future<void> setMaxEventPoolSize(int maxSize) async {
    final Map<String, int> params = <String, int>{'maxSize': maxSize};
    await _channel.invokeMethod('setMaxEventPoolSize', params);
    return;
  }

  Future<void> setMaxEventBufferTime(int maxBufferTimeInSec) async {
    final Map<String, int> params = <String, int>{
      'maxBufferTimeInSec': maxBufferTimeInSec
    };
    await _channel.invokeMethod('setMaxEventBufferTime', params);
    return;
  }

  void endInteraction(String interactionId) async {
    final Map<String, String> params = <String, String>{
      'interactionId': interactionId
    };

    await _channel.invokeMethod('endInteraction', params);
    return;
  }

  Future<void> logNetworkIoRequest(
    HttpClientRequest request, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    startTime ??= DateTime.now();
    final response = await request.done;

    return await logNetworkIoRequestResponse(request, response,
        startTime: startTime, endTime: endTime);
  }

  Future<void> logNetworkIoRequestResponse(
    HttpClientRequest request,
    HttpClientResponse response, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    endTime = DateTime.now();
    await NewrelicMobile.instance.noticeHttpTransaction(
        request.uri.toString(),
        request.method,
        response.statusCode,
        startTime!.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
        response.contentLength,
        response.contentLength,
        null,
        responseBody: response.toString());
  }

  Future<void> noticeHttpTransaction(
      String url,
      String httpMethod,
      int statusCode,
      int startTime,
      int endTime,
      int bytesSent,
      int bytesReceived,
      Map<String, dynamic>? traceData,
      {String responseBody = ""}) async {
    Map<String, dynamic>? traceAttributes;
    if (traceData != null) {
      if (PlatformManager.instance.isAndroid()) {
        traceAttributes = {
          DTTraceTags.id: traceData[DTTraceTags.id],
          DTTraceTags.guid: traceData[DTTraceTags.guid],
          DTTraceTags.traceId: traceData[DTTraceTags.traceId]
        };
      } else if (PlatformManager.instance.isIOS()) {
        traceAttributes = {
          DTTraceTags.traceParent: traceData[DTTraceTags.traceParent],
          DTTraceTags.traceState: traceData[DTTraceTags.traceState],
          DTTraceTags.newrelic: traceData[DTTraceTags.newrelic]
        };
      }
    }

    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': endTime,
      'bytesSent': bytesSent != -1 ? bytesSent : 0,
      'bytesReceived': bytesReceived != -1 ? bytesReceived : 0,
      'responseBody': responseBody,
      'traceAttributes': traceAttributes
    };
    return await _channel.invokeMethod('noticeHttpTransaction', params);
  }

  static List<Map<String, String>> getStackTraceElements(
      StackTrace stackTrace) {
    final Trace trace = Trace.parseVM(stackTrace.toString());
    final List<Map<String, String>> elements = <Map<String, String>>[];

    for (final Frame frame in trace.frames) {
      final Map<String, String> element = <String, String>{
        'file': frame.library,
        'line': frame.line?.toString() ?? '0',
      };
      final String member = frame.member ?? '<fn>';
      final List<String> members = member.split('.');
      if (members.length > 1) {
        element['method'] = members.sublist(1).join('.');
        element['class'] = members.first;
      } else {
        element['method'] = member;
      }
      elements.add(element);
    }

    return elements;
  }
}
