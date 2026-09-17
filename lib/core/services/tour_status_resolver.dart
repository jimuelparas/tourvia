import '../models/tour_model.dart';

/// The 3-state lifecycle for a tour (REV-004).
enum TourStatus {
  upcoming,
  active,
  completed;

  String get label {
    switch (this) {
      case TourStatus.upcoming:
        return 'Upcoming';
      case TourStatus.active:
        return 'Active';
      case TourStatus.completed:
        return 'Completed';
    }
  }

  String get value {
    switch (this) {
      case TourStatus.upcoming:
        return 'upcoming';
      case TourStatus.active:
        return 'active';
      case TourStatus.completed:
        return 'completed';
    }
  }

  bool get isUpcoming => this == TourStatus.upcoming;
  bool get isActive => this == TourStatus.active;
  bool get isCompleted => this == TourStatus.completed;
}

class TourTimeOffset {
  final int hour;
  final int minute;
  const TourTimeOffset(this.hour, this.minute);
}

/// Centralized Single Source of Truth for Tour Status Resolution (REV-004).
///
/// Determines the effective status of any tour strictly adhering to:
/// 1. FIRST: Check whether the tour has been explicitly/finally completed.
///    - tour.status == 'completed'
///    - OR tour.endedAt != null
///    - OR tour.completedAt != null
///    --> COMPLETED
///
/// 2. SECOND: Compare the FULL TOUR SCHEDULE (combining Date + Time).
///    - now < tourStartDateTime   --> UPCOMING
///    - now >= tourStartDateTime && now <= tourEndDateTime --> ACTIVE
///    - now > tourEndDateTime    --> COMPLETED
class TourStatusResolver {
  TourStatusResolver._();

  /// Resolves the effective status of [tour] at the given point in time [now].
  /// Defaults to [DateTime.now()] if [now] is not provided.
  static TourStatus resolve(Tour tour, [DateTime? now]) {
    try {
      final current = now ?? DateTime.now();

      // ── Priority 1: Explicit / Manual Completion ─────────────
      final rawStatus = tour.status.trim().toLowerCase();
      if (rawStatus == 'completed' ||
          tour.endedAt != null ||
          tour.completedAt != null) {
        return TourStatus.completed;
      }

      // ── Priority 2: Full Schedule (Date + Time) ──────────────
      final startDateTime = getTourStartDateTime(tour);
      final endDateTime = getTourEndDateTime(tour);

      if (current.isBefore(startDateTime)) {
        return TourStatus.upcoming;
      } else if (!current.isAfter(endDateTime)) {
        return TourStatus.active;
      } else {
        return TourStatus.completed;
      }
    } catch (_) {
      final raw = tour.status.trim().toLowerCase();
      if (raw == 'completed') return TourStatus.completed;
      if (raw == 'active') return TourStatus.active;
      return TourStatus.upcoming;
    }
  }

  /// Calculates the combined Tour Start DateTime.
  ///
  /// Combines Tour Start Date with Tour Start Time if present.
  /// Falls back to 00:00:00 of Start Date if no time is specified.
  static DateTime getTourStartDateTime(Tour tour) {
    try {
      final start = tour.startDate.toLocal();

      // 1. Explicit startTime on tour
      if (tour.startTime != null && tour.startTime!.trim().isNotEmpty) {
        final parsedTime = parseTimeOfDay(tour.startTime!);
        if (parsedTime != null) {
          return DateTime(
            start.year,
            start.month,
            start.day,
            parsedTime.hour,
            parsedTime.minute,
          );
        }
      }

      // 2. Try parsing start time from schedule string (e.g. "8:00 AM – 5:00 PM")
      if (tour.schedule.trim().isNotEmpty) {
        final times = extractTimesFromText(tour.schedule);
        if (times.isNotEmpty) {
          return DateTime(
            start.year,
            start.month,
            start.day,
            times.first.hour,
            times.first.minute,
          );
        }
      }

      // 3. Fallback: Beginning of start date
      return DateTime(start.year, start.month, start.day, 0, 0, 0);
    } catch (_) {
      return DateTime(
        tour.startDate.year,
        tour.startDate.month,
        tour.startDate.day,
        0,
        0,
        0,
      );
    }
  }

  /// Calculates the combined Tour End DateTime.
  ///
  /// Combines Tour End Date with Tour End Time if present.
  /// Falls back to 23:59:59.999 of End Date if no time is specified.
  static DateTime getTourEndDateTime(Tour tour) {
    try {
      final end = tour.endDate.toLocal();

      // 1. Explicit endTime on tour
      if (tour.endTime != null && tour.endTime!.trim().isNotEmpty) {
        final parsedTime = parseTimeOfDay(tour.endTime!);
        if (parsedTime != null) {
          return DateTime(
            end.year,
            end.month,
            end.day,
            parsedTime.hour,
            parsedTime.minute,
            59,
            999,
          );
        }
      }

      // 2. Try parsing end time from schedule string (e.g. "8:00 AM – 5:00 PM")
      if (tour.schedule.trim().isNotEmpty) {
        final times = extractTimesFromText(tour.schedule);
        if (times.length >= 2) {
          return DateTime(
            end.year,
            end.month,
            end.day,
            times[1].hour,
            times[1].minute,
            59,
            999,
          );
        }
      }

      // 3. Fallback: End of end date (23:59:59.999)
      return DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    } catch (_) {
      return DateTime(
        tour.endDate.year,
        tour.endDate.month,
        tour.endDate.day,
        23,
        59,
        59,
        999,
      );
    }
  }

  /// Parses various time strings into hour and minute:
  /// - "8:00 AM", "08:30 AM", "1:15 PM"
  /// - "8:00am", "5:00pm"
  /// - "17:30", "08:00"
  static TourTimeOffset? parseTimeOfDay(String timeStr) {
    final raw = timeStr.trim();
    if (raw.isEmpty) return null;

    try {
      final regex = RegExp(
        r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM|am|pm)?$',
        caseSensitive: false,
      );
      final match = regex.firstMatch(raw);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final meridian = match.group(3)?.toUpperCase();

        if (meridian == 'PM' && hour < 12) {
          hour += 12;
        } else if (meridian == 'AM' && hour == 12) {
          hour = 0;
        }
        return TourTimeOffset(hour.clamp(0, 23), minute.clamp(0, 59));
      }
    } catch (_) {}

    return null;
  }

  /// Extracts times from text containing time ranges (e.g., "8:00 AM - 5:00 PM").
  static List<TourTimeOffset> extractTimesFromText(String text) {
    final results = <TourTimeOffset>[];
    final regex = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?',
      caseSensitive: false,
    );
    for (final match in regex.allMatches(text)) {
      try {
        int hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final meridian = match.group(3)?.toUpperCase();

        if (meridian == 'PM' && hour < 12) {
          hour += 12;
        } else if (meridian == 'AM' && hour == 12) {
          hour = 0;
        }
        results.add(TourTimeOffset(hour.clamp(0, 23), minute.clamp(0, 59)));
      } catch (_) {}
    }
    return results;
  }
}
