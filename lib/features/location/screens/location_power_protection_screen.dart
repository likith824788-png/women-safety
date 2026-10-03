import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';

class LocationPowerProtectionScreen extends ConsumerWidget {
  const LocationPowerProtectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Location & Power Protection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Warning Notice
            AppCard(
              backgroundColor: AppColors.secondaryNavy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.battery_charging_full, color: AppColors.safeGreen, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Power-Off Telemetry Safeguard',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'If your device is powered off or loses battery during an active trip, your designated guardians immediately see your last synced GPS position (${locationState.locationAddress}) and exact timestamp.',
                    style: const TextStyle(fontSize: 14, color: AppColors.textDimmed, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BACKGROUND SYNC CONTROLS
            const Text(
              'Background Service Settings',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 12),

            AppCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.sync_lock, color: AppColors.primaryNavy),
                    title: const Text(
                      'WorkManager Background Sync',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Periodic background location pings every 15 minutes when app is closed.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    value: locationState.isGpsEnabled,
                    onChanged: (val) {
                      ref.read(locationProvider.notifier).toggleGps(val);
                    },
                  ),
                  const Divider(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: AppColors.primaryNavy),
                    title: const Text('Last Synced Ping'),
                    subtitle: Text(
                      locationState.lastPingTime != null
                          ? '${locationState.lastPingTime!.hour}:${locationState.lastPingTime!.minute.toString().padLeft(2, '0')} (${locationState.currentLat.toStringAsFixed(4)}, ${locationState.currentLng.toStringAsFixed(4)})'
                          : 'No ping recorded',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BATTERY IMPACT DOCUMENTATION
            const Text(
              'Battery Optimization Notice',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 12),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryNavy, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Expected Battery Impact: < 3% per 24 hours',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We utilize Android WorkManager and Android Foreground Location Service instead of infinite wake-lock loops. On OEM skins (Samsung, Xiaomi, OnePlus), disable battery optimization for Aegis Safety to guarantee high-priority background delivery.',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
