import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tourvia/core/services/routing_service.dart';

void main() {
  group('Navigation Accuracy & Snapping Tests', () {
    test('Coordinate order LatLng(latitude, longitude) validation', () {
      // Manila coordinates: lat ~14.5995, lng ~120.9842
      const manilaLat = 14.5995;
      const manilaLng = 120.9842;
      final pos = const LatLng(manilaLat, manilaLng);

      expect(pos.latitude, equals(manilaLat));
      expect(pos.longitude, equals(manilaLng));
      expect(RoutingService.isValidCoordinate(pos.latitude, pos.longitude), isTrue);

      // If inverted (lat=120.9842, lng=14.5995), lat is invalid (> 90)
      expect(RoutingService.isValidCoordinate(manilaLng, manilaLat), isFalse);
    });

    test('Road snapping: connects GPS origin to snapped road points if > 5m', () {
      final start = const LatLng(14.5990, 120.9840);
      final snappedStart = const LatLng(14.5992, 120.9842); // ~30m away on road
      final roadPoints = [
        snappedStart,
        const LatLng(14.5996, 120.9846),
        const LatLng(14.6000, 120.9850),
      ];
      final end = const LatLng(14.6002, 120.9852); // ~30m from last road point

      final dStart = const Distance().as(LengthUnit.Meter, start, roadPoints.first);
      final dEnd = const Distance().as(LengthUnit.Meter, end, roadPoints.last);

      final fullRoute = <LatLng>[];
      if (dStart > 5.0) fullRoute.add(start);
      fullRoute.addAll(roadPoints);
      if (dEnd > 5.0) fullRoute.add(end);

      expect(fullRoute.first, equals(start));
      expect(fullRoute.last, equals(end));
      expect(fullRoute.length, equals(5));
    });

    test('Accumulate road distance along polyline segments accurately', () {
      final points = [
        const LatLng(14.5990, 120.9840),
        const LatLng(14.6000, 120.9840), // ~111 meters north
        const LatLng(14.6000, 120.9850), // ~107 meters east
      ];

      // Road distance along segments
      double roadDistance = 0.0;
      for (int i = 0; i < points.length - 1; i++) {
        roadDistance += const Distance().as(LengthUnit.Meter, points[i], points[i + 1]);
      }

      // Straight-line Euclidean distance
      final directDistance = const Distance().as(LengthUnit.Meter, points.first, points.last);

      // Road distance (two sides of triangle) must be greater than straight-line hypotenuse
      expect(roadDistance, greaterThan(directDistance));
      expect(roadDistance, greaterThan(200.0));
      expect(directDistance, greaterThan(140.0));
    });

    test('Arrival threshold detection (< 15 meters)', () {
      const target = LatLng(14.60000, 120.98500);

      // 100 meters away -> not arrived
      const farUser = LatLng(14.60090, 120.98500);
      final farDist = const Distance().as(LengthUnit.Meter, farUser, target);
      expect(farDist > 15.0, isTrue);

      // 8 meters away -> arrived
      const nearUser = LatLng(14.60005, 120.98505);
      final nearDist = const Distance().as(LengthUnit.Meter, nearUser, target);
      expect(nearDist <= 15.0, isTrue);
    });

    test('Off-route threshold detection (> 50 meters)', () {
      final route = [
        const LatLng(14.5990, 120.9840),
        const LatLng(14.6000, 120.9840),
        const LatLng(14.6010, 120.9840),
      ];

      // User walking right on the road near a route waypoint
      const onRoadUser = LatLng(14.6001, 120.9840);
      double minDistanceOnRoad = double.infinity;
      for (final p in route) {
        final d = const Distance().as(LengthUnit.Meter, onRoadUser, p);
        if (d < minDistanceOnRoad) minDistanceOnRoad = d;
      }
      expect(minDistanceOnRoad, lessThan(50.0));

      // User wandered 80m east away from the route
      const offRouteUser = LatLng(14.5995, 120.9848);
      double minDistanceOffRoute = double.infinity;
      for (final p in route) {
        final d = const Distance().as(LengthUnit.Meter, offRouteUser, p);
        if (d < minDistanceOffRoute) minDistanceOffRoute = d;
      }
      expect(minDistanceOffRoute, greaterThan(50.0));
    });
  });
}
