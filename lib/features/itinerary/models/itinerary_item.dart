/// Attendance statuses for a passenger at a specific stop.
enum AttendanceStatus { present, absent, late }

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

  /// Attendance records for every registered passenger at this stop.
  final List<PassengerAttendance> attendance;

  ItineraryItem({
    required this.id,
    required this.destinationName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes = '',
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
    List<PassengerAttendance>? attendance,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      destinationName: destinationName ?? this.destinationName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      attendance: attendance ?? List.from(this.attendance),
    );
  }
}
