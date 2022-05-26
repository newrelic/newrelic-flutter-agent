import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/newrelic_mobile.dart';

void main() {
  const MethodChannel channel = MethodChannel('newrelic_mobile');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await NewrelicMobile.platformVersion, '42');
  });
}
