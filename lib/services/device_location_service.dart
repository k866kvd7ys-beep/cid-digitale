import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocationResult {
  const DeviceLocationResult({
    required this.serviceEnabled,
    required this.permission,
    required this.position,
  });

  final bool serviceEnabled;
  final LocationPermission? permission;
  final Position? position;

  bool get permissionGranted =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<DeviceLocationResult> requestCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const DeviceLocationResult(
        serviceEnabled: false,
        permission: null,
        position: null,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return DeviceLocationResult(
        serviceEnabled: true,
        permission: permission,
        position: null,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      ).timeout(timeout);

      return DeviceLocationResult(
        serviceEnabled: true,
        permission: permission,
        position: position,
      );
    } on TimeoutException {
      return DeviceLocationResult(
        serviceEnabled: true,
        permission: permission,
        position: null,
      );
    } catch (_) {
      return DeviceLocationResult(
        serviceEnabled: true,
        permission: permission,
        position: null,
      );
    }
  }

  Future<List<Placemark>> loadPlacemarks(Position position) {
    return placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
  }

  Future<String?> resolveCityHint(Position position) async {
    List<Placemark> placemarks;
    try {
      placemarks = await loadPlacemarks(position);
    } catch (_) {
      return null;
    }

    for (final placemark in placemarks) {
      final candidates = [
        placemark.locality,
        placemark.subAdministrativeArea,
        placemark.administrativeArea,
      ];

      for (final candidate in candidates) {
        final trimmed = candidate?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }

    return null;
  }

  Future<String?> resolveAddressLabel(Position position) async {
    List<Placemark> placemarks;
    try {
      placemarks = await loadPlacemarks(position);
    } catch (_) {
      return null;
    }
    if (placemarks.isEmpty) return null;

    final placemark = placemarks.first;
    final parts = <String>[
      if ((placemark.street ?? '').trim().isNotEmpty)
        placemark.street!.trim(),
      if ((placemark.locality ?? '').trim().isNotEmpty)
        placemark.locality!.trim(),
    ];

    final formatted = parts.join(', ');
    return formatted.isEmpty ? null : formatted;
  }
}
