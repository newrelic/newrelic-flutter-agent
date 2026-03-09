/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:newrelic_mobile/config.dart';
import 'package:newrelic_mobile/loglevel.dart';
import 'package:newrelic_mobile/network_failure.dart';

import '../metricunit.dart';

/// Web stub implementation of NewrelicMobile
/// New Relic Mobile SDK is not supported on web platforms.
/// All methods are no-ops to allow compilation without errors.
/// For web monitoring, use New Relic Browser Agent instead.
class NewrelicMobile {
  static final NewrelicMobile instance = NewrelicMobile._();

  Config? config;

  NewrelicMobile._();

  Future<String?> get platformVersion async {
    return 'web';
  }

  Future<void> start(Config config, Function runApp) async {
    // Initialize Flutter binding and run the app without New Relic monitoring
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = NewrelicMobile.onError;
    runApp();
  }

  @visibleForTesting
  void setAgentConfiguration(Config config) {
    this.config = config;
  }

  Config getAgentConfiguration() {
    return instance.config ?? Config(accessToken: '');
  }

  static void onError(FlutterErrorDetails errorDetails) async {
    // Simply present the error without New Relic recording on web
    FlutterError.presentError(errorDetails);
  }

  void recordError(Object error, StackTrace? stackTrace,
      {Map<String, dynamic>? attributes, bool isFatal = false}) async {
    // No-op on web
  }

  redirectDebugPrint() {
    // No-op on web
  }

  Future<void> startAgent(Config config) async {
    this.config = config;
    // No-op on web
  }

  Future<bool?> setUserId(String userId) async {
    return false;
  }

  Future<bool> setAttribute(String name, dynamic value) async {
    return false;
  }

  Future<bool> removeAttribute(String name) async {
    return false;
  }

  Future<bool> incrementAttribute(String name, {double? value}) async {
    return false;
  }

  Future<bool> recordBreadcrumb(String name,
      {Map<String, dynamic>? eventAttributes}) async {
    return false;
  }

  Future<void> recordMetric(String name, String category,
      {double? value, MetricUnit? countUnit, MetricUnit? valueUnit}) async {
    // No-op on web
  }

  Future<void> shutDown() async {
    // No-op on web
  }

  Future<String> currentSessionId() async {
    return '';
  }

  Future<bool> recordCustomEvent(String eventType,
      {String eventName = "", Map<String, dynamic>? eventAttributes}) async {
    return false;
  }

  Future<String> startInteraction(String actionName) async {
    return '';
  }

  void addHTTPHeadersTrackingFor(List<String> headers) async {
    // No-op on web
  }

  Future<dynamic> getHTTPHeadersTrackingFor() async {
    return [];
  }

  Future<Map<String, dynamic>> noticeDistributedTrace(
      Map<String, dynamic> requestAttributes) async {
    return {};
  }

  Future<void> setInteractionName(String interactionName) async {
    // No-op on web
  }

  Future<void> setMaxEventPoolSize(int maxSize) async {
    // No-op on web
  }

  Future<void> setMaxOfflineStorageSize(int megaBytes) async {
    // No-op on web
  }

  Future<void> setMaxEventBufferTime(int maxBufferTimeInSec) async {
    // No-op on web
  }

  void endInteraction(String interactionId) async {
    // No-op on web
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
    // No-op on web
  }

  Future<void> noticeNetworkFailure(String url, String httpMethod,
      int startTime, int endTime, NetworkFailure errorCode) async {
    // No-op on web
  }

  void log(LogLevel logLevel, String message) async {
    // No-op on web
  }

  void logAll(Exception exception, Map<String, dynamic>? attributes) async {
    // No-op on web
  }

  void logError(String message) async {
    // No-op on web
  }

  void logDebug(String message) async {
    // No-op on web
  }

  void logInfo(String message) async {
    // No-op on web
  }

  void logVerbose(String message) async {
    // No-op on web
  }

  void logWarning(String message) async {
    // No-op on web
  }

  void logAttributes(Map<String, dynamic>? attributes) async {
    // No-op on web
  }

  void crashNow({String? name}) async {
    // No-op on web
  }

  static List<Map<String, String>> getStackTraceElements(
      StackTrace stackTrace) {
    return [];
  }
}
