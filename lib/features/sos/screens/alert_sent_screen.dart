import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/sos_provider.dart';
import '../../../core/services/audio_risk_analyzer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/primary_button.dart';

class AlertSentScreen extends ConsumerWidget {
  const AlertSentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final sosState = ref.watch(sosProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.sosRed,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.white),
            SizedBox(width: 10),
            Text('ACTIVE EMERGENCY ALERT'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Alert Confirmation Header Card ──
            AppCard(
              backgroundColor: AppColors.sosRedBg,
              border:
                  Border.all(color: AppColors.sosRed.withOpacity(0.4), width: 1.5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.sosRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emergency, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SOS Alert Broadcasted',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sosRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Event ID: ${sosState.activeEvent?.id ?? "sos_live_001"}\nLive location streaming active.',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Audio Risk Analysis Card ────────────────────────────────────
            _AudioRiskCard(
              isRecording: sosState.isRecordingAudio,
              result: sosState.audioAnalysis,
            ),
            const SizedBox(height: 24),

            // ── Notified Guardians ──────────────────────────────────────────
            Text(
              'Notified Guardians (${contacts.length})',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 12),
            ...contacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: AppCard(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryNavy,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${c.relationship} • ${c.phone}',
                                style: AppTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        // ── Call Now Button ──
                        GestureDetector(
                          onTap: () async {
                            final callUri = Uri.parse('tel:${c.phone}');
                            if (await canLaunchUrl(callUri)) {
                              await launchUrl(callUri);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.sosRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.call, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Call',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.safeGreenBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check, size: 14, color: AppColors.safeGreen),
                              SizedBox(width: 4),
                              Text(
                                'Notified',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.safeGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 24),

            // ── Emergency Dispatch Feed ─────────────────────────────────────
            const Text('Emergency Dispatch Feed', style: AppTypography.titleLarge),
            const SizedBox(height: 12),

            _buildFeedItem(
              icon: Icons.cell_tower,
              title: 'Twilio SMS Fallback',
              subtitle: 'SMS emergency payloads dispatched to offline contacts',
              timestamp: 'Just now',
            ),
            _buildFeedItem(
              icon: Icons.notifications_active,
              title: 'Firebase FCM Push',
              subtitle: 'High-priority push notifications delivered to guardians',
              timestamp: '1 min ago',
            ),
            _buildFeedItem(
              icon: Icons.local_police,
              title: 'Police Dispatch Network',
              subtitle: 'Nearest precinct notified with verified ID telemetry',
              timestamp: '1 min ago',
            ),

            const SizedBox(height: 30),

            // ── Resolve Button ──────────────────────────────────────────────
            PrimaryButton(
              label: 'Mark Safe & Resolve Emergency',
              icon: Icons.check_circle_outline,
              onPressed: () {
                ref.read(sosProvider.notifier).resolveSos();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String timestamp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryNavy, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(timestamp,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textDimmed)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Risk Analysis Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AudioRiskCard extends StatefulWidget {
  final bool isRecording;
  final AudioRiskResult? result;

  const _AudioRiskCard({required this.isRecording, this.result});

  @override
  State<_AudioRiskCard> createState() => _AudioRiskCardState();
}

class _AudioRiskCardState extends State<_AudioRiskCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(_AudioRiskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result != null && oldWidget.result == null) {
      _barCtrl.forward(from: 0);
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'DANGER':
        return AppColors.sosRed;
      case 'WARNING':
        return const Color(0xFFF59E0B); // amber
      case 'SAFE':
        return AppColors.safeGreen;
      default:
        return AppColors.primaryNavy;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'DANGER':
        return Icons.warning_amber_rounded;
      case 'WARNING':
        return Icons.error_outline;
      case 'SAFE':
        return Icons.check_circle_outline;
      default:
        return Icons.mic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isRecording = widget.isRecording;
    final isAnalyzing = result?.predictedClass == 'pending';

    final Color cardBorderColor = result != null && !isAnalyzing
        ? _levelColor(result.dangerLevel).withOpacity(0.5)
        : AppColors.primaryNavy.withOpacity(0.3);

    final Color cardBg = result != null && !isAnalyzing
        ? _levelColor(result.dangerLevel).withOpacity(0.05)
        : AppColors.primaryNavy.withOpacity(0.04);

    return AppCard(
      border: Border.all(color: cardBorderColor, width: 1.5),
      backgroundColor: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (result != null && !isAnalyzing
                          ? _levelColor(result.dangerLevel)
                          : AppColors.primaryNavy)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result != null && !isAnalyzing
                      ? _levelIcon(result.dangerLevel)
                      : Icons.mic,
                  color: result != null && !isAnalyzing
                      ? _levelColor(result.dangerLevel)
                      : AppColors.primaryNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎙️ Audio CNN Risk Analysis',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    if (isRecording || isAnalyzing)
                      FadeTransition(
                        opacity: _pulseCtrl,
                        child: const Text(
                          'Recording 5s audio... analyzing threat level',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else if (result != null)
                      Text(
                        'Recorded ${result.recordedDurationSec.toStringAsFixed(1)}s • Analyzed at ${_timeStr(result.analyzedAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      )
                    else
                      const Text(
                        'Waiting for SOS trigger...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              // Status badge
              if (result != null && !isAnalyzing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _levelColor(result.dangerLevel),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.dangerLevel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                )
              else if (isRecording || isAnalyzing)
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy
                          .withOpacity(0.4 + _pulseCtrl.value * 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'RECORDING',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),

          if (isRecording || isAnalyzing) ...[
            const SizedBox(height: 16),
            // Animated waveform bars while recording
            _WaveformAnimation(controller: _pulseCtrl),
          ],

          // ── Analysis result ──
          if (result != null && !isAnalyzing) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Risk percentage bar
            Row(
              children: [
                const Text(
                  'Risk Score',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
                const Spacer(),
                Text(
                  '${result.riskPercent}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _levelColor(result.dangerLevel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Animated progress bar
            AnimatedBuilder(
              animation: _barAnim,
              builder: (_, __) {
                return Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (result.riskScore * _barAnim.value)
                          .clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _levelColor(result.dangerLevel).withOpacity(0.6),
                              _levelColor(result.dangerLevel),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // 50% threshold marker
                    Positioned(
                      left: null,
                      top: 0,
                      bottom: 0,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 2,
                            color: AppColors.textMuted.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('0%',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                Text(
                  '▲ 50% threshold',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted.withOpacity(0.8)),
                ),
                const Text('100%',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 14),

            // Detected class chip
            Row(
              children: [
                const Text(
                  'Detected Pattern:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _levelColor(result.dangerLevel).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _levelColor(result.dangerLevel).withOpacity(0.4)),
                  ),
                  child: Text(
                    result.predictedClass.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _levelColor(result.dangerLevel),
                    ),
                  ),
                ),
              ],
            ),

            // Feature mini-bars
            if (result.features.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Feature Analysis',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              ...result.features.entries.map((e) => _FeatureBar(
                    label: e.key,
                    value: e.value,
                    color: _levelColor(result.dangerLevel),
                  )),
            ],

            const SizedBox(height: 14),

            // Action taken box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _levelColor(result.dangerLevel).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _levelColor(result.dangerLevel).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    result.dangerLevel == 'DANGER'
                        ? Icons.emergency
                        : result.dangerLevel == 'WARNING'
                            ? Icons.warning_amber
                            : Icons.shield,
                    color: _levelColor(result.dangerLevel),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.action,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _levelColor(result.dangerLevel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Waveform while recording
// ─────────────────────────────────────────────────────────────────────────────
class _WaveformAnimation extends StatelessWidget {
  final AnimationController controller;

  const _WaveformAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(20, (i) {
              final phase = (i / 20 + controller.value) % 1.0;
              final height = 6 + 22 * _wave(phase);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy
                      .withOpacity(0.4 + 0.6 * controller.value),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  double _wave(double x) {
    // Simple sinusoidal wave
    final v = (x * 2 - 1).abs();
    return v * v * (1 - v);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature mini progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _FeatureBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
