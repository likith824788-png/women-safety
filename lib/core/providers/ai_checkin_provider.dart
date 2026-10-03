import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/checkin_message_model.dart';
import '../services/ai_fusion_engine.dart';
import 'sos_provider.dart';

class AiCheckinState {
  final List<CheckinMessage> messages;
  final bool isListening;
  final bool isAnalyzing;
  final double latestRiskScore;
  final String statusIndicator;

  AiCheckinState({
    this.messages = const [],
    this.isListening = false,
    this.isAnalyzing = false,
    this.latestRiskScore = 0.0,
    this.statusIndicator = 'AI Monitoring Active',
  });

  AiCheckinState copyWith({
    List<CheckinMessage>? messages,
    bool? isListening,
    bool? isAnalyzing,
    double? latestRiskScore,
    String? statusIndicator,
  }) {
    return AiCheckinState(
      messages: messages ?? this.messages,
      isListening: isListening ?? this.isListening,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      latestRiskScore: latestRiskScore ?? this.latestRiskScore,
      statusIndicator: statusIndicator ?? this.statusIndicator,
    );
  }
}

class AiCheckinNotifier extends StateNotifier<AiCheckinState> {
  final Ref _ref;
  final _fusionEngine = const AiFusionEngine();

  AiCheckinNotifier(this._ref)
      : super(
          AiCheckinState(
            messages: [
              CheckinMessage(
                id: 'msg_welcome',
                text: 'Hello, I am your Safety AI assistant. How are you feeling right now?',
                createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
                riskScore: 0.05,
                action: 'no_action',
                isUserMessage: false,
              ),
            ],
          ),
        );

  Future<void> sendMessage(String text, {double simulatedAudioScore = 0.0}) async {
    state = state.copyWith(isAnalyzing: true);

    // 1. Calculate text threat score
    final textScore = _fusionEngine.analyzeTextThreat(text);

    // 2. Compute multimodal fusion score
    final combinedRisk = _fusionEngine.computeCombinedScore(
      simulatedAudioScore,
      textScore,
    );

    // 3. Determine action threshold
    final action = _fusionEngine.determineAction(combinedRisk);
    final actionStr = _fusionEngine.actionToString(action);

    final userMsg = CheckinMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      createdAt: DateTime.now(),
      riskScore: combinedRisk,
      action: actionStr,
      isUserMessage: true,
    );

    String systemResponse;
    if (action == AiAction.autoEscalate) {
      systemResponse = 'HIGH RISK DETECTED (${(combinedRisk * 100).toInt()}%). Triggering Emergency SOS immediately!';
    } else if (action == AiAction.showCountdown) {
      systemResponse = 'Elevated concern detected (${(combinedRisk * 100).toInt()}%). Starting 10-second safety check countdown.';
    } else {
      systemResponse = 'Understood. I am continuing to monitor your surroundings in the background.';
    }

    final botMsg = CheckinMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch + 1}',
      text: systemResponse,
      createdAt: DateTime.now(),
      riskScore: combinedRisk,
      action: actionStr,
      isUserMessage: false,
    );

    state = state.copyWith(
      isAnalyzing: false,
      messages: [...state.messages, userMsg, botMsg],
      latestRiskScore: combinedRisk,
      statusIndicator: action == AiAction.noAction
          ? 'Monitoring • Low Risk'
          : action == AiAction.showCountdown
              ? 'Warning • Medium Risk'
              : 'CRITICAL • Alert Auto-Escalating',
    );

    // Trigger SOS flows based on AI evaluation
    if (action == AiAction.showCountdown) {
      _ref.read(sosProvider.notifier).startSosCountdown(
            triggerSource: 'ai_text',
            seconds: 10,
          );
    } else if (action == AiAction.autoEscalate) {
      _ref.read(sosProvider.notifier).startSosCountdown(
            triggerSource: 'ai_audio',
            seconds: 3, // Rapid countdown for direct escalation
          );
    }
  }

  void toggleVoiceListening() {
    final next = !state.isListening;
    state = state.copyWith(
      isListening: next,
      statusIndicator: next ? 'Listening to ambient audio...' : 'AI Monitoring Active',
    );

    if (next) {
      // Simulate speech detection
      Future.delayed(const Duration(seconds: 3), () {
        if (state.isListening) {
          sendMessage('I think someone is following me down this dark alley', simulatedAudioScore: 0.82);
          state = state.copyWith(isListening: false);
        }
      });
    }
  }
}

final aiCheckinProvider =
    StateNotifierProvider<AiCheckinNotifier, AiCheckinState>((ref) {
  return AiCheckinNotifier(ref);
});
