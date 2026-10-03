import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/companion_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/map_preview_card.dart';
import '../../../shared/widgets/primary_button.dart';

class CompanionTrackingScreen extends ConsumerWidget {
  final VoidCallback onOpenDeviationModal;

  const CompanionTrackingScreen({
    super.key,
    required this.onOpenDeviationModal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companionState = ref.watch(companionProvider);
    final trip = companionState.activeTrip;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Active Companion Tracking'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GUARDIAN WATCHING BANNER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility, color: Color(0xFF0284C7), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Guardians Are Watching',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        Text(
                          'Live telemetry & route polyline connected.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ROUTE MAP PREVIEW
            MapPreviewCard(
              height: 240,
              title: trip?.destination ?? '742 Evergreen Terrace',
              subtitle: 'Monitored Route • ${companionState.minutesRemaining} mins remaining',
            ),
            const SizedBox(height: 20),

            // TRIP DETAILS CARD
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'ETA REMAINING',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${companionState.minutesRemaining} min',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 40, width: 1, color: AppColors.borderLight),
                  Column(
                    children: [
                      const Text(
                        'ROUTE STATUS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companionState.status == CompanionTripStatus.deviated
                            ? 'DEVIATED'
                            : 'ON ROUTE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: companionState.status == CompanionTripStatus.deviated
                              ? AppColors.sosRed
                              : AppColors.safeGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DEMO DEVIATION SIMULATOR TRIGGER BUTTON
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warningOrange,
                  side: const BorderSide(color: AppColors.warningOrange),
                ),
                onPressed: () {
                  ref.read(companionProvider.notifier).simulateRouteDeviation();
                  onOpenDeviationModal();
                },
                icon: const Icon(Icons.alt_route),
                label: const Text('Simulate Route Deviation Alert'),
              ),
            ),
            const SizedBox(height: 24),

            // ARRIVED / END TRIP BUTTON
            PrimaryButton(
              label: "I've Arrived — End Monitored Trip",
              icon: Icons.check_circle_outline,
              onPressed: () {
                ref.read(companionProvider.notifier).completeTrip();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
