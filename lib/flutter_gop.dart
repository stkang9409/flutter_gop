import 'dart:async';
import 'package:flutter_gop/adapters/models/gop_adapter.dart';
import 'package:flutter_gop/adapters/on_device_adapter.dart';
import 'package:flutter_gop/adapters/speech_super_adapter.dart';
import 'package:flutter_gop/adapters/os_stt_adapter.dart';

class PronunciationEvaluator {
  static final Map<String, GoPAdapter> _adapters = {};
  static final StreamController<dynamic> _evaluationStream =
      StreamController<dynamic>.broadcast();

  static Future<void> init(Map<String, dynamic> adapterConfigs) async {
    _adapters.clear();

    if (adapterConfigs.containsKey('on_device')) {
      _adapters['on_device'] = OnDeviceAdapter();
    }

    if (adapterConfigs.containsKey('speech_super')) {
      final config = adapterConfigs['speech_super'];
      if (config != null) {
        _adapters['speech_super'] = SpeechSuperAdaptor(
          config: SpeechSuperConfig(
            language: config['language'] ?? 'en',
            model: config['model'] ?? 'sent.eval',
            apiKey: config['apiKey'] ?? '',
            apiSecret: config['apiSecret'] ?? '',
            userId: config['userId'] ?? '',
          ),
        );
      }
    }

    if (adapterConfigs.containsKey('os_stt')) {
      final config = adapterConfigs['os_stt'];
      if (config != null) {
        _adapters['os_stt'] = OsSttAdaptor(
          config: OsSttConfig(
            language: config['language'] ?? 'en',
            model: config['model'] ?? '',
            apiKey: config['apiKey'] ?? '',
            apiSecret: config['apiSecret'] ?? '',
          ),
        );
      }
    }

    for (final adapter in _adapters.values) {
      await adapter.init();
    }
  }

  /// 발음 평가를 시작합니다.
  /// [text]는 평가할 텍스트, [language]는 'en' 또는 'ko'를 지정합니다.
  /// [adapters]는 사용할 어댑터들의 맵입니다.
  static Future<void> startEvaluation(
    String text,
    String language, {
    Map<String, dynamic>? adapters,
  }) async {
    if (adapters != null) {
      await init(adapters);
    }

    if (_adapters.isEmpty) {
      throw Exception('No adapters configured');
    }

    for (final adapter in _adapters.values) {
      adapter.startEvaluation(text, language);
    }
  }

  /// 발음 평가를 중지합니다.
  static Future<void> stopEvaluation() async {
    for (final adapter in _adapters.values) {
      await adapter.stopEvaluation();
    }
  }

  /// 실시간 발음 평가 결과를 스트림으로 받습니다.
  static Stream<dynamic> get evaluationStream {
    return _evaluationStream.stream;
  }
}
