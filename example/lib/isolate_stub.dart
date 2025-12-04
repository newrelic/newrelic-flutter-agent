/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/// Stub implementation for dart:isolate on web platform
/// These classes provide no-op implementations for web compatibility

class Isolate {
  static Future<Isolate> spawn<T>(
    void Function(T) entryPoint,
    T message, {
    bool paused = false,
    bool errorsAreFatal = true,
    SendPort? onExit,
    SendPort? onError,
    String? debugName,
  }) {
    throw UnsupportedError('Isolates are not supported on web');
  }

  void addErrorListener(SendPort port) {
    throw UnsupportedError('Isolates are not supported on web');
  }
}

class ReceivePort {
  ReceivePort();

  void listen(void Function(dynamic) onData) {
    throw UnsupportedError('Isolates are not supported on web');
  }

  SendPort get sendPort => throw UnsupportedError('Isolates are not supported on web');

  dynamic get first => throw UnsupportedError('Isolates are not supported on web');
}

class SendPort {}