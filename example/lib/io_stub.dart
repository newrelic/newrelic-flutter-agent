/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/// Stub implementation for dart:io on web platform
/// These classes provide no-op implementations for web compatibility

import 'dart:async';
import 'dart:convert';

class HttpClient {
  HttpClient();

  Future<HttpClientRequest> postUrl(Uri url) {
    throw UnsupportedError('HttpClient is not supported on web. Use package:http or dio instead.');
  }
}

class HttpClientRequest {
  HttpHeaders get headers => HttpHeaders();

  void write(String data) {
    throw UnsupportedError('HttpClient is not supported on web');
  }

  Future<HttpClientResponse> close() {
    throw UnsupportedError('HttpClient is not supported on web');
  }
}

class HttpClientResponse {
  Stream<List<int>> transform(Converter<List<int>, String> converter) {
    throw UnsupportedError('HttpClient is not supported on web');
  }
}

class HttpHeaders {
  static const contentTypeHeader = 'content-type';

  void set(String name, Object value) {
    throw UnsupportedError('HttpClient is not supported on web');
  }
}