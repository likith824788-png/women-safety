import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/primary_button.dart';

class GpsOffModal extends ConsumerWidget {
  const GpsOffModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final contacts = ref.watch(contactsProvider);

    return PopScope(
      canPop: false, // BLOCKING MODAL — NO DISMISS WITHOUT ACTION
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sosRed.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.sosRedBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off,
                      color: AppColors.sosRed,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Location Services Disabled!',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'System LocationManager reported GPS turned off. Active safety tracking is currently suspended.',
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // GUARDIAN LAST KNOWN LOCATION SENT SUMMARY
                  AppCard(
                    backgroundColor: AppColors.surfaceVariant,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Known Location Broadcasted:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${locationState.locationAddress} (${locationState.lastPingTime?.hour}:${locationState.lastPingTime?.minute.toString().padLeft(2, '0')})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Divider(height: 16),
                        Text(
                          'Recipients notified: ${contacts.map((c) => c.name).join(", ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SINGLE PRIMARY ACTION: TURN LOCATION BACK ON
                  PrimaryButton(
                    label: 'Turn Location Back On',
                    icon: Icons.location_on,
                    onPressed: () {
                      ref.read(locationProvider.notifier).toggleGps(true);
                    },
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
