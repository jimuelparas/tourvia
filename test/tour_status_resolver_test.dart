import 'package:flutter_test/flutter_test.dart';
import 'package:tourvia/core/models/tour_model.dart';
import 'package:tourvia/core/services/tour_status_resolver.dart';

void main() {
  group('TourStatusResolver - Centralized Status Architecture (REV-004)', () {
    final baseDate = DateTime(2026, 9, 16);

    test('Returns only TourStatus enum: upcoming, active, completed', () {
      expect(TourStatus.values, [
        TourStatus.upcoming,
        TourStatus.active,
        TourStatus.completed,
      ]);
    });

    test('Priority 1: Explicit status == "completed" returns TourStatus.completed', () {
      final tour = Tour(
        id: 'tour-1',
        name: 'Explicitly Completed Tour',
        guideId: 'guide-1',
        guideName: 'Guide',
        startDate: baseDate.add(const Duration(days: 5)),
        endDate: baseDate.add(const Duration(days: 6)),
        totalDays: 2,
        accessCode: 'CODE01',
        status: 'completed',
      );

      expect(tour.effectiveStatus, TourStatus.completed);
      expect(tour.isCompleted, isTrue);
      expect(tour.isUpcoming, isFalse);
      expect(tour.isActive, isFalse);
    });

    test('Priority 1: endedAt != null returns TourStatus.completed regardless of raw status', () {
      final tour = Tour(
        id: 'tour-2',
        name: 'Ended At Tour',
        guideId: 'guide-1',
        guideName: 'Guide',
        startDate: baseDate,
        endDate: baseDate.add(const Duration(days: 1)),
        totalDays: 2,
        accessCode: 'CODE02',
        status: 'active',
        endedAt: DateTime(2026, 9, 16, 10, 0),
      );

      expect(tour.effectiveStatus, TourStatus.completed);
      expect(tour.isCompleted, isTrue);
      expect(tour.isActive, isFalse);
    });

    test('Priority 2: Future tour schedule resolves to UPCOMING', () {
      final tour = Tour(
        id: 'tour-future',
        name: 'Future Tour',
        guideId: 'guide-1',
        guideName: 'Guide',
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 22),
        totalDays: 3,
        accessCode: 'CODE03',
        status: 'upcoming',
      );

      final now = DateTime(2026, 9, 16, 12, 0);
      final status = TourStatusResolver.resolve(tour, now);

      expect(status, TourStatus.upcoming);
      expect(tour.resolveStatus(now), TourStatus.upcoming);
    });

    test('Priority 2: Ongoing tour schedule resolves to ACTIVE', () {
      final tour = Tour(
        id: 'tour-ongoing',
        name: 'Ongoing Tour',
        guideId: 'guide-1',
        guideName: 'Guide',
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 9, 17),
        totalDays: 3,
        accessCode: 'CODE04',
        status: 'upcoming', // Stale Firestore status must be ignored!
      );

      final now = DateTime(2026, 9, 16, 12, 0);
      final status = TourStatusResolver.resolve(tour, now);

      expect(status, TourStatus.active);
    });

    test('Priority 2: Past tour schedule resolves to COMPLETED even if stored status is stale', () {
      // Simulates the exact bug reported: tour 'gggggg' had status 'active' in Firestore
      final tourActiveStale = Tour(
        id: 'zmdpsxAJCttpxP8XEd7i',
        name: 'gggggg',
        guideId: 'guide-1',
        guideName: 'Tourvia ggg',
        startDate: DateTime(2026, 9, 12),
        endDate: DateTime(2026, 9, 13),
        totalDays: 2,
        accessCode: 'TRV-F43',
        status: 'active', // Stale status!
      );

      // Simulates tour 'gg' which had status 'upcoming' in Firestore
      final tourUpcomingStale = Tour(
        id: 'XTd4JQaoPNPOavCmhCEy',
        name: 'gg',
        guideId: 'guide-1',
        guideName: 'Tourvia ggg',
        startDate: DateTime(2026, 9, 14),
        endDate: DateTime(2026, 9, 14),
        totalDays: 1,
        accessCode: 'TRV-DEE',
        status: 'upcoming', // Stale status!
      );

      final now = DateTime(2026, 9, 16, 12, 0);

      expect(tourActiveStale.resolveStatus(now), TourStatus.completed);
      expect(tourUpcomingStale.resolveStatus(now), TourStatus.completed);
    });

    test('Full Schedule with Start Time and End Time (Section 2 & 6)', () {
      final tourWithTimes = Tour(
        id: 'tour-timed',
        name: 'Timed Tour',
        guideId: 'guide-1',
        guideName: 'Guide',
        startDate: DateTime(2026, 9, 16),
        endDate: DateTime(2026, 9, 16),
        totalDays: 1,
        accessCode: 'TIME01',
        startTime: '08:00 AM',
        endTime: '05:00 PM',
        status: 'upcoming',
      );

      // 1. Before 8:00 AM -> UPCOMING
      final beforeStart = DateTime(2026, 9, 16, 7, 30);
      expect(tourWithTimes.resolveStatus(beforeStart), TourStatus.upcoming);

      // 2. Exactly at 8:00 AM -> ACTIVE
      final atStart = DateTime(2026, 9, 16, 8, 0);
      expect(tourWithTimes.resolveStatus(atStart), TourStatus.active);

      // 3. During the tour (12:00 PM) -> ACTIVE
      final duringTour = DateTime(2026, 9, 16, 12, 0);
      expect(tourWithTimes.resolveStatus(duringTour), TourStatus.active);

      // 4. After 5:00 PM (5:01 PM) -> COMPLETED
      final afterEnd = DateTime(2026, 9, 16, 17, 1);
      expect(tourWithTimes.resolveStatus(afterEnd), TourStatus.completed);
    });

    test('Tab filtering and Badge always agree (No contradictory status)', () {
      final pastTour = Tour(
        id: 't-past',
        name: 'Old Tour',
        guideId: 'guide-1',
        guideName: 'Guide',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 2),
        totalDays: 2,
        accessCode: 'PAST01',
        status: 'active', // stale raw status
      );

      final now = DateTime(2026, 9, 16);
      final effective = pastTour.resolveStatus(now);

      // Tab membership
      final inUpcomingTab = effective == TourStatus.upcoming;
      final inActiveTab = effective == TourStatus.active;
      final inCompletedTab = effective == TourStatus.completed;

      expect(inUpcomingTab, isFalse);
      expect(inActiveTab, isFalse);
      expect(inCompletedTab, isTrue);

      // Badge label
      expect(effective.label, 'Completed');
    });
  });
}
