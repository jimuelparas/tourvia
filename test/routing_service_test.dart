import 'package:flutter_test/flutter_test.dart';
import 'package:tourvia/core/services/routing_service.dart';

void main() {
  group('RoutingService — Coordinate Validation & Route Parsing', () {
    test('isValidCoordinate accepts valid geographic coordinates', () {
      expect(RoutingService.isValidCoordinate(14.5995, 120.9842), isTrue); // Manila
      expect(RoutingService.isValidCoordinate(0.0, 0.0), isTrue);
      expect(RoutingService.isValidCoordinate(90.0, 180.0), isTrue);
      expect(RoutingService.isValidCoordinate(-90.0, -180.0), isTrue);
    });

    test('isValidCoordinate rejects invalid / out-of-bounds / infinite coordinates', () {
      expect(RoutingService.isValidCoordinate(429605.03482, 120.9842), isFalse);
      expect(RoutingService.isValidCoordinate(91.0, 0.0), isFalse);
      expect(RoutingService.isValidCoordinate(-90.1, 0.0), isFalse);
      expect(RoutingService.isValidCoordinate(0.0, 180.1), isFalse);
      expect(RoutingService.isValidCoordinate(0.0, -180.1), isFalse);
      expect(RoutingService.isValidCoordinate(double.nan, 0.0), isFalse);
      expect(RoutingService.isValidCoordinate(0.0, double.infinity), isFalse);
    });

    test('getRouteWithMode rejects invalid start or end coordinates immediately', () async {
      final result = await RoutingService.getRouteWithMode(
        startLat: 429605.03482,
        startLng: 120.9842,
        endLat: 14.6000,
        endLng: 120.9850,
        mode: 'foot',
      );
      expect(result, isNull);
    });
  });
}
