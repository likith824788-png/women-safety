import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/companion_trip_model.dart';
import '../services/companion_deviation_engine.dart';
import 'sos_provider.dart';

enum CompanionTripStatus { inactive, active, deviated, arrived, sosTriggered }

class CompanionState {
  final CompanionTripStatus status;
  final CompanionTrip? activeTrip;
  final int minutesRemaining;
  final bool isDeviatedModalOpen;

  CompanionState({
    this.status = CompanionTripStatus.inactive,
    this.activeTrip,
    this.minutesRemaining = 0,
    this.isDeviatedModalOpen = false,
  });

  CompanionState copyWith({
    CompanionTripStatus? status,
    CompanionTrip? activeTrip,
    int? minutesRemaining,
    bool? isDeviatedModalOpen,
  }) {
    return CompanionState(
      status: status ?? this.status,
      activeTrip: activeTrip ?? this.activeTrip,
      minutesRemaining: minutesRemaining ?? this.minutesRemaining,
      isDeviatedModalOpen: isDeviatedModalOpen ?? this.isDeviatedModalOpen,
    );
  }
}

class CompanionNotifier extends StateNotifier<CompanionState> {
  final Ref _ref;
  Timer? _etaTimer;
  final _engine = const CompanionDeviationEngine();

  CompanionNotifier(this._ref) : super(CompanionState());

  void startTrip({
    required String destination,
    required int etaMinutes,
    required List<String> recipientIds,
  }) {
    final expectedArrival = DateTime.now().add(Duration(minutes: etaMinutes));
    final trip = CompanionTrip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      uid: 'user_demo_777',
      destination: destination,
      expectedArrival: expectedArrival,
      status: 'active',
      routePolyline: 'g_s_Fkn~wO...encoded_polyline',
      recipientContactIds: recipientIds,
    );

    state = state.copyWith(
      status: CompanionTripStatus.active,
      activeTrip: trip,
      minutesRemaining: etaMinutes,
      isDeviatedModalOpen: false,
    );

    _startEtaCountdown();
  }

  void _startEtaCountdown() {
    _etaTimer?.cancel();
    _etaTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (state.minutesRemaining > 1) {
        state = state.copyWith(minutesRemaining: state.minutesRemaining - 1);
      } else {
        // ETA expired without arrival check-in -> trigger deviation alert
        triggerDeviationAlert();
      }
    });
  }

  void simulateRouteDeviation() {
    state = state.copyWith(
      status: CompanionTripStatus.deviated,
      isDeviatedModalOpen: true,
    );
  }

  void triggerDeviationAlert() {
    state = state.copyWith(
      status: CompanionTripStatus.deviated,
      isDeviatedModalOpen: true,
    );
  }

  void dismissDeviationAndContinue() {
    state = state.copyWith(
      status: CompanionTripStatus.active,
      isDeviatedModalOpen: false,
    );
  }

  void escalateDeviationToSos() {
    state = state.copyWith(
      status: CompanionTripStatus.sosTriggered,
      isDeviatedModalOpen: false,
    );
    _ref.read(sosProvider.notifier).startSosCountdown(
          triggerSource: 'companion_deviation',
          seconds: 10,
        );
  }

  void completeTrip() {
    _etaTimer?.cancel();
    state = state.copyWith(
      status: CompanionTripStatus.arrived,
      isDeviatedModalOpen: false,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      state = CompanionState();
    });
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    super.dispose();
  }
}

final companionProvider =
    StateNotifierProvider<CompanionNotifier, CompanionState>((ref) {
  return CompanionNotifier(ref);
});
