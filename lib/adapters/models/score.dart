sealed class Score {}

class RealTimeScore extends Score {
  final int eof = 0;
  final double score;

  RealTimeScore(this.score);
}

class FinalScore extends Score {
  final int eof = 1;
  final double score;

  FinalScore(this.score);
}

class ScoreError extends Score {
  final String error;

  ScoreError(this.error);
}
