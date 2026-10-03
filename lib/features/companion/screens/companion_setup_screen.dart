import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/providers/shared_tracking_provider.dart';
import '../../../core/services/resend_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/pin_verification_dialog.dart';
import '../../../shared/widgets/primary_button.dart';

class CompanionSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;
  final String? prefilledDestination;

  const CompanionSetupScreen({
    super.key,
    this.onBack,
    this.onNavigate,
    this.prefilledDestination,
  });

  @override
  ConsumerState<CompanionSetupScreen> createState() =>
      _CompanionSetupScreenState();
}


class _CompanionSetupScreenState
    extends ConsumerState<CompanionSetupScreen> {
  static String get _mapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  final MapController _mapController = MapController();
  final TextEditingController _destinationCtrl = TextEditingController();

  final Set<String> _selectedContactIds = {};
  bool _isCalculatingRoute = false;
  bool _sessionActive = false;
  String? _trackingId;

  // Directions & route data
  List<LatLng> _routePolyline = [];
  LatLng? _destinationPoint;
  double? _routeDistanceKm;
  double? _routeDurationMins;
  String? _travelInfoText;

  // Live journey simulation & deviation state
  Timer? _journeyTimer;
  int _currentStepIndex = 0;
  bool _isDeviated = false;
  DateTime? _deviationStartTime;
  bool _deviationEmailSent = false;
  bool _escalationSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(locationProvider.notifier).fetchCurrentGpsLocation();
      final currentLoc = ref.read(locationProvider).currentLocation;
      try {
        _mapController.move(currentLoc, 14);
      } catch (_) {}

      if (widget.prefilledDestination != null &&
          widget.prefilledDestination!.isNotEmpty) {
        _destinationCtrl.text = widget.prefilledDestination!;
        _calculateRoute();
      }
    });
  }


  @override
  void dispose() {

    _destinationCtrl.dispose();
    _journeyTimer?.cancel();
    super.dispose();
  }

  // ── Mapbox Geocoding + Directions ──────────────────────────────────────────
  Future<void> _calculateRoute() async {
    final query = _destinationCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isCalculatingRoute = true;
      _routePolyline.clear();
      _destinationPoint = null;
      _travelInfoText = null;
    });

    final currentLoc = ref.read(locationProvider).currentLocation;
    final startLat = currentLoc.latitude;
    final startLng = currentLoc.longitude;

    try {
      // 1. Geocode destination query
      final geocodeUrl = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$_mapboxToken&limit=1');
      final geoRes = await http.get(geocodeUrl);

      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final features = geoData['features'] as List;
        if (features.isNotEmpty) {
          final center = features[0]['center'];
          final destLng = (center[0] as num).toDouble();
          final destLat = (center[1] as num).toDouble();
          _destinationPoint = LatLng(destLat, destLng);

          // 2. Mapbox Directions API for driving route
          final dirUrl = Uri.parse(
              'https://api.mapbox.com/directions/v5/mapbox/driving/$startLng,$startLat;$destLng,$destLat?geometries=geojson&overview=full&access_token=$_mapboxToken');
          final dirRes = await http.get(dirUrl);

          if (dirRes.statusCode == 200) {
            final dirData = jsonDecode(dirRes.body);
            final routes = dirData['routes'] as List;
            if (routes.isNotEmpty) {
              final route = routes[0];
              final distanceMeters = (route['distance'] as num).toDouble();
              final durationSeconds = (route['duration'] as num).toDouble();

              _routeDistanceKm = distanceMeters / 1000.0;
              _routeDurationMins = durationSeconds / 60.0;

              // Format duration into hours and minutes
              final hours = _routeDurationMins! ~/ 60;
              final mins = (_routeDurationMins! % 60).round();
              final durationStr = hours > 0
                  ? '${hours}h ${mins}m'
                  : '${mins} mins';

              _travelInfoText =
                  '${_routeDistanceKm!.toStringAsFixed(1)} km • Estimated $durationStr';

              // Extract polyline geometry
              final coords = route['geometry']['coordinates'] as List;
              _routePolyline = coords
                  .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                  .toList();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Mapbox route: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
        if (_destinationPoint != null) {
          try {
            _mapController.move(currentLoc, 13);
          } catch (_) {}
        }
      }
    }
  }

  // ── Start Trip ────────────────────────────────────────────────────────────
  Future<void> _startTrip() async {
    final contacts = ref.read(contactsProvider);
    final selected =
        contacts.where((c) => _selectedContactIds.contains(c.id)).toList();

    final pinValid = await PinVerificationDialog.verify(
      context: context,
      actionTitle: 'Start Companion Journey',
    );
    if (!pinValid) return;

    final currentLoc = ref.read(locationProvider).currentLocation;
    final destPoint = _destinationPoint ?? LatLng(12.9716, 77.5946);

    final authState = ref.read(authProvider);
    final realName = authState.userProfile?.name ?? 'Aegis User';
    final realPhone = authState.userProfile?.phone ?? '';

    _trackingId = 'track_${DateTime.now().millisecondsSinceEpoch}';

    final newTracking = CompanionTracking(
      id: _trackingId!,
      userName: realName,
      userPhone: realPhone,
      destination: _destinationCtrl.text.trim(),
      currentPosition: currentLoc,
      destinationPosition: destPoint,
      startedAt: DateTime.now(),
      distanceRemainingKm: _routeDistanceKm ?? 5.2,
      etaLabel: _travelInfoText != null
          ? _travelInfoText!.split('•').last.trim()
          : '25 mins',
      isActive: true,
    );

    // Broadcast tracking to receiver's Monitor page
    ref.read(sharedTrackingProvider.notifier).addTracking(newTracking);

    // Send notification emails to selected guardians
    final emails = selected.map((c) => c.email).where((e) => e.isNotEmpty).toList();
    if (emails.isNotEmpty) {
      ResendService.sendLiveLocationEmail(
        toEmails: emails,
        userName: realName,
        latitude: currentLoc.latitude,
        longitude: currentLoc.longitude,
        durationMinutes: 60,
      );
    }

    setState(() {
      _sessionActive = true;
      _currentStepIndex = 0;
      _isDeviated = false;
      _deviationStartTime = null;
      _deviationEmailSent = false;
      _escalationSent = false;
    });

    // Start live tracking loop (simulating journey movement & route checks)
    _startJourneyTrackingLoop();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🗺️ Companion trip started! Live tracking shared to Monitor page & ${selected.length} guardian(s).',
          ),
          backgroundColor: AppColors.safeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Journey Loop & Deviation Detection ────────────────────────────────────
  void _startJourneyTrackingLoop() {
    _journeyTimer?.cancel();
    _journeyTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_sessionActive || _trackingId == null) {
        timer.cancel();
        return;
      }

      final trackings = ref.read(sharedTrackingProvider);
      final index = trackings.indexWhere((t) => t.id == _trackingId);
      if (index == -1) return;
      final currentTracking = trackings[index];

      // Simulate step movement along polyline
      LatLng nextPos;
      if (_routePolyline.isNotEmpty && _currentStepIndex < _routePolyline.length) {
        nextPos = _routePolyline[_currentStepIndex];
        _currentStepIndex++;
      } else {
        nextPos = currentTracking.currentPosition;
      }

      // Calculate remaining distance
      final remainingKm = _routeDistanceKm != null && _routePolyline.isNotEmpty
          ? (_routePolyline.length - _currentStepIndex) *
              (_routeDistanceKm! / math.max(1, _routePolyline.length))
          : 3.5;

      // Check deviation condition (if step > 8, simulate a deviation off-route for demo testing)
      bool deviated = _isDeviated;
      if (_currentStepIndex > 6 && !deviated) {
        deviated = true;
        _deviationStartTime = DateTime.now();

        // Trigger deviation email alert to selected contacts
        if (!_deviationEmailSent) {
          _deviationEmailSent = true;
          final contacts = ref.read(contactsProvider);
          final emails = contacts
              .where((c) => _selectedContactIds.contains(c.id))
              .map((c) => c.email)
              .where((e) => e.isNotEmpty)
              .toList();

          ResendService.sendDeviationAlert(
            toEmails: emails,
            userName: 'User Demo',
            destination: _destinationCtrl.text,
            latitude: nextPos.latitude,
            longitude: nextPos.longitude,
            deviationMeters: 450,
          );
        }
      }

      // Check 30-minute escalation rule
      if (deviated && _deviationStartTime != null && !_escalationSent) {
        final offMins = DateTime.now().difference(_deviationStartTime!).inMinutes;
        // Escalation threshold (using 30 mins, or instant demo threshold)
        if (offMins >= 30) {
          _escalationSent = true;
          final contacts = ref.read(contactsProvider);
          final emails = contacts
              .where((c) => _selectedContactIds.contains(c.id))
              .map((c) => c.email)
              .where((e) => e.isNotEmpty)
              .toList();

          ResendService.sendEscalationAlert(
            toEmails: emails,
            userName: 'User Demo',
            destination: _destinationCtrl.text,
            latitude: nextPos.latitude,
            longitude: nextPos.longitude,
            minutesDeviated: offMins,
          );
        }
      }

      final updated = currentTracking.copyWith(
        currentPosition: nextPos,
        distanceRemainingKm: math.max(0.0, remainingKm),
        etaLabel: '${(remainingKm * 5).round()} mins remaining',
        isDeviated: deviated,
        deviationStartedAt: _deviationStartTime,
      );

      ref.read(sharedTrackingProvider.notifier).updateTracking(_trackingId!, updated);

      if (mounted) {
        setState(() {
          _isDeviated = deviated;
        });
      }
    });
  }

  // ── End Trip ──────────────────────────────────────────────────────────────
  Future<void> _endTrip() async {
    final pinValid = await PinVerificationDialog.verify(
      context: context,
      actionTitle: 'End Companion Trip',
    );
    if (!pinValid) return;

    _journeyTimer?.cancel();
    if (_trackingId != null) {
      ref.read(sharedTrackingProvider.notifier).endTracking(_trackingId!);
    }

    setState(() {
      _sessionActive = false;
      _isDeviated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final currentLoc = ref.watch(locationProvider).currentLocation;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: widget.onNavigate != null
          ? AppDrawer(currentIndex: 2, onNavigate: widget.onNavigate!)
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
        title: const Text('Companion Mode'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            AppCard(
              backgroundColor: AppColors.primaryNavy,
              child: const Row(
                children: [
                  Icon(Icons.navigation, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enter your destination to compute route directions and share live tracking with guardians in real-time.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Small Live Map Preview ────────────────────────────────────────
            Container(
              height: 200,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDeviated ? AppColors.sosRed : AppColors.borderLight,
                  width: _isDeviated ? 2 : 1,
                ),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLoc,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                    userAgentPackageName: 'com.aegissafety.app',
                  ),

                  // Polyline Route
                  if (_routePolyline.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePolyline,
                          color: _isDeviated
                              ? AppColors.sosRed
                              : AppColors.primaryNavy,
                          strokeWidth: 4.5,
                        ),
                      ],
                    ),

                  // Markers Layer
                  MarkerLayer(
                    markers: [
                      // Current Location Marker
                      Marker(
                        point: currentLoc,
                        width: 40,
                        height: 40,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isDeviated
                                ? AppColors.sosRed
                                : AppColors.primaryNavy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Destination Marker
                      if (_destinationPoint != null)
                        Marker(
                          point: _destinationPoint!,
                          width: 40,
                          height: 40,
                          child: Container(
                            padding: const EdgeInsets.all(6),
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
            const SizedBox(height: 20),

            // ── Deviation Alert Banner ──
            if (_isDeviated) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sosRedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sosRed, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.sosRed, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '⚠️ Suspicious Route Deviation Detected!\nAlert email dispatched to trusted contacts. Escalation in 30 mins.',
                        style: TextStyle(
                          color: AppColors.sosRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Destination Input ───
            const Text('Destination', style: AppTypography.titleLarge),
            const SizedBox(height: 10),

            TextFormField(
              controller: _destinationCtrl,
              decoration: InputDecoration(
                hintText: 'Enter destination (e.g., MG Road, Bangalore)',
                prefixIcon:
                    const Icon(Icons.place, color: AppColors.primaryNavy),
                suffixIcon: _isCalculatingRoute
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _calculateRoute,
                      ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
              onFieldSubmitted: (_) => _calculateRoute(),
            ),

            // Travel Info Badge
            if (_travelInfoText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car,
                        color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _travelInfoText!,
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ─── Trip Guardians (Sharing Recipients) ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trip Guardians', style: AppTypography.titleLarge),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedContactIds.length == contacts.length) {
                        _selectedContactIds.clear();
                      } else {
                        _selectedContactIds.addAll(contacts.map((c) => c.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedContactIds.length == contacts.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...contacts.map((c) => _contactTile(c)),

            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No trusted contacts added.\nAdd contacts in Trusted Contacts screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ─── Start / End Journey Button ───
            if (!_sessionActive)
              PrimaryButton(
                label: 'Start Companion Journey',
                icon: Icons.navigation,
                onPressed:
                    _destinationCtrl.text.isEmpty ? null : _startTrip,
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.safeGreen),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.safeGreen, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Journey Active — heading to "${_destinationCtrl.text}"\nStreaming live tracking to Monitor page.',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.safeGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sosRed),
                        onPressed: _endTrip,
                        child: const Text('End Journey',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(TrustedContact contact) {
    final isSelected = _selectedContactIds.contains(contact.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedContactIds.remove(contact.id);
            } else {
              _selectedContactIds.add(contact.id);
            }
          });
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryNavy,
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('${contact.relationship} • ${contact.phone}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            Checkbox(
              value: isSelected,
              activeColor: AppColors.primaryNavy,
              onChanged: (_) {
                setState(() {
                  if (isSelected) {
                    _selectedContactIds.remove(contact.id);
                  } else {
                    _selectedContactIds.add(contact.id);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
