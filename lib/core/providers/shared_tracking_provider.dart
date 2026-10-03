import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Represents a live companion journey being shared to the Monitor page.
class CompanionTracking {
  final String id;
  final String userName;
  final String userPhone;
  final String destination;
  final LatLng currentPosition;
  final LatLng destinationPosition;
  final DateTime startedAt;
  final bool isActive;
  final double? distanceRemainingKm;
  final String? etaLabel;
  final bool isDeviated;
  final DateTime? deviationStartedAt;

  CompanionTracking({
    required this.id,
    required this.userName,
    required this.userPhone,
    required this.destination,
    required this.currentPosition,
    required this.destinationPosition,
    required this.startedAt,
    this.isActive = true,
    this.distanceRemainingKm,
    this.etaLabel,
    this.isDeviated = false,
    this.deviationStartedAt,
  });

  CompanionTracking copyWith({
    LatLng? currentPosition,
    bool? isActive,
    double? distanceRemainingKm,
    String? etaLabel,
    bool? isDeviated,
    DateTime? deviationStartedAt,
  }) {
    return CompanionTracking(
      id: id,
      userName: userName,
      userPhone: userPhone,
      destination: destination,
      currentPosition: currentPosition ?? this.currentPosition,
      destinationPosition: destinationPosition,
      startedAt: startedAt,
      isActive: isActive ?? this.isActive,
      distanceRemainingKm: distanceRemainingKm ?? this.distanceRemainingKm,
      etaLabel: etaLabel ?? this.etaLabel,
      isDeviated: isDeviated ?? this.isDeviated,
      deviationStartedAt: deviationStartedAt ?? this.deviationStartedAt,
    );
  }

  String get durationLabel {
    final mins = DateTime.now().difference(startedAt).inMinutes;
    if (mins < 60) return '${mins}m ago';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}m ago';
  }
}

class SharedTrackingNotifier extends StateNotifier<List<CompanionTracking>> {
  SharedTrackingNotifier() : super([]);

  void addTracking(CompanionTracking tracking) {
    state = [tracking, ...state];
  }

  void updateTracking(String id, CompanionTracking updated) {
    state = state.map((t) => t.id == id ? updated : t).toList();
  }

  void endTracking(String id) {
    state = state
        .map((t) => t.id == id ? t.copyWith(isActive: false) : t)
        .toList();
  }

  void clearAll() {
    state = [];
  }
}

final sharedTrackingProvider =
    StateNotifierProvider<SharedTrackingNotifier, List<CompanionTracking>>(
  (ref) => SharedTrackingNotifier(),
);
