enum AiAction { noAction, showCountdown, autoEscalate }

class AiFusionEngine {
  final double audioWeight;
  final double textWeight;
  final double countdownThreshold;
  final double escalateThreshold;

  const AiFusionEngine({
    this.audioWeight = 0.40,
    this.textWeight = 0.60,
    this.countdownThreshold = 0.50,
    this.escalateThreshold = 0.75,
  });

  /// Fuses audio CNN score [0.0 - 1.0] and text DistilBERT score [0.0 - 1.0]
  double computeCombinedScore(double audioScore, double textScore) {
    final clampedAudio = audioScore.clamp(0.0, 1.0);
    final clampedText = textScore.clamp(0.0, 1.0);
    final score = (clampedAudio * audioWeight) + (clampedText * textWeight);
    return double.parse(score.toStringAsFixed(3));
  }

  /// Determines appropriate safety action based on combined risk score
  AiAction determineAction(double combinedScore) {
    if (combinedScore >= escalateThreshold) {
      return AiAction.autoEscalate;
    } else if (combinedScore >= countdownThreshold) {
      return AiAction.showCountdown;
    } else {
      return AiAction.noAction;
    }
  }

  /// Convenience string mapping for Firestore logging
  String actionToString(AiAction action) {
    switch (action) {
      case AiAction.autoEscalate:
        return 'auto_escalate';
      case AiAction.showCountdown:
        return 'show_countdown';
      case AiAction.noAction:
        return 'no_action';
    }
  }

  /// Analyzes text message with simulated NLP keyword classifier
  double analyzeTextThreat(String message) {
    final lower = message.toLowerCase();
    final urgentKeywords = ['help', 'danger', 'following me', 'scared', 'attack', 'emergency', 'sos', 'stop'];
    final mildKeywords = ['nervous', 'dark', 'alone', 'weird', 'uncomfortable', 'fast'];

    double score = 0.1; // Baseline safe score
    for (var kw in urgentKeywords) {
      if (lower.contains(kw)) score += 0.45;
    }
    for (var kw in mildKeywords) {
      if (lower.contains(kw)) score += 0.25;
    }
    return score.clamp(0.0, 1.0);
  }
}
