import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Lightweight location wrapper. Resolves the user's current position once
/// (best-effort, medium accuracy is fine for distance-sort use) and caches
/// it inside a Riverpod FutureProvider. Returns null on denial / timeout so
/// callers can fall back to a non-distance sort.
class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationService {
  Future<LatLng?> currentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// Haversine great-circle distance in kilometres between two LatLng points.
double haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = _toRad(b.lat - a.lat);
  final dLng = _toRad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(a.lat)) *
          math.cos(_toRad(b.lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.asin(math.sqrt(h));
  return r * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;

final locationServiceProvider =
    Provider<LocationService>((_) => LocationService());

/// Cached one-shot position lookup. Screens watch this to react when the
/// user grants/denies the prompt mid-session.
final currentLocationProvider = FutureProvider<LatLng?>((ref) async {
  return ref.watch(locationServiceProvider).currentPosition();
});
