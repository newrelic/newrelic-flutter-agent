/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:newrelic_mobile/loglevel.dart';

class Config {
  final String accessToken;
  final bool analyticsEventEnabled;
  final bool crashReportingEnabled;
  final bool interactionTracingEnabled;
  final bool networkRequestEnabled;
  final bool networkErrorRequestEnabled;
  final bool httpResponseBodyCaptureEnabled;
  final bool loggingEnabled;
  final bool webViewInstrumentation;
  final bool printStatementAsEventsEnabled;
  final bool httpInstrumentationEnabled;
  final bool fedRampEnabled;
  final bool offlineStorageEnabled;
  final bool backgroundReportingEnabled;
  final bool newEventSystemEnabled;
  final bool distributedTracingEnabled;
  final String collectorAddress;
  final String crashCollectorAddress;
  final LogLevel logLevel;

  Config(
      {required this.accessToken,
      this.analyticsEventEnabled = true,
      this.crashReportingEnabled = true,
      this.httpResponseBodyCaptureEnabled = true,
      this.interactionTracingEnabled = true,
      this.loggingEnabled = true,
      this.networkErrorRequestEnabled = true,
      this.networkRequestEnabled = true,
      this.webViewInstrumentation = true,
      this.printStatementAsEventsEnabled = true,
      this.httpInstrumentationEnabled = true,
      this.fedRampEnabled = false,
      this.offlineStorageEnabled = true,
      this.backgroundReportingEnabled = false,
      this.distributedTracingEnabled = true,
      this.newEventSystemEnabled = false,
      this.collectorAddress = "",
      this.crashCollectorAddress = "",
      this.logLevel = LogLevel.DEBUG});
}
