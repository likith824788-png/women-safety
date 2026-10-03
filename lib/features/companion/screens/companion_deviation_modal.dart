import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/companion_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/countdown_ring.dart';
import '../../../shared/widgets/danger_button.dart';

class CompanionDeviationModal extends ConsumerStatefulWidget {
  const CompanionDeviationModal({super.key});

  @override
  ConsumerState<CompanionDeviationModal> createState() =>
      _CompanionDeviationModalState();
}

class _CompanionDeviationModalState
    extends ConsumerState<CompanionDeviationModal> {
  int _secondsRemaining = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining -= 1;
        });
      } else {
        _timer?.cancel();
        // Auto-escalate to SOS alert on timeout
        ref.read(companionProvider.notifier).escalateDeviationToSos();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.85),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.warningOrangeBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.alt_route,
                      color: AppColors.warningOrange,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Route Deviation / Delay Detected!',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your GPS location moved >250m off your planned route. Are you okay?',
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // COUNTDOWN RING
                  CountdownRing(
                    secondsRemaining: _secondsRemaining,
                    totalSeconds: 15,
                    size: 160,
                  ),
                  const SizedBox(height: 24),

                  // ACTIONS
                  DangerButton(
                    label: 'SEND SOS NOW',
                    icon: Icons.warning_amber_rounded,
                    onPressed: () {
                      _timer?.cancel();
                      ref.read(companionProvider.notifier).escalateDeviationToSos();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderLight, width: 2),
                      ),
                      onPressed: () {
                        _timer?.cancel();
                        ref.read(companionProvider.notifier).dismissDeviationAndContinue();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "I'm Okay — Continue Trip",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
