# Web Platform Support

## Overview

As of version 1.1.20, the `newrelic_mobile` package includes conditional exports that allow it to compile on Flutter Web (including WASM) without runtime errors. However, **New Relic Mobile monitoring is only functional on native mobile platforms (iOS and Android)**.

## Behavior by Platform

### Native Platforms (iOS/Android)
- Full New Relic Mobile SDK functionality
- All monitoring features are active
- HTTP instrumentation works as expected

### Web Platforms (JavaScript/WASM)
- Package compiles without errors
- All methods are no-ops (no-operation stubs)
- No monitoring data is collected
- No runtime errors occur

## Usage

Your existing code continues to work without changes:

```dart
import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'package:newrelic_mobile/config.dart';

void main() {
  Config config = Config(
    accessToken: 'YOUR_TOKEN',
    // ... other config options
  );

  NewrelicMobile.instance.start(config, () {
    runApp(MyApp());
  });
}
```

This code will:
- On iOS/Android: Start the New Relic Mobile agent with full monitoring
- On Web: Compile successfully and run the app without monitoring (no-op)

## Web Monitoring Alternative

For web application monitoring, use the **New Relic Browser Agent** instead:
- [New Relic Browser Documentation](https://docs.newrelic.com/docs/browser/browser-monitoring/getting-started/introduction-browser-monitoring/)
- [Browser Agent Installation](https://docs.newrelic.com/docs/browser/browser-monitoring/installation/install-browser-monitoring-agent/)

## Implementation Details

The package uses Dart's conditional imports feature (`dart.library.js_interop`) to:
- Load native implementations (`*_io.dart`) on mobile platforms
- Load no-op stubs (`*_web.dart`) on web platforms

This approach ensures:
- Zero overhead on web platforms
- No breaking changes for existing mobile users
- Compatibility with multi-platform Flutter projects

## Files Affected

The following files now use conditional exports:
- `lib/newrelic_mobile.dart`
- `lib/utils/platform_manager.dart`
- `lib/newrelic_http_overrides.dart`
- `lib/newrelic_http_client.dart`

Each has corresponding `*_io.dart` (native) and `*_web.dart` (stub) implementations.
