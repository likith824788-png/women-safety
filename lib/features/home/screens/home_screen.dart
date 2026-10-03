import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/providers/sos_provider.dart';
import '../../../core/services/audio_risk_analyzer.dart';
import '../../../core/services/microphone_service.dart';
import '../../../core/services/resend_service.dart';
import '../../../core/services/twilio_service.dart';
import '../../../core/services/web_audio_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/pin_verification_dialog.dart';
import '../../../shared/widgets/status_pill.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateTab;

  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _holdProgressController;
  bool _isLongPressing = false;
  bool _isSendingAlert = false;
  Timer? _holdTimer;

  // ── Double-press power button simulation ──
  int _powerPressCount = 0;
  DateTime? _lastPowerPress;
  static const _powerDoublePressWindowMs = 800;
  bool _powerSosBannerVisible = false;

  // ── Shake Detection ──
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime? _lastShakeTime;
  static const double _shakeThreshold = 25.0; // m/s² — tune if needed
  static const int _shakeCooldownMs = 3000;   // ignore re-triggers within 3s

  // ── Violent Shake Detection state ──
  bool _shakeBannerVisible = false;
  AudioRiskResult? _shakeRiskResult;
  bool _isProcessingShakeAudio = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _holdProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // ── Start real accelerometer shake detection ──
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((AccelerometerEvent event) {
      final double magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      // Subtract gravity (~9.8 m/s²) from magnitude to get pure acceleration
      final double accel = (magnitude - 9.8).abs();
      if (accel > _shakeThreshold) {
        final now = DateTime.now();
        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!).inMilliseconds > _shakeCooldownMs) {
          _lastShakeTime = now;
          _handleViolentShake();
        }
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _pulseController.dispose();
    _holdProgressController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }


  // ── Violent Mobile Shake Handler ──────────────────────────────────────────
  Future<void> _handleViolentShake() async {
    if (_isProcessingShakeAudio) return;
    setState(() {
      _isProcessingShakeAudio = true;
      _shakeBannerVisible = true;
    });

    // 1. Play warning chime
    WebAudioPlayer.playAlarmSiren();

    // 2. Record 5s real audio from device microphone
    final samples = await MicrophoneService.record5Seconds();

    // 3. Analyze via CNN Risk Model
    final riskResult = AudioRiskAnalyzer.analyze(samples);

    if (!mounted) return;

    setState(() {
      _isProcessingShakeAudio = false;
      _shakeRiskResult = riskResult;
    });

    // 4. Decision: if risk >= 50%, activate SOS countdown automatically
    if (riskResult.riskScore >= 0.50) {
      ref.read(sosProvider.notifier).startSosCountdown(
            triggerSource: 'violent_shake',
            seconds: 10,
          );
      _dispatchSosAlerts(triggeredBy: 'Violent Mobile Shake (CNN Risk ${riskResult.riskPercent}%)');
    }
  }

  // ── Double Power Button Handler ───────────────────────────────────────────
  void _handlePowerButtonSimulation() {
    final now = DateTime.now();
    if (_lastPowerPress != null &&
        now.difference(_lastPowerPress!).inMilliseconds <
            _powerDoublePressWindowMs) {
      _powerPressCount = 0;
      _lastPowerPress = null;
      _onSosTriggeredByPower();
    } else {
      _powerPressCount = 1;
      _lastPowerPress = now;
    }
  }

  Future<void> _onSosTriggeredByPower() async {
    setState(() => _powerSosBannerVisible = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _powerSosBannerVisible = false);
    });

    WebAudioPlayer.playAlarmSiren();
    ref.read(sosProvider.notifier).startSosCountdown(
          triggerSource: 'power_button',
          seconds: 10,
        );

    _dispatchSosAlerts(triggeredBy: 'Double-Press Power Button');
  }

  Future<void> _onSosTriggered() async {
    WebAudioPlayer.playAlarmSiren();
    ref.read(sosProvider.notifier).startSosCountdown(
          triggerSource: 'manual',
          seconds: 10,
        );

    _dispatchSosAlerts(triggeredBy: 'Manual SOS (Long-Press)');
  }

  Future<void> _dispatchSosAlerts({required String triggeredBy}) async {
    if (_isSendingAlert) return;
    setState(() => _isSendingAlert = true);

    final authState = ref.read(authProvider);
    final contacts = ref.read(contactsProvider);
    final locationState = ref.read(locationProvider);

    final emails = contacts
        .map((c) => c.email)
        .where((e) => e.contains('@'))
        .toList();

    final phones = contacts
        .map((c) => c.phone)
        .where((p) => p.isNotEmpty)
        .toList();

    final userName = authState.userProfile?.name ?? 'Aegis User';

    // 1. Auto-call priority-1 contact immediately
    if (contacts.isNotEmpty) {
      final priority1 = contacts.reduce(
          (a, b) => a.priority <= b.priority ? a : b);
      final callUri = Uri.parse('tel:${priority1.phone}');
      try {
        if (await canLaunchUrl(callUri)) {
          await launchUrl(callUri);
        }
      } catch (e) {
        debugPrint('Auto-call error: $e');
      }
    }

    // 2. Send Emergency Emails via Resend
    await ResendService.sendSosAlert(
      toEmails: emails.isEmpty
          ? [
              'likith824788@gmail.com',
              'sundreshan21@gmail.com',
              'saibharathchalla29@gmail.com',
              'priyajegan1222@gmail.com',
            ]
          : emails,
      userName: userName,
      latitude: locationState.currentLat,
      longitude: locationState.currentLng,
      triggeredBy: triggeredBy,
    );

    // 3. Send Emergency SMS via Twilio
    await TwilioService.sendSosSms(
      phoneNumbers: phones.isEmpty
          ? ['9100771523', '9025174327', '6382104870', '7569228039']
          : phones,
      userName: userName,
      latitude: locationState.currentLat,
      longitude: locationState.currentLng,
      triggeredBy: triggeredBy,
    );

    setState(() => _isSendingAlert = false);
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final authState = ref.watch(authProvider);
    final userName =
        authState.userProfile?.name?.split(' ').first ?? 'User';

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        // Web/desktop fallback: F8 = power button sim, Shift+S = shake sim
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f8) {
            _handlePowerButtonSimulation();
          } else if (event.logicalKey == LogicalKeyboardKey.keyS &&
              HardwareKeyboard.instance.isShiftPressed) {
            _handleViolentShake();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        drawer: AppDrawer(
          currentIndex: 0,
          onNavigate: widget.onNavigateTab,
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open navigation sidebar',
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Aegis Safety'),
            ],
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting & GPS Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, $userName 👋',
                              style: AppTypography.displayLarge),
                          const SizedBox(height: 4),
                          const Text(
                            'Stay protected wherever you go.',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                      StatusPill(
                        label: locationState.isGpsEnabled
                            ? 'GPS ACTIVE'
                            : 'GPS OFF',
                        type: locationState.isGpsEnabled
                            ? StatusPillType.safe
                            : StatusPillType.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── BIG RED SOS BUTTON WITH OUTER 1.5s LOADING RING ──
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'HOLD FOR 1.5 SECONDS FOR EMERGENCY SOS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sosRed,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onLongPressStart: (_) {
                            setState(() => _isLongPressing = true);
                            _holdProgressController.forward(from: 0.0);
                            _holdTimer =
                                Timer(const Duration(milliseconds: 1500), () {
                              _onSosTriggered();
                            });
                          },
                          onLongPressEnd: (_) {
                            _holdTimer?.cancel();
                            _holdProgressController.reset();
                            setState(() => _isLongPressing = false);
                          },
                          onLongPressCancel: () {
                            _holdTimer?.cancel();
                            _holdProgressController.reset();
                            setState(() => _isLongPressing = false);
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer loading progress ring
                              SizedBox(
                                width: 236,
                                height: 236,
                                child: AnimatedBuilder(
                                  animation: _holdProgressController,
                                  builder: (context, _) {
                                    return CircularProgressIndicator(
                                      value: _isLongPressing
                                          ? _holdProgressController.value
                                          : 0.0,
                                      strokeWidth: 6,
                                      color: AppColors.sosRed,
                                      backgroundColor:
                                          AppColors.sosRed.withOpacity(0.12),
                                    );
                                  },
                                ),
                              ),

                              // Big Red SOS Button
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final scale =
                                      1.0 + (_pulseController.value * 0.06);
                                  return Transform.scale(
                                    scale: _isLongPressing ? 1.10 : scale,
                                    child: Container(
                                      width: 210,
                                      height: 210,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const RadialGradient(
                                          colors: [
                                            Color(0xFFFF5252),
                                            Color(0xFFE8452C),
                                            Color(0xFFC0260E),
                                          ],
                                          stops: [0.3, 0.7, 1.0],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.sosRed.withOpacity(
                                                _isLongPressing ? 0.6 : 0.35),
                                            blurRadius:
                                                _isLongPressing ? 40 : 25,
                                            spreadRadius:
                                                _isLongPressing ? 10 : 5,
                                          ),
                                        ],
                                      ),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.emergency,
                                            size: 70,
                                            color: Colors.white,
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'SOS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 3.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Press & hold in case of immediate danger',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Quick Action Cards
                  const Text('Safety Tools', style: AppTypography.titleLarge),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _quickActionCard(
                          icon: Icons.navigation,
                          color: const Color(0xFF0284C7),
                          title: 'Companion Mode',
                          subtitle: 'Live trip monitoring',
                          onTap: () => widget.onNavigateTab(2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _quickActionCard(
                          icon: Icons.share_location,
                          color: AppColors.safeGreen,
                          title: 'Live Share',
                          subtitle: 'Broadcast GPS',
                          onTap: () => widget.onNavigateTab(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _quickActionCard(
                          icon: Icons.psychology,
                          color: AppColors.primaryNavy,
                          title: 'AI Check-in',
                          subtitle: 'Threat detection',
                          onTap: () => widget.onNavigateTab(3),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _quickActionCard(
                          icon: Icons.local_police,
                          color: const Color(0xFF475569),
                          title: 'Nearby Services',
                          subtitle: 'Police & Hospitals',
                          onTap: () => widget.onNavigateTab(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Top Push-Style Power SOS Notification Banner ──
            if (_powerSosBannerVisible)
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.sosRed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active,
                            color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🚨 POWER BUTTON SOS ACTIVATED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Emergency alert broadcasted. Recording 5s audio.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () =>
                              setState(() => _powerSosBannerVisible = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Top Push-Style Violent Shake "Are You Safe?" Interactive Banner ──
            if (_shakeBannerVisible)
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFB45309),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vibration,
                                color: Colors.white, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isProcessingShakeAudio
                                    ? '🎙️ VIOLENT SHAKE DETECTED — Recording 5s Audio...'
                                    : '🚨 VIOLENT SHAKE DETECTED — Are you safe?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 20),
                              onPressed: () =>
                                  setState(() => _shakeBannerVisible = false),
                            ),
                          ],
                        ),
                        if (_shakeRiskResult != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'CNN Risk Prediction: ${_shakeRiskResult!.riskPercent}% • Level: ${_shakeRiskResult!.dangerLevel}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryNavy,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  setState(() => _shakeBannerVisible = false);
                                  widget.onNavigateTab(3); // Open AI Chat
                                },
                                icon: const Icon(Icons.psychology, size: 18),
                                label: const Text('Talk to AI',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Colors.white, width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  final valid =
                                      await PinVerificationDialog.verify(
                                    context: context,
                                    actionTitle: 'Confirm You Are Safe',
                                  );
                                  if (valid && mounted) {
                                    setState(
                                        () => _shakeBannerVisible = false);
                                  }
                                },
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text("I'm Safe (PIN)",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
