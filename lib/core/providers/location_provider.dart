import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationState {
  final bool isGpsEnabled;
  final bool isSharingActive;
  final double currentLat;
  final double currentLng;
  final String locationAddress;
  final DateTime? lastPingTime;
  final int shareDurationMinutes;
  final List<String> activeRecipients;

  LocationState({
    this.isGpsEnabled = true,
    this.isSharingActive = false,
    this.currentLat = 12.9716,
    this.currentLng = 77.5946,
    this.locationAddress = 'MG Road, Central District',
    this.lastPingTime,
    this.shareDurationMinutes = 60,
    this.activeRecipients = const [],
  });

  LatLng get currentLocation => LatLng(currentLat, currentLng);

  LocationState copyWith({
    bool? isGpsEnabled,
    bool? isSharingActive,
    double? currentLat,
    double? currentLng,
    String? locationAddress,
    DateTime? lastPingTime,
    int? shareDurationMinutes,
    List<String>? activeRecipients,
  }) {
    return LocationState(
      isGpsEnabled: isGpsEnabled ?? this.isGpsEnabled,
      isSharingActive: isSharingActive ?? this.isSharingActive,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      locationAddress: locationAddress ?? this.locationAddress,
      lastPingTime: lastPingTime ?? this.lastPingTime,
      shareDurationMinutes: shareDurationMinutes ?? this.shareDurationMinutes,
      activeRecipients: activeRecipients ?? this.activeRecipients,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState(lastPingTime: DateTime.now())) {
    fetchCurrentGpsLocation();
  }

  Future<void> fetchCurrentGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      state = state.copyWith(
        currentLat: pos.latitude,
        currentLng: pos.longitude,
        locationAddress: 'Current GPS Location',
        lastPingTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error fetching GPS location: $e');
    }
  }

  void toggleGps(bool enabled) {
    state = state.copyWith(
      isGpsEnabled: enabled,
      lastPingTime: DateTime.now(),
    );
    if (enabled) {
      fetchCurrentGpsLocation();
    }
  }

  void startLiveSharing({int durationMinutes = 60, required List<String> recipients}) {
    state = state.copyWith(
      isSharingActive: true,
      shareDurationMinutes: durationMinutes,
      activeRecipients: recipients,
      lastPingTime: DateTime.now(),
    );
  }

  void stopLiveSharing() {
    state = state.copyWith(
      isSharingActive: false,
      activeRecipients: [],
    );
  }

  void updateLocation(double lat, double lng, String address) {
    state = state.copyWith(
      currentLat: lat,
      currentLng: lng,
      locationAddress: address,
      lastPingTime: DateTime.now(),
    );
  }
}


final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
