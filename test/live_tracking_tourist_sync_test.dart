import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tourvia/core/services/location_service.dart';
import 'package:tourvia/core/services/tour_service.dart';
import 'package:tourvia/features/tracking/screens/tour_guide_map_screen.dart';

void main() {
  group('Live Tracking — Tourist Synchronization & Membership', () {
    const guidePos = LatLng(14.5995, 120.9842); // Manila

    test('ApprovedTourist model parses from Firestore data with fallbacks', () {
      final tourist = ApprovedTourist.fromFirestore('t-123', {
        'touristName': 'Alice Wonderland',
        'contactNumber': '+639123456789',
        'emergencyContact': '+639987654321',
      });

      expect(tourist.touristId, 't-123');
      expect(tourist.touristName, 'Alice Wonderland');
      expect(tourist.contactNumber, '+639123456789');
      expect(tourist.emergencyContact, '+639987654321');
    });

    test('TouristTrackingItem without location doc is recognized as Offline / Location Unavailable', () {
      const item = TouristTrackingItem(
        touristId: 't-offline',
        touristName: 'Offline Tourist',
        location: null,
      );

      expect(item.hasLocation, isFalse);
      expect(item.distanceTo(guidePos), isNull);
      expect(item.isOutside(guidePos), isFalse); // Never classified as outside
    });

    test('TouristTrackingItem with (0.0, 0.0) coordinates is treated as unavailable', () {
      final item = TouristTrackingItem(
        touristId: 't-zero',
        touristName: 'Zero GPS Tourist',
        location: UserLocation(
          userId: 't-zero',
          userName: 'Zero GPS Tourist',
          latitude: 0.0,
          longitude: 0.0,
          accuracy: 0.0,
          isGuide: false,
          ringCommand: false,
          updatedAt: DateTime.now(),
        ),
      );

      expect(item.hasLocation, isFalse);
      expect(item.distanceTo(guidePos), isNull);
      expect(item.isOutside(guidePos), isFalse);
    });

    test('TouristTrackingItem within 1km geofence is Safe', () {
      // LatLng very close to guide (approx 50m away)
      final item = TouristTrackingItem(
        touristId: 't-safe',
        touristName: 'Safe Tourist',
        location: UserLocation(
          userId: 't-safe',
          userName: 'Safe Tourist',
          latitude: 14.5998,
          longitude: 120.9845,
          accuracy: 5.0,
          isGuide: false,
          ringCommand: false,
          updatedAt: DateTime.now(),
        ),
      );

      expect(item.hasLocation, isTrue);
      final dist = item.distanceTo(guidePos);
      expect(dist, isNotNull);
      expect(dist! < 1000.0, isTrue);
      expect(item.isOutside(guidePos), isFalse);
    });

    test('TouristTrackingItem beyond 1km geofence is Outside', () {
      // LatLng approx 5km away from guide
      final item = TouristTrackingItem(
        touristId: 't-outside',
        touristName: 'Outside Tourist',
        location: UserLocation(
          userId: 't-outside',
          userName: 'Outside Tourist',
          latitude: 14.6500,
          longitude: 121.0000,
          accuracy: 5.0,
          isGuide: false,
          ringCommand: false,
          updatedAt: DateTime.now(),
        ),
      );

      expect(item.hasLocation, isTrue);
      final dist = item.distanceTo(guidePos);
      expect(dist, isNotNull);
      expect(dist! > 1000.0, isTrue);
      expect(item.isOutside(guidePos), isTrue);
    });

    test('Counters separation: 3 approved tourists (1 safe, 1 outside, 1 offline) calculates correctly', () {
      final tourists = [
        TouristTrackingItem(
          touristId: 't1',
          touristName: 'Tourist 1',
          location: UserLocation(
            userId: 't1',
            userName: 'Tourist 1',
            latitude: 14.5998,
            longitude: 120.9845,
            accuracy: 5.0,
            isGuide: false,
            ringCommand: false,
            updatedAt: DateTime.now(),
          ),
        ),
        TouristTrackingItem(
          touristId: 't2',
          touristName: 'Tourist 2',
          location: UserLocation(
            userId: 't2',
            userName: 'Tourist 2',
            latitude: 14.6500,
            longitude: 121.0000,
            accuracy: 5.0,
            isGuide: false,
            ringCommand: false,
            updatedAt: DateTime.now(),
          ),
        ),
        const TouristTrackingItem(
          touristId: 't3',
          touristName: 'Tourist 3',
          location: null,
        ),
      ];

      final withLoc = tourists.where((t) => t.hasLocation).toList();
      final outsideCount = withLoc.where((t) => t.isOutside(guidePos)).length;
      final safeCount = withLoc.length - outsideCount;
      final offlineCount = tourists.length - withLoc.length;

      expect(tourists.length, 3); // 3 total
      expect(safeCount, 1);       // 1 Safe
      expect(outsideCount, 1);    // 1 Outside
      expect(offlineCount, 1);    // 1 Offline
    });
  });
}
