/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

class Config {
  final String accessToken;
  final bool analyticsEventEnabled;
  final bool crashReportingEnabled;
  final bool interactionTracingEnabled;
  final bool networkRequestEnabled;
  final bool networkErrorRequestEnabled;
  final bool httpRequestBodyCaptureEnabled;
  final bool loggingEnabled;
  final bool webViewInstrumentation;

  Config(
      {required this.accessToken,
      this.analyticsEventEnabled = true,
      this.crashReportingEnabled = true,
      this.httpRequestBodyCaptureEnabled = true,
      this.interactionTracingEnabled = true,
      this.loggingEnabled = true,
      this.networkErrorRequestEnabled = true,
      this.networkRequestEnabled = true,
      this.webViewInstrumentation = true});
}
