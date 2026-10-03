import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/sos_provider.dart';
import '../../../core/services/audio_risk_analyzer.dart';
import '../../../core/services/microphone_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/countdown_ring.dart';
import '../../../shared/widgets/pin_verification_dialog.dart';

/// SOS Countdown with audio-first risk gate:
///   Seconds 7→3 : Recording microphone audio (5s)
///   Seconds 2→1 : Analyzing risk score
///   Second  0   : Auto-send if risk > 50%, else show "low risk" result
class SosCountdownScreen extends ConsumerStatefulWidget {
  const SosCountdownScreen({super.key});

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownScreenState();
}

class _SosCountdownScreenState extends ConsumerState<SosCountdownScreen>
    with TickerProviderStateMixin {
  late AnimationController _micPulse;

  // Phase flags
  bool _recordingStarted = false;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // Start audio recording immediately when the screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAudioRecording();
    });
  }

  @override
  void dispose() {
    _micPulse.dispose();
    super.dispose();
  }

  Future<void> _startAudioRecording() async {
    if (_recordingStarted) return;
    setState(() => _recordingStarted = true);

    // Record 5 seconds of real audio from device microphone
    final samples = await MicrophoneService.record5Seconds();

    if (!mounted) return;

    // Move to analyzing phase
    setState(() => _analyzing = true);

    // Small delay to show "Analyzing..." for at least 1 second
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Analyze risk — MicrophoneService already handles fallback internally
    final result = AudioRiskAnalyzer.analyze(samples);

    if (!mounted) return;
    setState(() => _analyzing = false);

    // Decision: risk > 50% → fire SOS, else cancel with notice
    if (result.riskScore >= 0.50) {
      ref.read(sosProvider.notifier).fireSosAlertWithAudio(result);
    } else {
      // Low risk — show result and cancel
      ref.read(sosProvider.notifier).cancelSosLowRisk(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);

    String triggerLabel = 'Manual Long-Press';
    if (sosState.triggerSource == 'ai_assistant') {
      triggerLabel = 'AI Threat Assistant';
    } else if (sosState.triggerSource == 'power_button') {
      triggerLabel = 'Double-Press Power Button';
    } else if (sosState.triggerSource == 'companion_deviation') {
      triggerLabel = 'Companion Route Deviation';
    }

    final phase = _analyzing
        ? 'ANALYZING RISK...'
        : _recordingStarted
            ? 'RECORDING AUDIO'
            : 'PREPARING...';

    final phaseColor = _analyzing ? const Color(0xFFF59E0B) : AppColors.sosRed;

    return Scaffold(
      backgroundColor: AppColors.sosRedBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: phaseColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _analyzing ? Icons.psychology : Icons.mic,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      phase,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'SOS Risk Assessment',
                style: AppTypography.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Triggered by: $triggerLabel',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Phase description card
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _analyzing
                    ? _PhaseCard(
                        key: const ValueKey('analyze'),
                        icon: Icons.psychology,
                        color: const Color(0xFFF59E0B),
                        title: 'Analyzing Audio...',
                        subtitle:
                            'CNN model computing risk score — deciding if SOS should be sent',
                      )
                    : _PhaseCard(
                        key: const ValueKey('record'),
                        icon: Icons.mic,
                        color: AppColors.sosRed,
                        title: 'Recording 5s Audio',
                        subtitle:
                            'Listening to environment — risk prediction determines if SOS fires',
                      ),
              ),

              const Spacer(),

              // Countdown ring OR mic animation
              if (!_analyzing && !_recordingStarted)
                CountdownRing(
                  secondsRemaining: sosState.secondsRemaining,
                  totalSeconds: sosState.totalSeconds,
                  size: 200,
                )
              else if (_analyzing)
                _AnalyzingSpinner()
              else
                _RecordingWaveform(controller: _micPulse),

              const Spacer(),

              // Only cancel button — no "Send Immediately"
              SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.borderLight, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final pinValid = await PinVerificationDialog.verify(
                      context: context,
                      actionTitle: 'Cancel SOS Alert',
                    );
                    if (pinValid && mounted) {
                      ref.read(sosProvider.notifier).cancelSos();
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.safeGreen, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "I'm Safe — Cancel (PIN required)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Phase Info Card ─────────────────────────────────────────────────────────
class _PhaseCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _PhaseCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recording Waveform ───────────────────────────────────────────────────────
class _RecordingWaveform extends StatelessWidget {
  final AnimationController controller;
  const _RecordingWaveform({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sosRed
                  .withOpacity(0.1 + controller.value * 0.15),
              border: Border.all(
                color: AppColors.sosRed
                    .withOpacity(0.4 + controller.value * 0.4),
                width: 3,
              ),
            ),
            child: Icon(
              Icons.mic,
              size: 72,
              color: AppColors.sosRed.withOpacity(0.7 + controller.value * 0.3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Microphone active — listening to environment',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Analyzing Spinner ────────────────────────────────────────────────────────
class _AnalyzingSpinner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.4), width: 3),
          ),
          child: const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              color: Color(0xFFF59E0B),
              strokeWidth: 5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'CNN model analyzing threat level...',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
