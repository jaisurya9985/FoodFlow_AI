import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { donor, ngo, volunteer }

class UserLocation {
  final double lat;
  final double lng;

  const UserLocation({required this.lat, required this.lng});

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? orgName;
  final UserLocation? location;
  final double rating;
  final int deliveriesDone;
  final bool hasVehicle;
  final bool isAvailable;
  final int points;
  final String? fcmToken;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.orgName,
    this.location,
    this.rating = 5.0,
    this.deliveriesDone = 0,
    this.hasVehicle = false,
    this.isAvailable = true,
    this.points = 0,
    this.fcmToken,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: _roleFromString(data['role'] ?? 'donor'),
      orgName: data['orgName'],
      location: data['location'] != null
          ? UserLocation.fromMap(data['location'])
          : null,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      deliveriesDone: (data['deliveriesDone'] as num?)?.toInt() ?? 0,
      hasVehicle: data['hasVehicle'] ?? false,
      isAvailable: data['isAvailable'] ?? true,
      points: (data['points'] as num?)?.toInt() ?? 0,
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'orgName': orgName,
        'location': location?.toMap(),
        'rating': rating,
        'deliveriesDone': deliveriesDone,
        'hasVehicle': hasVehicle,
        'isAvailable': isAvailable,
        'points': points,
        'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  UserModel copyWith({
    String? name,
    String? phone,
    String? orgName,
    UserLocation? location,
    double? rating,
    int? deliveriesDone,
    bool? hasVehicle,
    bool? isAvailable,
    int? points,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      orgName: orgName ?? this.orgName,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      deliveriesDone: deliveriesDone ?? this.deliveriesDone,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      isAvailable: isAvailable ?? this.isAvailable,
      points: points ?? this.points,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
    );
  }

  static UserRole _roleFromString(String s) {
    switch (s) {
      case 'ngo':
        return UserRole.ngo;
      case 'volunteer':
        return UserRole.volunteer;
      default:
        return UserRole.donor;
    }
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }
}
