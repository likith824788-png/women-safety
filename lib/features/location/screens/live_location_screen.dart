import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/services/resend_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/pin_verification_dialog.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/status_pill.dart';

class LiveLocationScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;

  const LiveLocationScreen({super.key, this.onBack, this.onNavigate});

  @override
  ConsumerState<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends ConsumerState<LiveLocationScreen> {
  static String get _mapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  // 3 options: 30m, 60m, -1 = until stopped
  int _selectedDuration = 60;
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(12.9716, 77.5946);
  StreamSubscription<Position>? _positionSub;
  bool _isSendingLink = false;
  Timer? _locationEmailTimer;  // periodic live location update emails

  // Contact selection
  final Set<String> _selectedContactIds = {};

  @override
  void initState() {
    super.initState();
    _startLocationTracking();

    // Pre-select all contacts by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contacts = ref.read(contactsProvider);
      setState(() {
        _selectedContactIds.addAll(contacts.map((c) => c.id));
      });
    });
  }

  void _startLocationTracking() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
        try {
          _mapController.move(_currentPosition, 15);
        } catch (_) {}
        ref.read(locationProvider.notifier).updateLocation(
              pos.latitude,
              pos.longitude,
              'Current GPS Location',
            );
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _locationEmailTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSharingAndSendLink() async {
    final pinValid = await PinVerificationDialog.verify(
      context: context,
      actionTitle: 'Start Live Location Sharing',
    );
    if (!pinValid) return;

    final contacts = ref.read(contactsProvider);
    final authState = ref.read(authProvider);

    final selectedContacts = contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    // Start location sharing
    ref.read(locationProvider.notifier).startLiveSharing(
          durationMinutes: _selectedDuration,
          recipients: _selectedContactIds.toList(),
        );

    // Send email link via Resend
    setState(() => _isSendingLink = true);

    // FIX: was incorrectly using c.phone.contains('@') — now uses c.email
    final emails = selectedContacts
        .where((c) => c.email.isNotEmpty && c.email.contains('@'))
        .map((c) => c.email)
        .toList();

    // Always fallback to hardcoded emails if contact emails missing
    final toEmails = emails.isNotEmpty
        ? emails
        : [
            'likith824788@gmail.com',
            'sundreshan21@gmail.com',
            'saibharathchalla29@gmail.com',
            'priyajegan1222@gmail.com',
          ];

    final userName = authState.userProfile?.name ?? 'Aegis User';

    await ResendService.sendLiveLocationEmail(
      toEmails: toEmails,
      userName: userName,
      latitude: _currentPosition.latitude,
      longitude: _currentPosition.longitude,
      durationMinutes: _selectedDuration,
    );

    // Start periodic location update emails every 10 minutes
    _locationEmailTimer?.cancel();
    _locationEmailTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) async {
        final loc = ref.read(locationProvider);
        await ResendService.sendLiveLocationEmail(
          toEmails: toEmails,
          userName: userName,
          latitude: loc.currentLat,
          longitude: loc.currentLng,
          durationMinutes: _selectedDuration,
        );
      },
    );

    setState(() => _isSendingLink = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📧 Live location sent to ${toEmails.length} contact(s)! Updates every 10 min.',
          ),
          backgroundColor: AppColors.safeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: widget.onNavigate != null
          ? AppDrawer(currentIndex: 1, onNavigate: widget.onNavigate!)
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
        title: const Text('Live Location Share'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── LIVE MAP ───
            Container(
              height: 240,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
                    userAgentPackageName: 'com.aegissafety.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition,
                        width: 50,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.sosRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_pin, color: Colors.white, size: 22),
                            ),
                            Container(width: 2, height: 6, color: AppColors.sosRed),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (locationState.isSharingActive)
              Container(
                margin: const EdgeInsets.only(top: 10),
                child: StatusPill(
                  label: 'Live Sharing Active',
                  type: StatusPillType.guardianWatching,
                ),
              ),

            const SizedBox(height: 24),

            // ─── DURATION SELECTOR (3 options only) ───
            const Text('Sharing Duration', style: AppTypography.titleLarge),
            const SizedBox(height: 12),

            Row(
              children: [
                _durationChip(30, '30 min'),
                const SizedBox(width: 10),
                _durationChip(60, '1 hour'),
                const SizedBox(width: 10),
                _durationChip(-1, 'Until Stopped'),
              ],
            ),
            const SizedBox(height: 28),

            // ─── CONTACT SELECTOR ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Send To', style: AppTypography.titleLarge),
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
                    _selectedContactIds.length == contacts.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(color: AppColors.primaryNavy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...contacts.map((c) => _contactTile(c)),

            const SizedBox(height: 28),

            // ─── ACTION BUTTON ───
            if (!locationState.isSharingActive)
              PrimaryButton(
                label: 'Start Sharing & Send Link',
                icon: Icons.share_location,
                isLoading: _isSendingLink,
                onPressed: _selectedContactIds.isEmpty ? null : _startSharingAndSendLink,
              )
            else
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sosRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final pinValid = await PinVerificationDialog.verify(
                      context: context,
                      actionTitle: 'Stop Location Sharing',
                    );
                    if (pinValid) {
                      ref.read(locationProvider.notifier).stopLiveSharing();
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Stop Sharing',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _durationChip(int value, String label) {
    final isSelected = _selectedDuration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDuration = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryNavy : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryNavy : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          ),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('${contact.relationship} • ${contact.phone}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
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
