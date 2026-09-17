import 'package:flutter_test/flutter_test.dart';
import 'package:tourvia/core/services/attendance_service.dart';
import 'package:tourvia/core/services/weather_service.dart';
import 'package:tourvia/features/attendance/models/tourist_attendance.dart';
import 'package:tourvia/features/itinerary/models/itinerary_item.dart'
    hide AttendanceStatus;

void main() {
  group('Attendance Count & Calculation Tests', () {
    test('Calculates correct present and total count for approved tourists', () {
      final roster = [
        const TouristRecord(codeDocId: 't1', code: 'TRV-1', touristName: 'Alice'),
        const TouristRecord(codeDocId: 't2', code: 'TRV-2', touristName: 'Bob'),
        const TouristRecord(codeDocId: 't3', code: 'TRV-3', touristName: 'Charlie'),
        const TouristRecord(codeDocId: 't4', code: 'TRV-4', touristName: 'Diana'),
      ];

      // 0 marked present
      Map<String, AttendanceRecord> records0 = {};
      int present0 = roster
          .where((t) => records0[t.codeDocId]?.status == AttendanceStatus.present)
          .length;
      expect(present0, 0);
      expect(roster.length, 4);

      // 3 marked present, 1 absent
      Map<String, AttendanceRecord> records3 = {
        't1': const AttendanceRecord(touristId: 't1', touristName: 'Alice', touristCode: 'TRV-1', status: AttendanceStatus.present),
        't2': const AttendanceRecord(touristId: 't2', touristName: 'Bob', touristCode: 'TRV-2', status: AttendanceStatus.present),
        't3': const AttendanceRecord(touristId: 't3', touristName: 'Charlie', touristCode: 'TRV-3', status: AttendanceStatus.present),
        't4': const AttendanceRecord(touristId: 't4', touristName: 'Diana', touristCode: 'TRV-4', status: AttendanceStatus.absent),
      };
      int present3 = roster
          .where((t) => records3[t.codeDocId]?.status == AttendanceStatus.present)
          .length;
      expect(present3, 3);
      expect(roster.length, 4);

      // All 4 marked present
      Map<String, AttendanceRecord> records4 = {
        't1': const AttendanceRecord(touristId: 't1', touristName: 'Alice', touristCode: 'TRV-1', status: AttendanceStatus.present),
        't2': const AttendanceRecord(touristId: 't2', touristName: 'Bob', touristCode: 'TRV-2', status: AttendanceStatus.present),
        't3': const AttendanceRecord(touristId: 't3', touristName: 'Charlie', touristCode: 'TRV-3', status: AttendanceStatus.present),
        't4': const AttendanceRecord(touristId: 't4', touristName: 'Diana', touristCode: 'TRV-4', status: AttendanceStatus.present),
      };
      int present4 = roster
          .where((t) => records4[t.codeDocId]?.status == AttendanceStatus.present)
          .length;
      expect(present4, 4);
      expect(roster.length, 4);
    });

    test('Empty roster produces 0 / 0 Present', () {
      final roster = <TouristRecord>[];
      final records = <String, AttendanceRecord>{};
      int present = roster
          .where((t) => records[t.codeDocId]?.status == AttendanceStatus.present)
          .length;
      expect(present, 0);
      expect(roster.length, 0);
    });
  });

  group('Tour Progress Completion Consistency Tests', () {
    test('Completed stops are consistently evaluated using effectiveStatus', () {
      final now = DateTime.now();
      final stops = [
        ItineraryItem(
          id: 's1',
          destinationName: 'Burnham Park',
          date: now,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          status: ItineraryStatus.completed,
        ),
        ItineraryItem(
          id: 's2',
          destinationName: 'Session Road',
          date: now,
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          status: ItineraryStatus.completed,
        ),
        ItineraryItem(
          id: 's3',
          destinationName: 'Mines View',
          date: now,
          startTime: '01:00 PM',
          endTime: '02:00 PM',
          status: ItineraryStatus.completed,
        ),
      ];

      final completedCount = stops
          .where((s) => s.effectiveStatus == ItineraryStatus.completed)
          .length;

      expect(completedCount, 3);
      expect(stops.length, 3);
      expect('$completedCount / ${stops.length} Stops Completed',
          '3 / 3 Stops Completed');
    });
  });

  group('Weather Location Exceptions Tests', () {
    test('LocationServiceDisabledException has correct user message', () {
      const ex = LocationServiceDisabledException();
      expect(ex.message, 'Location service is unavailable.');
      expect(ex.toString(), 'Location service is unavailable.');
    });

    test('LocationPermissionDeniedException has correct user message', () {
      const ex = LocationPermissionDeniedException();
      expect(ex.message, 'Enable location to view local weather.');
      expect(ex.toString(), 'Enable location to view local weather.');
    });
  });
}
