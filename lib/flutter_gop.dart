import 'dart:async';
import 'package:flutter/services.dart';

class PronunciationEvaluator {
  static const MethodChannel _channel = MethodChannel(
    'pronunciation_evaluator',
  );
  static const EventChannel _eventChannel = EventChannel(
    'pronunciation_evaluator/events',
  );

  /// 발음 평가를 시작합니다.
  /// [text]는 평가할 텍스트, [language]는 'en' 또는 'ko'를 지정합니다.
  static Future<void> startEvaluation(String text, String language) async {
    try {
      await _channel.invokeMethod('startEvaluation', {
        'text': text,
        'language': language,
      });
    } on PlatformException catch (e) {
      print('Failed to start evaluation: ${e.message}');
      rethrow;
    }
  }

  /// 발음 평가를 중지합니다.
  static Future<void> stopEvaluation() async {
    try {
      await _channel.invokeMethod('stopEvaluation');
    } on PlatformException catch (e) {
      print('Failed to stop evaluation: ${e.message}');
      rethrow;
    }
  }

  /// 실시간 발음 평가 결과를 스트림으로 받습니다.
  static Stream<dynamic> get evaluationStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return event;
      }
      return null;
    });
  }
}
