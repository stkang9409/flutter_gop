import 'package:flutter_gop/adapters/models/score.dart';

abstract class GoPAdapter {
  Future<void> startEvaluation(String text, String language) async {}

  Future<void> stopEvaluation() async {}

  Future<void> init() async {}

  Stream<Score?> get evaluationStream async* {}
}
