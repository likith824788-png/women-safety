import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/providers/shared_tracking_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';

class MonitorScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;

  const MonitorScreen({
    super.key,
    this.onBack,
    this.onNavigate,
  });

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> {
  static String get _mapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  final MapController _mapController = MapController();
  CompanionTracking? _selectedTracking;

  @override
  Widget build(BuildContext context) {
    final trackings = ref.watch(sharedTrackingProvider);

    // If selected tracking is null but list has elements, pick first
    final active = _selectedTracking ?? (trackings.isNotEmpty ? trackings.first : null);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: widget.onNavigate != null
          ? AppDrawer(currentIndex: 7, onNavigate: widget.onNavigate!)
          : null,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Open navigation sidebar',
          ),
        ),
        title: const Text('Live Location Monitor'),
      ),

      body: trackings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Shared Live Trackings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When contacts share their journey or live location with you, their live route and telemetry will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (active != null) ...[
                    // ── Map Header ──
                    Container(
                      height: 250,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: active.currentPosition,
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                            userAgentPackageName: 'com.aegissafety.app',
                          ),
                          MarkerLayer(
                            markers: [
                              // Current position marker
                              Marker(
                                point: active.currentPosition,
                                width: 50,
                                height: 50,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: active.isDeviated
                                            ? AppColors.sosRed
                                            : AppColors.primaryNavy,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person_pin_circle,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Destination marker
                              Marker(
                                point: active.destinationPosition,
                                width: 40,
                                height: 40,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.safeGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Active Monitored Banner
                    AppCard(
                      backgroundColor: active.isDeviated
                          ? AppColors.sosRedBg
                          : active.isActive
                              ? AppColors.primaryNavy
                              : const Color(0xFF475569),
                      border: active.isDeviated
                          ? Border.all(color: AppColors.sosRed, width: 1.5)
                          : null,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Text(
                              active.userName.isNotEmpty
                                  ? active.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      active.userName,
                                      style: TextStyle(
                                        color: active.isDeviated
                                            ? AppColors.sosRed
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: active.isDeviated
                                            ? AppColors.sosRed
                                            : active.isActive
                                                ? AppColors.safeGreen
                                                : Colors.grey,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        active.isDeviated
                                            ? 'SUSPICIOUS DEVIATION'
                                            : active.isActive
                                                ? 'LIVE TRACKING'
                                                : 'ENDED',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Destination: ${active.destination}\n${active.etaLabel ?? "In transit"} • ${active.distanceRemainingKm?.toStringAsFixed(1) ?? "--"} km remaining',
                                  style: TextStyle(
                                    color: active.isDeviated
                                        ? AppColors.textDark
                                        : Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── Shared Links List ───
                  const Text('Active Shared Trackings', style: AppTypography.titleLarge),
                  const SizedBox(height: 12),

                  ...trackings.map((tracking) {
                    final isSelected = active?.id == tracking.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryNavy
                              : AppColors.borderLight,
                          width: isSelected ? 2 : 1,
                        ),
                        backgroundColor:
                            isSelected ? const Color(0xFFF0F7FF) : Colors.white,
                        child: Row(
                          children: [
                            Icon(
                              tracking.isDeviated
                                  ? Icons.warning_amber
                                  : tracking.isActive
                                      ? Icons.location_on
                                      : Icons.location_off,
                              color: tracking.isDeviated
                                  ? AppColors.sosRed
                                  : tracking.isActive
                                      ? AppColors.safeGreen
                                      : AppColors.textMuted,
                              size: 24,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Journey: ${tracking.destination}',
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'User: ${tracking.userName} • Started ${tracking.durationLabel}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? AppColors.primaryNavy
                                    : AppColors.secondaryNavy,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedTracking = tracking;
                                });
                                try {
                                  _mapController.move(tracking.currentPosition, 14);
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.map,
                                  size: 16, color: Colors.white),
                              label: const Text('Open Map',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
