enum AttendanceStatus { present, absent, pending }

class TouristAttendance {
  final String id;
  final String touristName;
  final AttendanceStatus status;
  final DateTime? timestamp;

  TouristAttendance({
    required this.id,
    required this.touristName,
    this.status = AttendanceStatus.pending,
    this.timestamp,
  });

  TouristAttendance copyWith({
    String? id,
    String? touristName,
    AttendanceStatus? status,
    DateTime? timestamp,
  }) {
    return TouristAttendance(
      id: id ?? this.id,
      touristName: touristName ?? this.touristName,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
