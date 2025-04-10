import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gop/flutter_gop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PronunciationEvaluator platform = PronunciationEvaluator();
  const MethodChannel channel = MethodChannel('pronunciation_evaluator');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
