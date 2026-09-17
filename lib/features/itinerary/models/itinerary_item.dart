/// Attendance statuses for a passenger at a specific stop.
enum AttendanceStatus { present, absent, late }

/// Status of the itinerary stop.
enum ItineraryStatus { upcoming, ongoing, completed, skipped }

/// Represents one passenger's attendance record at a stop.
class PassengerAttendance {
  final String passengerId;
  final String passengerName;
  AttendanceStatus status;
  String? checkInTime; // set when marked Present or Late

  PassengerAttendance({
    required this.passengerId,
    required this.passengerName,
    this.status = AttendanceStatus.absent,
    this.checkInTime,
  });

  PassengerAttendance copyWith({
    AttendanceStatus? status,
    String? checkInTime,
  }) =>
      PassengerAttendance(
        passengerId: passengerId,
        passengerName: passengerName,
        status: status ?? this.status,
        checkInTime: checkInTime ?? this.checkInTime,
      );
}

/// One destination stop in the tour itinerary.
/// Each stop maintains its own [attendance] map keyed by passengerId.
class ItineraryItem {
  final String id;
  final String destinationName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String notes;

  // ── Added properties for Routing & Map ──
  final double latitude;
  final double longitude;
  final ItineraryStatus status;
  final double? distanceToNext; // in meters
  final int? durationToNext; // in seconds
  final String? encodedPolyline; // for route path to next stop
  final double? routeEndLatitude; // used to detect if next stop moved
  final double? routeEndLongitude;

  /// Attendance records for every registered passenger at this stop.
  final List<PassengerAttendance> attendance;

  ItineraryItem({
    required this.id,
    required this.destinationName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.status = ItineraryStatus.upcoming,
    this.distanceToNext,
    this.durationToNext,
    this.encodedPolyline,
    this.routeEndLatitude,
    this.routeEndLongitude,
    List<PassengerAttendance>? attendance,
  }) : attendance = attendance ?? [];

  // ── Derived counts & Time-based Auto Status ────────────
  int get presentCount =>
      attendance.where((a) => a.status == AttendanceStatus.present).length;
  int get absentCount =>
      attendance.where((a) => a.status == AttendanceStatus.absent).length;
  int get lateCount =>
      attendance.where((a) => a.status == AttendanceStatus.late).length;
  int get totalPassengers => attendance.length;

  static int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      final isAm = parts.length > 1 && parts[1].toUpperCase() == 'AM';
      if (isPm && hour != 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  /// True if the scheduled date/end-time has already elapsed.
  bool get isPastSchedule {
    final now = DateTime.now();
    final stopDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    if (today.isBefore(stopDate)) return false;
    if (today.isAfter(stopDate)) return true;

    // Same day: check end time
    final endMins = _parseTimeToMinutes(endTime);
    if (endMins <= 0) return false;
    final currentMins = now.hour * 60 + now.minute;
    return currentMins >= endMins;
  }

  /// True if current clock time is within [startTime, endTime] on this date.
  bool get isCurrentlyOngoing {
    final now = DateTime.now();
    final stopDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    if (today != stopDate) return false;

    final startMins = _parseTimeToMinutes(startTime);
    final endMins = _parseTimeToMinutes(endTime);
    final currentMins = now.hour * 60 + now.minute;

    return currentMins >= startMins && currentMins < endMins;
  }

  /// Automatically derives the current status (completed when time/date passes, ongoing when active).
  ItineraryStatus get effectiveStatus {
    if (status == ItineraryStatus.completed || status == ItineraryStatus.skipped) {
      return status;
    }
    if (isPastSchedule) {
      return ItineraryStatus.completed;
    }
    if (isCurrentlyOngoing) {
      return ItineraryStatus.ongoing;
    }
    return ItineraryStatus.upcoming;
  }

  ItineraryItem copyWith({
    String? id,
    String? destinationName,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? notes,
    double? latitude,
    double? longitude,
    ItineraryStatus? status,
    double? distanceToNext,
    int? durationToNext,
    String? encodedPolyline,
    double? routeEndLatitude,
    double? routeEndLongitude,
    List<PassengerAttendance>? attendance,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      destinationName: destinationName ?? this.destinationName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      distanceToNext: distanceToNext ?? this.distanceToNext,
      durationToNext: durationToNext ?? this.durationToNext,
      encodedPolyline: encodedPolyline ?? this.encodedPolyline,
      routeEndLatitude: routeEndLatitude ?? this.routeEndLatitude,
      routeEndLongitude: routeEndLongitude ?? this.routeEndLongitude,
      attendance: attendance ?? List.from(this.attendance),
    );
  }
}
