import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a tourist's join request for a specific tour (REV-002 Section 6).
///
/// Status flow:
/// `pending` -> `approved` (moves to Tour Roster) OR `rejected`
class JoinRequest {
  final String id;
  final String tourId;
  final String touristId;
  final String touristName;
  final String contactNumber;
  final String emergencyContact;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const JoinRequest({
    required this.id,
    required this.tourId,
    required this.touristId,
    required this.touristName,
    required this.contactNumber,
    this.emergencyContact = '',
    this.status = 'pending',
    this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory JoinRequest.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return JoinRequest(
      id: id,
      tourId: data['tourId'] as String? ?? '',
      touristId: data['touristId'] as String? ?? id,
      touristName: data['touristName'] as String? ?? 'Unnamed Tourist',
      contactNumber: data['contactNumber'] as String? ?? '',
      emergencyContact: data['emergencyContact'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: parseDate(data['createdAt']),
      reviewedAt: parseDate(data['reviewedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tourId': tourId,
      'touristId': touristId,
      'touristName': touristName.trim(),
      'contactNumber': contactNumber.trim(),
      'emergencyContact': emergencyContact.trim(),
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }
}
