import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The native iOS agent reads this plist to learn the framework and its version when the app starts
// the agent natively before Flutter code runs. It is plain XML, so nothing derives it from the
// plugin version; this test is what stops it going stale.
const _plist = 'ios/newrelic_mobile/Sources/newrelic_mobile/Resources/NewRelicHybrid.plist';

String _value(String key) {
  final xml = File(_plist).readAsStringSync();
  final match = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>').firstMatch(xml);
  expect(match, isNotNull, reason: '$key is missing from $_plist');
  return match!.group(1)!.trim();
}

void main() {
  test('the iOS framework plist names this plugin as Flutter', () {
    expect(_value('ApplicationFramework'), 'Flutter');
  });

  test('the iOS framework plist version equals the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1)!;

    expect(
      _value('ApplicationFrameworkVersion'),
      version,
      reason: 'update-native-agents.yml should bump the plist with pubspec.yaml',
    );
  });

  test('the plist is shipped by both the podspec and the Swift package', () {
    expect(File('ios/newrelic_mobile.podspec').readAsStringSync(), contains('Resources/NewRelicHybrid.plist'));
    expect(File('ios/newrelic_mobile/Package.swift').readAsStringSync(), contains('Resources/NewRelicHybrid.plist'));
  });
}
