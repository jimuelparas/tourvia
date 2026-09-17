import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/tour_status_resolver.dart';

export '../services/tour_status_resolver.dart' show TourStatus;

/// The 3-state lifecycle according to the tour schedule.
enum TourScheduleStatus {
  ready, // currentDate < startDate (READY / UPCOMING)
  active, // startDate <= currentDate <= endDate (ACTIVE)
  completed, // currentDate > endDate or explicitly completed (COMPLETED)
}

/// Represents a distinct tour entity in Tourvia (REV-002 & REV-004).
///
/// Supports multi-tour pre-planning, date conflict detection,
/// auto-generated access codes, and a 3-stage lifecycle:
/// `upcoming` -> `active` -> `completed`.
class Tour {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String schedule;
  final String guideId;
  final String guideName;
  final String status; // Raw Firestore status string: 'upcoming' | 'active' | 'completed'
  final String accessCode;
  final int touristCount;
  final String? startTime; // e.g. "08:00 AM" or "08:00"
  final String? endTime; // e.g. "05:00 PM" or "17:00"
  final DateTime? endedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Tour({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.schedule = '',
    required this.guideId,
    required this.guideName,
    this.status = 'upcoming',
    required this.accessCode,
    this.touristCount = 0,
    this.startTime,
    this.endTime,
    this.endedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  // ── Centralized Status Resolution (REV-004) ────────────────

  /// Evaluates effective status at the given [now] (or DateTime.now()).
  TourStatus resolveStatus([DateTime? now]) =>
      TourStatusResolver.resolve(this, now);

  /// Centralized Single Source of Truth for this tour's current status.
  TourStatus get effectiveStatus => TourStatusResolver.resolve(this);

  bool get isUpcoming => effectiveStatus == TourStatus.upcoming;
  bool get isActive => effectiveStatus == TourStatus.active;
  bool get isCompleted => effectiveStatus == TourStatus.completed;

  /// Backward-compatible schedule status mapping.
  TourScheduleStatus get scheduleStatus {
    switch (effectiveStatus) {
      case TourStatus.upcoming:
        return TourScheduleStatus.ready;
      case TourStatus.active:
        return TourScheduleStatus.active;
      case TourStatus.completed:
        return TourScheduleStatus.completed;
    }
  }

  bool get isReady => isUpcoming;
  bool get isScheduleActive => isActive;
  bool get isScheduleCompleted => isCompleted;

  /// Clamped current day progress for this tour (1-indexed).
  /// When tour has not started yet (READY/UPCOMING), returns 1.
  /// When tour is active, returns current day offset clamped to [1, totalDays].
  /// When completed, returns totalDays.
  int get currentScheduleDay {
    if (isUpcoming) return 1;
    if (isCompleted) return totalDays;
    final now = DateTime.now();
    return dayNumberForDate(now).clamp(1, totalDays);
  }

  /// Formatted date string (e.g. "Sep 15, 2026")
  static String formatDate(DateTime d) {
    return '${_monthName(d.month)} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  /// Formatted date range string (e.g. "Oct 01, 2026 – Oct 05, 2026")
  String get formattedDateRange {
    final s = formatDate(startDate);
    final e = formatDate(endDate);
    return '$s – $e';
  }

  /// Calculates the day number offset for a given date within this tour (1-indexed).
  int dayNumberForDate(DateTime date) {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final difference = targetDay.difference(startDay).inDays;
    return difference + 1;
  }

  /// Checks whether this tour's date range overlaps with another date range.
  /// Overlap condition: NewStart <= ExistingEnd && NewEnd >= ExistingStart
  bool overlapsWith(DateTime newStart, DateTime newEnd) {
    // Only check active or upcoming tours for conflicts (ignore completed)
    if (isCompleted) return false;

    final s1 = DateTime(startDate.year, startDate.month, startDate.day);
    final e1 = DateTime(endDate.year, endDate.month, endDate.day);
    final s2 = DateTime(newStart.year, newStart.month, newStart.day);
    final e2 = DateTime(newEnd.year, newEnd.month, newEnd.day);

    return !s2.isAfter(e1) && !e2.isBefore(s1);
  }

  factory Tour.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final start = parseDate(data['startDate']);
    final end = parseDate(data['endDate']);
    final totalDaysNum = (data['totalDays'] as num?)?.toInt();
    final days = totalDaysNum ??
        ((end.difference(start).inDays) + 1).clamp(1, 365);

    return Tour(
      id: id,
      name: data['name'] as String? ?? 'Unnamed Tour',
      startDate: start,
      endDate: end,
      totalDays: days,
      schedule: data['schedule'] as String? ?? '',
      guideId: data['guideId'] as String? ?? '',
      guideName: data['guideName'] as String? ?? '',
      status: data['status'] as String? ?? 'upcoming',
      accessCode: data['accessCode'] as String? ?? '',
      touristCount: (data['touristCount'] as num?)?.toInt() ?? 0,
      startTime: data['startTime'] as String? ?? data['tourStartTime'] as String?,
      endTime: data['endTime'] as String? ?? data['tourEndTime'] as String?,
      endedAt: parseDateNullable(data['endedAt']),
      completedAt: parseDateNullable(data['completedAt']),
      createdAt: parseDateNullable(data['createdAt']),
      updatedAt: parseDateNullable(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'schedule': schedule.trim(),
      'guideId': guideId,
      'guideName': guideName,
      'status': status,
      'accessCode': accessCode.toUpperCase().trim(),
      'touristCount': touristCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (startTime != null && startTime!.trim().isNotEmpty) {
      map['startTime'] = startTime!.trim();
    }
    if (endTime != null && endTime!.trim().isNotEmpty) {
      map['endTime'] = endTime!.trim();
    }
    if (endedAt != null) {
      map['endedAt'] = Timestamp.fromDate(endedAt!);
    }
    if (completedAt != null) {
      map['completedAt'] = Timestamp.fromDate(completedAt!);
    }

    return map;
  }

  Tour copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    String? schedule,
    String? status,
    String? accessCode,
    int? touristCount,
    String? startTime,
    String? endTime,
    DateTime? endedAt,
    DateTime? completedAt,
  }) {
    return Tour(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      schedule: schedule ?? this.schedule,
      guideId: guideId,
      guideName: guideName,
      status: status ?? this.status,
      accessCode: accessCode ?? this.accessCode,
      touristCount: touristCount ?? this.touristCount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      endedAt: endedAt ?? this.endedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }
}
