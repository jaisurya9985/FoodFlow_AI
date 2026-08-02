import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { pending, assigned, accepted, completed, declined }

class MatchModel {
  final String id;
  final String donationId;
  final String ngoId;
  final String volunteerId;
  final String volunteerName;
  final int volunteerMatchScore;
  final MatchStatus status;
  final DateTime createdAt;

  const MatchModel({
    required this.id,
    required this.donationId,
    required this.ngoId,
    required this.volunteerId,
    required this.volunteerName,
    required this.volunteerMatchScore,
    required this.status,
    required this.createdAt,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      donationId: data['donationId'] ?? '',
      ngoId: data['ngoId'] ?? '',
      volunteerId: data['volunteerId'] ?? '',
      volunteerName: data['volunteerName'] ?? '',
      volunteerMatchScore: (data['volunteerMatchScore'] as num?)?.toInt() ?? 0,
      status: _statusFromString(data['status'] ?? 'assigned'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'donationId': donationId,
        'ngoId': ngoId,
        'volunteerId': volunteerId,
        'volunteerName': volunteerName,
        'volunteerMatchScore': volunteerMatchScore,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static MatchStatus _statusFromString(String s) {
    switch (s) {
      case 'accepted':
        return MatchStatus.accepted;
      case 'completed':
        return MatchStatus.completed;
      case 'declined':
        return MatchStatus.declined;
      case 'pending':
        return MatchStatus.pending;
      default:
        return MatchStatus.assigned;
    }
  }
}
