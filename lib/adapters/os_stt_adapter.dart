import 'package:flutter_gop/adapters/models/gop_adapter.dart';
import 'package:flutter_gop/adapters/models/score.dart';

class OsSttAdaptor extends GoPAdapter {
  OsSttAdaptor({OsSttConfig? config});

  @override
  Future<void> init() async {}

  @override
  Future<void> startEvaluation(String text, String language) async {}

  @override
  Future<void> stopEvaluation() async {}

  @override
  Stream<Score?> get evaluationStream async* {}
}

class OsSttConfig {
  final String language;
  final String model;
  final String apiKey;
  final String apiSecret;

  OsSttConfig({
    required this.language,
    required this.model,
    required this.apiKey,
    required this.apiSecret,
  });
}
