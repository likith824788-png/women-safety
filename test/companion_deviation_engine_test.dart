import 'package:flutter_test/flutter_test.dart';
import 'package:personal_safety_app/core/services/companion_deviation_engine.dart';

void main() {
  group('CompanionDeviationEngine Tests', () {
    const engine = CompanionDeviationEngine(deviationThresholdMeters: 250.0);

    test('Distance within threshold is not deviated', () {
      // ~50m apart coordinates
      final deviated = engine.isDeviated(
        currentLat: 12.9716,
        currentLng: 77.5946,
        expectedLat: 12.9718,
        expectedLng: 77.5948,
      );
      expect(deviated, isFalse);
    });

    test('Distance beyond 250m is flagged as deviated', () {
      // ~1km apart coordinates
      final deviated = engine.isDeviated(
        currentLat: 12.9716,
        currentLng: 77.5946,
        expectedLat: 12.9800,
        expectedLng: 77.6000,
      );
      expect(deviated, isTrue);
    });

    test('ETA expiry detection', () {
      final pastEta = DateTime.now().subtract(const Duration(minutes: 5));
      final futureEta = DateTime.now().add(const Duration(minutes: 20));

      expect(engine.isEtaExpired(pastEta), isTrue);
      expect(engine.isEtaExpired(futureEta), isFalse);
    });
  });
}
