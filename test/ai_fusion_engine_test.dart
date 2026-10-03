import 'package:flutter_test/flutter_test.dart';
import 'package:personal_safety_app/core/services/ai_fusion_engine.dart';

void main() {
  group('AiFusionEngine Risk Fusion Tests', () {
    const engine = AiFusionEngine();

    test('Low scores result in noAction (< 0.50)', () {
      final combined = engine.computeCombinedScore(0.2, 0.3);
      final action = engine.determineAction(combined);
      expect(combined, lessThan(0.50));
      expect(action, equals(AiAction.noAction));
      expect(engine.actionToString(action), equals('no_action'));
    });

    test('Medium scores result in showCountdown (0.50 - 0.75)', () {
      final combined = engine.computeCombinedScore(0.6, 0.65);
      final action = engine.determineAction(combined);
      expect(combined, greaterThanOrEqualTo(0.50));
      expect(combined, lessThan(0.75));
      expect(action, equals(AiAction.showCountdown));
      expect(engine.actionToString(action), equals('show_countdown'));
    });

    test('High scores result in autoEscalate (> 0.75)', () {
      final combined = engine.computeCombinedScore(0.85, 0.90);
      final action = engine.determineAction(combined);
      expect(combined, greaterThanOrEqualTo(0.75));
      expect(action, equals(AiAction.autoEscalate));
      expect(engine.actionToString(action), equals('auto_escalate'));
    });

    test('Text threat analyzer detects emergency keywords', () {
      final scoreUrgent = engine.analyzeTextThreat('Someone is following me, help!');
      expect(scoreUrgent, greaterThanOrEqualTo(0.80));

      final scoreMild = engine.analyzeTextThreat('Walking home, it is a bit dark.');
      expect(scoreMild, greaterThan(0.20));

      final scoreSafe = engine.analyzeTextThreat('Everything is fine, see you soon.');
      expect(scoreSafe, lessThan(0.30));
    });
  });
}
