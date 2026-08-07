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

  // ── Derived counts ──────────────────────────────────────
  int get presentCount =>
      attendance.where((a) => a.status == AttendanceStatus.present).length;
  int get absentCount =>
      attendance.where((a) => a.status == AttendanceStatus.absent).length;
  int get lateCount =>
      attendance.where((a) => a.status == AttendanceStatus.late).length;
  int get totalPassengers => attendance.length;

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
