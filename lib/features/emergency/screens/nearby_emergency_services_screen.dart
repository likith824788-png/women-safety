import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';

class NearbyEmergencyServicesScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;

  const NearbyEmergencyServicesScreen({
    super.key,
    this.onBack,
    this.onNavigate,
  });

  @override
  ConsumerState<NearbyEmergencyServicesScreen> createState() =>
      _NearbyEmergencyServicesScreenState();
}

class _NearbyEmergencyServicesScreenState
    extends ConsumerState<NearbyEmergencyServicesScreen> {
  static String get _mapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  int _selectedCategory = 0; // 0 = Police, 1 = Hospital
  final MapController _mapController = MapController();

  Map<String, dynamic>? _selectedPlace;
  List<LatLng> _routePolyline = [];
  bool _isFetchingRoute = false;

  final List<Map<String, dynamic>> _policeServices = [
    {
      'name': 'Police Emergency Control Room',
      'address': 'Dial 100 — Nearest Police Station',
      'distance': 'Call Now',
      'phone': '100',
      'lat': 12.9716,
      'lng': 77.5946,
    },
    {
      'name': 'Women Helpline',
      'address': 'National Emergency Helpline for Women',
      'distance': 'Call Now',
      'phone': '1091',
      'lat': 12.9730,
      'lng': 77.5960,
    },
    {
      'name': 'Likith (Primary Contact)',
      'address': 'Trusted Contact — Emergency Alert',
      'distance': 'Trusted Contact',
      'phone': '+919100771523',
      'lat': 12.9720,
      'lng': 77.5950,
    },
    {
      'name': 'Sundreshan (Trusted Friend)',
      'address': 'Trusted Contact — Emergency Alert',
      'distance': 'Trusted Contact',
      'phone': '+919025174327',
      'lat': 12.9750,
      'lng': 77.5965,
    },
  ];

  final List<Map<String, dynamic>> _hospitals = [
    {
      'name': 'Ambulance Emergency',
      'address': 'Dial 108 — National Ambulance Service',
      'distance': 'Call Now',
      'phone': '108',
      'lat': 12.9710,
      'lng': 77.5930,
    },
    {
      'name': 'Disaster Management',
      'address': 'National Disaster Response — Dial 112',
      'distance': 'Call Now',
      'phone': '112',
      'lat': 12.9690,
      'lng': 77.5910,
    },
    {
      'name': 'Sai Bharath (Trusted Friend)',
      'address': 'Trusted Contact — Emergency Alert',
      'distance': 'Trusted Contact',
      'phone': '+916382104870',
      'lat': 12.9700,
      'lng': 77.5920,
    },
    {
      'name': 'Priya Jegan (Trusted Friend)',
      'address': 'Trusted Contact — Emergency Alert',
      'distance': 'Trusted Contact',
      'phone': '+917569228039',
      'lat': 12.9680,
      'lng': 77.5900,
    },
  ];


  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // ── Calculate Directions Route to Selected Place ────────────────────────────
  Future<void> _showRouteToPlace(Map<String, dynamic> place) async {
    final currentLoc = ref.read(locationProvider).currentLocation;
    final destLat = place['lat'] as double;
    final destLng = place['lng'] as double;

    setState(() {
      _selectedPlace = place;
      _isFetchingRoute = true;
      _routePolyline.clear();
    });

    try {
      final dirUrl = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/${currentLoc.longitude},${currentLoc.latitude};$destLng,$destLat?geometries=geojson&overview=full&access_token=$_mapboxToken');
      final dirRes = await http.get(dirUrl);

      if (dirRes.statusCode == 200) {
        final dirData = jsonDecode(dirRes.body);
        final routes = dirData['routes'] as List;
        if (routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List;
          _routePolyline = coords
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingRoute = false);
        try {
          _mapController.move(LatLng(destLat, destLng), 14);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLoc = ref.watch(locationProvider).currentLocation;
    final currentList =
        _selectedCategory == 0 ? _policeServices : _hospitals;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: widget.onNavigate != null
          ? AppDrawer(currentIndex: 4, onNavigate: widget.onNavigate!)
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
        title: const Text('Nearby Emergency Services'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Live Map Header showing Current Location & Directions Polyline ──
            Container(
              height: 220,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: currentLoc,
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                        userAgentPackageName: 'com.aegissafety.app',
                      ),

                      // Polyline route to selected emergency place
                      if (_routePolyline.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePolyline,
                              color: _selectedCategory == 0
                                  ? AppColors.primaryNavy
                                  : AppColors.sosRed,
                              strokeWidth: 4.5,
                            ),
                          ],
                        ),

                      // Markers Layer
                      MarkerLayer(
                        markers: [
                          // Live user GPS location marker
                          Marker(
                            point: currentLoc,
                            width: 44,
                            height: 44,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryNavy,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),

                          // Emergency places markers
                          ...currentList.map((place) {
                            final isSelected =
                                _selectedPlace?['name'] == place['name'];
                            return Marker(
                              point: LatLng(place['lat'], place['lng']),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => _showRouteToPlace(place),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.sosRed
                                        : _selectedCategory == 0
                                            ? AppColors.secondaryNavy
                                            : AppColors.safeGreen,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white, width: 2)
                                        : null,
                                  ),
                                  child: Icon(
                                    _selectedCategory == 0
                                        ? Icons.local_police
                                        : Icons.local_hospital,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),

                  if (_isFetchingRoute)
                    Container(
                      color: Colors.black12,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector Tabs
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedCategory == 0
                          ? AppColors.primaryNavy
                          : Colors.white,
                      foregroundColor: _selectedCategory == 0
                          ? Colors.white
                          : AppColors.primaryNavy,
                      side: BorderSide(
                        color: _selectedCategory == 0
                            ? AppColors.primaryNavy
                            : AppColors.borderLight,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 0;
                        _selectedPlace = null;
                        _routePolyline.clear();
                      });
                    },
                    icon: Icon(
                      Icons.local_police,
                      color: _selectedCategory == 0
                          ? Colors.white
                          : AppColors.primaryNavy,
                    ),
                    label: const Text('Police Stations'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedCategory == 1
                          ? AppColors.primaryNavy
                          : Colors.white,
                      foregroundColor: _selectedCategory == 1
                          ? Colors.white
                          : AppColors.primaryNavy,
                      side: BorderSide(
                        color: _selectedCategory == 1
                            ? AppColors.primaryNavy
                            : AppColors.borderLight,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 1;
                        _selectedPlace = null;
                        _routePolyline.clear();
                      });
                    },
                    icon: Icon(
                      Icons.local_hospital,
                      color: _selectedCategory == 1
                          ? Colors.white
                          : AppColors.primaryNavy,
                    ),
                    label: const Text('Hospitals'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Service List
            Text(
              'Nearest Verified Services (${currentList.length})',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 12),

            ...currentList.map((place) {
              final isSelected = _selectedPlace?['name'] == place['name'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: AppCard(
                  border: isSelected
                      ? Border.all(color: AppColors.primaryNavy, width: 2)
                      : null,
                  backgroundColor:
                      isSelected ? const Color(0xFFF0F7FF) : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryNavy.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedCategory == 0
                                  ? Icons.local_police
                                  : Icons.local_hospital,
                              color: AppColors.primaryNavy,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  place['address'],
                                  style: AppTypography.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              place['distance'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          // 1-TAP CALL BUTTON
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.safeGreen,
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: () => _makeCall(place['phone']),
                              icon: const Icon(Icons.phone, size: 18),
                              label: const Text('1-Tap Call',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // SHOW DIRECTIONS ON MAP BUTTON
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                side: const BorderSide(
                                    color: AppColors.primaryNavy),
                                backgroundColor: isSelected
                                    ? AppColors.primaryNavy
                                    : Colors.white,
                                foregroundColor: isSelected
                                    ? Colors.white
                                    : AppColors.primaryNavy,
                              ),
                              onPressed: () => _showRouteToPlace(place),
                              icon: Icon(
                                Icons.directions,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryNavy,
                              ),
                              label: Text(
                                isSelected ? 'Showing Route' : 'Directions',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
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
