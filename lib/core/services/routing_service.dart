import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service for calculating route distance, duration, and geometry using OSRM.
/// Returns decoded polyline points for direct rendering on flutter_map.
class RoutingService {
  RoutingService._();

  /// OSRM demo server base URLs (HTTPS preferred, HTTP fallback).
  static const String _osrmHttpsUrl =
      'https://router.project-osrm.org/route/v1';
  static const String _osrmHttpUrl =
      'http://router.project-osrm.org/route/v1';

  /// Validates that a coordinate has valid geographic bounds (-90..90 lat, -180..180 lng).
  static bool isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lng >= -180.0 &&
        lng <= 180.0;
  }

  /// Fetches a route between two coordinates with an explicit travel mode.
  ///
  /// [mode] must be `'foot'` (walking) or `'driving'`.
  /// Returns a Map containing:
  /// - `'distance'`: double (meters)
  /// - `'duration'`: int (seconds)
  /// - `'polyline'`: String (empty for geojson mode)
  /// - `'points'`:   `List<LatLng>` (valid polyline points for flutter_map)
  /// - `'mode'`:     String ('foot' or 'driving')
  ///
  /// Returns `null` if the request fails or coordinates are invalid.
  static Future<Map<String, dynamic>?> getRouteWithMode({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String mode,
  }) async {
    if (!isValidCoordinate(startLat, startLng) ||
        !isValidCoordinate(endLat, endLng)) {
      debugPrint(
        'RoutingService: Invalid start or end coordinates: '
        'start($startLat, $startLng), end($endLat, $endLng)',
      );
      return null;
    }

    final profile = (mode == 'foot') ? 'foot' : 'driving';
    final coordinates = '$startLng,$startLat;$endLng,$endLat';
    final queryParams = 'overview=full&geometries=geojson';

    // Try HTTPS first, fall back to HTTP
    for (final baseUrl in [_osrmHttpsUrl, _osrmHttpUrl]) {
      final url = Uri.parse('$baseUrl/$profile/$coordinates?$queryParams');
      try {
        final response = await http.get(url).timeout(
          const Duration(seconds: 10),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final geometry = route['geometry'];
            final points = <LatLng>[];

            if (geometry is Map<String, dynamic> &&
                geometry['coordinates'] is List) {
              final coords = geometry['coordinates'] as List<dynamic>;
              for (final pair in coords) {
                if (pair is List && pair.length >= 2) {
                  final lng = (pair[0] as num).toDouble();
                  final lat = (pair[1] as num).toDouble();
                  if (isValidCoordinate(lat, lng)) {
                    points.add(LatLng(lat, lng));
                  } else {
                    debugPrint('RoutingService: Ignoring invalid point ($lat, $lng)');
                  }
                }
              }
            }

            // If geometry coordinates were empty or invalid, fallback to start/end
            if (points.isEmpty) {
              points.addAll([
                LatLng(startLat, startLng),
                LatLng(endLat, endLng),
              ]);
            }

            return {
              'distance': (route['distance'] as num).toDouble(),
              'duration': (route['duration'] as num).toInt(),
              'polyline': '',
              'points': points,
              'mode': profile,
            };
          }
        } else {
          debugPrint(
            'OSRM Routing API Error: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('OSRM request failed ($baseUrl): $e');
        // Continue to next URL
      }
    }
    return null;
  }

  /// Auto-detects travel mode and fetches route.
  /// Uses walking if straight-line distance < 1 km, otherwise driving.
  static Future<Map<String, dynamic>?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final isShort = _isShortDistance(startLat, startLng, endLat, endLng);
    final mode = isShort ? 'foot' : 'driving';
    return getRouteWithMode(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      mode: mode,
    );
  }

  /// Simple approximation to check if distance is < 1km.
  static bool _isShortDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dx = (lat1 - lat2) * 111.32;
    final dy = (lon1 - lon2) * 111.32 * 0.9;
    final distanceKmSq = dx * dx + dy * dy;
    return distanceKmSq < 1.0;
  }
}
