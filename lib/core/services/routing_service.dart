import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for calculating route distance, duration, and geometry using OpenRouteService or OSRM.
/// Defaulting to OSRM demo server since it requires no API key.
class RoutingService {
  RoutingService._();

  static const String _osrmBaseUrl = 'http://router.project-osrm.org/route/v1';

  /// Determines the route between two coordinates.
  /// Automatically uses walking profile if straight-line distance is small, otherwise driving.
  /// Returns a Map containing:
  /// - 'distance': double (in meters)
  /// - 'duration': int (in seconds)
  /// - 'polyline': String (encoded polyline)
  static Future<Map<String, dynamic>?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // Determine profile based on heuristic (if < 1km, walk)
    final bool isShortDistance = _isShortDistance(startLat, startLng, endLat, endLng);
    final profile = isShortDistance ? 'foot' : 'driving';

    // OSRM coordinates format: {longitude},{latitude};{longitude},{latitude}
    final coordinates = '$startLng,$startLat;$endLng,$endLat';
    final url = Uri.parse('$_osrmBaseUrl/$profile/$coordinates?overview=full&geometries=polyline');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final route = routes.first;
          return {
            'distance': (route['distance'] as num).toDouble(),
            'duration': (route['duration'] as num).toInt(),
            'polyline': route['geometry'] as String,
            'mode': profile,
          };
        }
      } else {
        print('OSRM Routing API Error: \${response.statusCode} - \${response.body}');
      }
    } catch (e) {
      print('Exception in getRoute: \$e');
    }
    return null;
  }

  /// Simple approximation to check if distance is < 1km
  static bool _isShortDistance(double lat1, double lon1, double lat2, double lon2) {
    // simplified distance check, 1 degree is ~111km
    final dx = (lat1 - lat2) * 111.32;
    final dy = (lon1 - lon2) * 111.32 * 0.9; // rough approx for Philippines latitude
    final distanceKm = dx * dx + dy * dy;
    return distanceKm < 1.0;
  }
}
