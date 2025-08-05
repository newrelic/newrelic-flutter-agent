/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:async';
import 'dart:io' show HttpOverrides, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/loglevel.dart';
import 'package:newrelic_mobile/network_failure.dart';
import 'package:newrelic_mobile/newrelic_dt_trace.dart';
import 'package:newrelic_mobile/newrelic_http_overrides.dart';
import 'package:newrelic_mobile/utils/platform_manager.dart';
import 'package:stack_trace/stack_trace.dart';
import 'metricunit.dart';

class NewrelicMobile {
  static final NewrelicMobile instance = NewrelicMobile._();

  Config? config;

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
          .setAttribute("Flutter Agent Version", "1.1.13");
    }, (Object error, StackTrace stackTrace) {
      NewrelicMobile.instance.recordError(error, stackTrace);
      FlutterError.presentError(
          FlutterErrorDetails(exception: error, stack: stackTrace));
    }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
      if (config.printStatementAsEventsEnabled) {
        logInfo(line);
      }
      parent.print(zone, line);
    }));
  }

  @visibleForTesting
  void setAgentConfiguration(Config config) {
    this.config = config;
  }

  Config getAgentConfiguration() {
    return instance.config!;
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
    if (attributes != null) {
      for (final String key in attributes.keys) {
        if (key == 'attributes') {
          continue;
        }
        eventParams[key] = attributes[key];
      }
    }
    eventParams.remove('stackTraceElements');
    eventParams.remove('attributes');

    NewrelicMobile.instance
        .recordCustomEvent("Mobile Dart Errors", eventAttributes: eventParams);

    await _channel.invokeMethod('recordError', params);
  }

  redirectDebugPrint() {
    if (_originalDebugPrint != null) return;
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (_originalDebugPrint != null) {
        if (message != null) logDebug(message);
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
      'loggingEnabled': config.loggingEnabled,
      'fedRampEnabled': config.fedRampEnabled,
      'offlineStorageEnabled': config.offlineStorageEnabled,
      'backgroundReportingEnabled': config.backgroundReportingEnabled,
      'newEventSystemEnabled': config.newEventSystemEnabled,
      'distributedTracingEnabled': config.distributedTracingEnabled,
      'collectorAddress': config.collectorAddress,
      'crashCollectorAddress': config.crashCollectorAddress,
      'logLevel': config.logLevel.name,
    };

    redirectDebugPrint();
    this.config = config;
    if (config.httpInstrumentationEnabled) {
      HttpOverrides.global =
          NewRelicHttpOverrides(current: HttpOverrides.current);
    }
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

  Future<bool> incrementAttribute(String name, {double? value}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'value': value
    };
    final bool attributeIsIncreased =
        await _channel.invokeMethod('incrementAttribute', params);
    return attributeIsIncreased;
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

  Future<void> recordMetric(String name, String category,
      {double? value, MetricUnit? countUnit, MetricUnit? valueUnit}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'name': name,
      'category': category,
      'value': value,
      'countUnit': countUnit != null ? countUnit.label : countUnit,
      'valueUnit': valueUnit != null ? valueUnit.label : valueUnit,
    };

    return await _channel.invokeMethod('recordMetric', params);
  }

  Future<void> shutDown() async {
    return await _channel.invokeMethod('shutDown');
  }

  Future<String> currentSessionId() async {
    return await _channel.invokeMethod('currentSessionId');
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
    Config con = getAgentConfiguration();

    if (con.interactionTracingEnabled) {
      final Map<String, String> params = <String, String>{
        'actionName': actionName
      };
      final String interactionId =
          await _channel.invokeMethod('startInteraction', params);
      return interactionId;
    } else {
      return "";
    }
  }

  void addHTTPHeadersTrackingFor(List<String> headers) async {
    final Map<String, List<String>> params = <String, List<String>>{
      'headers': headers
    };

    await _channel.invokeMethod('addHTTPHeadersTrackingFor', params);
  }

  Future<dynamic> getHTTPHeadersTrackingFor() async {
    return await _channel.invokeMethod('getHTTPHeadersTrackingFor');
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

  Future<void> setMaxOfflineStorageSize(int megaBytes) async {
    final Map<String, int> params = <String, int>{'megaBytes': megaBytes};
    await _channel.invokeMethod('setMaxOfflineStorageSize', params);
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

  Future<void> noticeHttpTransaction(
      String url,
      String httpMethod,
      int statusCode,
      int startTime,
      int endTime,
      int bytesSent,
      int bytesReceived,
      Map<String, dynamic>? traceData,
      {Map<String, dynamic>? httpParams,
      String responseBody = ""}) async {
    Map<String, dynamic>? traceAttributes;
    if (config!.distributedTracingEnabled) {
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
      'traceAttributes': traceAttributes,
      'params': httpParams
    };
    return await _channel.invokeMethod('noticeHttpTransaction', params);
  }

  Future<void> noticeNetworkFailure(String url, String httpMethod,
      int startTime, int endTime, NetworkFailure errorCode) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'url': url,
      'httpMethod': httpMethod,
      'startTime': startTime,
      'endTime': endTime,
      'errorCode': errorCode.code
    };
    return await _channel.invokeMethod('noticeNetworkFailure', params);
  }

  void log(LogLevel logLevel, String message) async {
    if (message.isEmpty) {
      print("Log message is empty.");
      return;
    }
    Map<String, dynamic> attributes = <String, dynamic>{
      Platform.isAndroid ? "level" : "logLevel": logLevel.name,
      "message": message
    };

    logAttributes(attributes);
    return;
  }

  void logAll(Exception exception, Map<String, dynamic>? attributes) async {
    Map<String, dynamic> allAttributes = <String, dynamic>{
      "message": exception.toString(),
    };
    allAttributes.addAll(attributes!);
    logAttributes(allAttributes);
  }

  void logError(String message) async {
    log(LogLevel.ERROR, message);
  }

  void logDebug(String message) async {
    log(LogLevel.DEBUG, message);
  }

  void logInfo(String message) async {
    log(LogLevel.INFO, message);
  }

  void logVerbose(String message) async {
    log(LogLevel.VERBOSE, message);
  }

  void logWarning(String message) async {
    log(LogLevel.WARN, message);
  }

  void logAttributes(Map<String, dynamic>? attributes) async {
    if (attributes!.isEmpty) {
      print("Attributes are empty.");
      return;
    }

    // attributes["sessionId"] = await currentSessionId();

    final Map<String, dynamic> params = <String, dynamic>{
      'attributes': attributes,
    };
    await _channel.invokeMethod('logAttributes', params);
    return;
  }

  void crashNow({String? name}) async {
    final Map<String, String> params = <String, String>{
      'name': name ?? 'NewRelic Demo Crash',
    };

    await _channel.invokeMethod('crashNow', params);
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
