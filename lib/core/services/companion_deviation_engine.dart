import 'dart:math';

class CompanionDeviationEngine {
  final double deviationThresholdMeters; // Max allowed distance from route

  const CompanionDeviationEngine({
    this.deviationThresholdMeters = 250.0,
  });

  /// Calculates straight-line Haversine distance in meters between two lat/lng coordinates
  double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) => degree * (pi / 180.0);

  /// Checks if position is deviated from destination or route line
  bool isDeviated({
    required double currentLat,
    required double currentLng,
    required double expectedLat,
    required double expectedLng,
  }) {
    final distance = calculateDistanceMeters(
      currentLat,
      currentLng,
      expectedLat,
      expectedLng,
    );
    return distance > deviationThresholdMeters;
  }

  /// Checks if trip has expired past ETA without user confirming arrival
  bool isEtaExpired(DateTime expectedArrival, {DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    return now.isAfter(expectedArrival);
  }
}
