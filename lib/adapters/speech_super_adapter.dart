import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_gop/adapters/models/gop_adapter.dart';
import 'package:flutter_gop/adapters/models/score.dart';
import 'package:flutter_gop/services/speech_super_service.dart';

class SpeechSuperAdaptor extends GoPAdapter {
  late final SpeechService _speechService;
  final SpeechSuperConfig config;
  final StreamController<Score?> _evaluationStream =
      StreamController<Score?>.broadcast();

  SpeechSuperAdaptor({required this.config})
    : _speechService = SpeechService(
        userId: config.userId,
        appKey: config.apiKey,
        secretKey: config.apiSecret,
        log: (String message) {
          if (kDebugMode) {
            print(message);
          }
        },
      );

  @override
  Future<void> init() async {
    await _speechService.initialize();
  }

  @override
  Future<void> startEvaluation(String text, String language) async {
    Completer<void> completer = Completer<void>();
    await _speechService.start(
      coreType: 'sent.eval',
      refText: text,
      onStart: () {
        completer.complete();
      },
      onRecordEnd: () {
        _evaluationStream.add(null);
      },
      onScore: (String score) {
        final data = jsonDecode(score);
        _evaluationStream.add(data);
      },
      onStartRecordFail: (String error) {
        _evaluationStream.add(null);
        completer.completeError(Exception('Start record failed: $error'));
      },
    );
    await completer.future;
  }

  @override
  Future<void> stopEvaluation() async {
    await _speechService.stop();
  }

  @override
  Stream<Score?> get evaluationStream async* {
    yield* _evaluationStream.stream;
  }
}

class SpeechSuperConfig {
  final String language;
  final String model;
  final String apiKey;
  final String apiSecret;
  final String userId;

  SpeechSuperConfig({
    required this.language,
    required this.model,
    required this.apiKey,
    required this.apiSecret,
    required this.userId,
  });
}
