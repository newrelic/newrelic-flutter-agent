import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The native Android agent reads these string resources to learn the framework and its version when
// the app starts the agent natively before Flutter code runs. They are plain XML, so nothing derives
// them from the plugin version; this test is what stops them going stale.
String _resource(String file, String name) {
  final xml = File('android/src/main/res/values/$file').readAsStringSync();
  final match = RegExp('<string name="$name"[^>]*>([^<]*)</string>').firstMatch(xml);
  expect(match, isNotNull, reason: '$name is missing from $file');
  return match!.group(1)!.trim();
}

void main() {
  test('the Android framework resource names this plugin as Flutter', () {
    expect(_resource('com_newrelic_application_framework.xml', 'com_newrelic_application_framework'), 'Flutter');
  });

  test('the Android framework version resource equals the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1)!;

    expect(
      _resource('com_newrelic_application_framework_version.xml', 'com_newrelic_application_framework_version'),
      version,
      reason: 'update-native-agents.yml should bump the resource with pubspec.yaml',
    );
  });
}
