import 'package:flutter_test/flutter_test.dart';
import 'package:tourvia/core/models/tour_model.dart';
import 'package:tourvia/features/itinerary/models/itinerary_item.dart';

void main() {
  group('TourScheduleStatus Lifecycle Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfterTomorrow = today.add(const Duration(days: 2));
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    test('Future tour (starts tomorrow) is READY / UPCOMING and never ACTIVE', () {
      final tour = Tour(
        id: 'future-tour',
        name: 'Future Adventure',
        guideId: 'guide-1',
        guideName: 'John Doe',
        startDate: tomorrow,
        endDate: dayAfterTomorrow,
        totalDays: 2,
        accessCode: 'TEST12',
        status: 'ready',
      );

      expect(tour.scheduleStatus, TourScheduleStatus.ready);
      expect(tour.isReady, isTrue);
      expect(tour.isScheduleActive, isFalse);
      expect(tour.isScheduleCompleted, isFalse);
      expect(tour.currentScheduleDay, 1);
    });

    test('Active tour (starts today or ongoing) is ACTIVE', () {
      final tour = Tour(
        id: 'active-tour',
        name: 'Ongoing Adventure',
        guideId: 'guide-1',
        guideName: 'John Doe',
        startDate: today,
        endDate: tomorrow,
        totalDays: 2,
        accessCode: 'TEST12',
        status: 'ready', // even if raw status string is not updated yet, calendar day governs
      );

      expect(tour.scheduleStatus, TourScheduleStatus.active);
      expect(tour.isReady, isFalse);
      expect(tour.isScheduleActive, isTrue);
      expect(tour.isScheduleCompleted, isFalse);
      expect(tour.currentScheduleDay, 1);
    });

    test('Past tour (end date has passed) is COMPLETED', () {
      final tour = Tour(
        id: 'past-tour',
        name: 'Past Adventure',
        guideId: 'guide-1',
        guideName: 'John Doe',
        startDate: twoDaysAgo,
        endDate: yesterday,
        totalDays: 2,
        accessCode: 'TEST12',
        status: 'ready',
      );

      expect(tour.scheduleStatus, TourScheduleStatus.completed);
      expect(tour.isReady, isFalse);
      expect(tour.isScheduleActive, isFalse);
      expect(tour.isScheduleCompleted, isTrue);
    });

    test('Explicitly completed tour is COMPLETED even if within date range', () {
      final tour = Tour(
        id: 'ended-early-tour',
        name: 'Ended Early Adventure',
        guideId: 'guide-1',
        guideName: 'John Doe',
        startDate: today,
        endDate: tomorrow,
        totalDays: 2,
        accessCode: 'TEST12',
        status: 'completed',
      );

      expect(tour.scheduleStatus, TourScheduleStatus.completed);
      expect(tour.isReady, isFalse);
      expect(tour.isScheduleActive, isFalse);
      expect(tour.isScheduleCompleted, isTrue);
    });
  });

  group('Itinerary Date Guard Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    test('Future stop is NEVER past schedule, even if stop time is in the morning', () {
      final item = ItineraryItem(
        id: 'stop-future',
        destinationName: 'Tomorrow Museum',
        date: tomorrow,
        startTime: '08:00 AM',
        endTime: '09:00 AM',
      );

      expect(item.isPastSchedule, isFalse);
      // Effective status must NOT be completed
      expect(item.effectiveStatus, isNot(ItineraryStatus.completed));
    });

    test('Past stop from yesterday IS past schedule', () {
      final item = ItineraryItem(
        id: 'stop-yesterday',
        destinationName: 'Yesterday Museum',
        date: yesterday,
        startTime: '08:00 AM',
        endTime: '09:00 AM',
      );

      expect(item.isPastSchedule, isTrue);
      expect(item.effectiveStatus, ItineraryStatus.completed);
    });

    test('Stop with missing end time on today does not prematurely complete', () {
      final item = ItineraryItem(
        id: 'stop-no-end-time',
        destinationName: 'Park Visit',
        date: today,
        startTime: '08:00 AM',
        endTime: '',
      );

      // Should not be marked past schedule because end time is not set
      expect(item.isPastSchedule, isFalse);
    });
  });
}
