import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sos_event_model.dart';
import '../services/audio_risk_analyzer.dart';
import '../services/firebase_service.dart';
import '../services/microphone_service.dart';
import 'contacts_provider.dart';
import 'location_provider.dart';

enum SosState { idle, countdown, sent, cancelled, resolved }

class SosProgressState {
  final SosState state;
  final int secondsRemaining;
  final int totalSeconds;
  final SosEvent? activeEvent;
  final String triggerSource;

  // ── Audio risk analysis result ──
  final AudioRiskResult? audioAnalysis;
  final bool isRecordingAudio;

  SosProgressState({
    this.state = SosState.idle,
    this.secondsRemaining = 10,
    this.totalSeconds = 10,
    this.activeEvent,
    this.triggerSource = 'manual',
    this.audioAnalysis,
    this.isRecordingAudio = false,
  });

  SosProgressState copyWith({
    SosState? state,
    int? secondsRemaining,
    int? totalSeconds,
    SosEvent? activeEvent,
    String? triggerSource,
    AudioRiskResult? audioAnalysis,
    bool? isRecordingAudio,
  }) {
    return SosProgressState(
      state: state ?? this.state,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      activeEvent: activeEvent ?? this.activeEvent,
      triggerSource: triggerSource ?? this.triggerSource,
      audioAnalysis: audioAnalysis ?? this.audioAnalysis,
      isRecordingAudio: isRecordingAudio ?? this.isRecordingAudio,
    );
  }

  bool get isCountdownActive => state == SosState.countdown;
  bool get isAlertSent => state == SosState.sent;
  int get remainingSeconds => secondsRemaining;
}

class SosNotifier extends StateNotifier<SosProgressState> {
  final Ref _ref;
  Timer? _timer;

  SosNotifier(this._ref) : super(SosProgressState());

  void startSosCountdown({String triggerSource = 'manual', int seconds = 10}) {
    _timer?.cancel();
    final contacts = _ref.read(contactsProvider);
    final contactIds = contacts.map((c) => c.id).toList();

    // Use real GPS from locationProvider
    final locationState = _ref.read(locationProvider);
    final double lat = locationState.currentLat;
    final double lng = locationState.currentLng;

    final event = SosEvent(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      uid: FirebaseService.currentUser?.uid ?? 'aegis_user',
      status: 'countdown',
      triggeredBy: triggerSource,
      createdAt: DateTime.now(),
      latitude: lat,
      longitude: lng,
      notifiedContactIds: contactIds,
    );

    state = state.copyWith(
      state: SosState.countdown,
      secondsRemaining: seconds,
      totalSeconds: seconds,
      activeEvent: event,
      triggerSource: triggerSource,
      audioAnalysis: null,
      isRecordingAudio: false,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining > 1) {
        state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
      } else {
        _timer?.cancel();
        fireSosAlert();
      }
    });
  }

  /// Fires the SOS alert and automatically starts a 5-second audio recording
  /// for risk analysis. Updates state with [AudioRiskResult] when done.
  void fireSosAlert() {
    _timer?.cancel();
    if (state.activeEvent != null) {
      final updatedEvent = SosEvent(
        id: state.activeEvent!.id,
        uid: state.activeEvent!.uid,
        status: 'sent',
        triggeredBy: state.activeEvent!.triggeredBy,
        createdAt: state.activeEvent!.createdAt,
        latitude: state.activeEvent!.latitude,
        longitude: state.activeEvent!.longitude,
        notifiedContactIds: state.activeEvent!.notifiedContactIds,
      );

      // Mark SOS as sent and start audio recording simultaneously
      state = state.copyWith(
        state: SosState.sent,
        activeEvent: updatedEvent,
        secondsRemaining: 0,
        isRecordingAudio: true,
        audioAnalysis: AudioRiskResult.pending(),
      );

      // Record 5s audio in background and analyze risk
      _recordAndAnalyzeAudio();
    }
  }

  /// Records 5 seconds of audio and computes the CNN-equivalent risk score.
  Future<void> _recordAndAnalyzeAudio() async {
    try {
      // Record real audio from device microphone
      final samples = await MicrophoneService.record5Seconds();

      // MicrophoneService already falls back to simulation internally
      final List<double> audioData = samples;

      // Run CNN-equivalent risk analysis
      final result = AudioRiskAnalyzer.analyze(audioData);

      debugPrint(
        'SOS Audio Analysis: ${result.predictedClass} | '
        'Risk: ${result.riskPercent}% | '
        'Level: ${result.dangerLevel}',
      );

      // Update state with analysis result
      if (mounted) {
        state = state.copyWith(
          isRecordingAudio: false,
          audioAnalysis: result,
        );
      }
    } catch (e) {
      debugPrint('SOS audio analysis error: $e');
      if (mounted) {
        state = state.copyWith(
          isRecordingAudio: false,
          audioAnalysis: AudioRiskResult(
            riskScore: 0.5,
            dangerLevel: 'WARNING',
            predictedClass: 'unknown',
            action: 'Analysis failed — SOS kept active for safety',
            features: {},
            sosConfirmed: true,
            recordedDurationSec: 5.0,
          ),
        );
      }
    }
  }

  void fireSosAlertWithAudio(AudioRiskResult result) {
    _timer?.cancel();
    if (state.activeEvent != null) {
      final updatedEvent = SosEvent(
        id: state.activeEvent!.id,
        uid: state.activeEvent!.uid,
        status: 'sent',
        triggeredBy: state.activeEvent!.triggeredBy,
        createdAt: state.activeEvent!.createdAt,
        latitude: state.activeEvent!.latitude,
        longitude: state.activeEvent!.longitude,
        notifiedContactIds: state.activeEvent!.notifiedContactIds,
      );

      state = state.copyWith(
        state: SosState.sent,
        activeEvent: updatedEvent,
        secondsRemaining: 0,
        isRecordingAudio: false,
        audioAnalysis: result,
      );
    }
  }

  void cancelSosLowRisk(AudioRiskResult result) {
    _timer?.cancel();
    state = state.copyWith(
      state: SosState.cancelled,
      secondsRemaining: 0,
      isRecordingAudio: false,
      audioAnalysis: result,
    );
    Future.delayed(const Duration(milliseconds: 3000), () {
      state = SosProgressState();
    });
  }

  void cancelSos() {

    _timer?.cancel();
    state = state.copyWith(
      state: SosState.cancelled,
      secondsRemaining: 0,
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      state = SosProgressState();
    });
  }

  void resolveSos() {
    _timer?.cancel();
    state = state.copyWith(
      state: SosState.resolved,
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      state = SosProgressState();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sosProvider = StateNotifierProvider<SosNotifier, SosProgressState>((ref) {
  return SosNotifier(ref);
});
