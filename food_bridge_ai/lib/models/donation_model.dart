import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

enum DonationStatus { available, matched, accepted, pickedUp, delivered }

enum RiskLabel { low, medium, high }

enum FoodCategory {
  cookedMeal,
  rawProduce,
  packagedFood,
  bakery,
  dairy,
  beverages,
}

extension FoodCategoryExtension on FoodCategory {
  String get displayName {
    switch (this) {
      case FoodCategory.cookedMeal:
        return 'Cooked Meal';
      case FoodCategory.rawProduce:
        return 'Raw Produce';
      case FoodCategory.packagedFood:
        return 'Packaged Food';
      case FoodCategory.bakery:
        return 'Bakery';
      case FoodCategory.dairy:
        return 'Dairy';
      case FoodCategory.beverages:
        return 'Beverages';
    }
  }

  String get apiValue {
    switch (this) {
      case FoodCategory.cookedMeal:
        return 'cooked_meal';
      case FoodCategory.rawProduce:
        return 'raw_produce';
      case FoodCategory.packagedFood:
        return 'packaged';
      case FoodCategory.bakery:
        return 'bakery';
      case FoodCategory.dairy:
        return 'dairy';
      case FoodCategory.beverages:
        return 'beverages';
    }
  }

  String get icon {
    switch (this) {
      case FoodCategory.cookedMeal:
        return '🍲';
      case FoodCategory.rawProduce:
        return '🥕';
      case FoodCategory.packagedFood:
        return '📦';
      case FoodCategory.bakery:
        return '🥖';
      case FoodCategory.dairy:
        return '🥛';
      case FoodCategory.beverages:
        return '🧃';
    }
  }
}

class PickupLocation {
  final double lat;
  final double lng;
  final String address;

  const PickupLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });

  factory PickupLocation.fromMap(Map<String, dynamic> map) {
    return PickupLocation(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'address': address,
      };
}

class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final String title;
  final FoodCategory category;
  final double quantityKg;
  final double storageTemperatureC;
  final double maxFridgeDays;
  final double timeSinceCooked;
  final String description;
  final PickupLocation pickupLocation;
  final DonationStatus status;
  final RiskLabel riskLabel;
  final int riskScore;
  final String? matchedNGOId;
  final String? matchedNGOName;
  final String? assignedVolunteerId;
  final String? assignedVolunteerName;
  final int expiryMinutes;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool volunteerDroppedOff;
  final bool ngoReceived;

  const DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.title,
    required this.category,
    required this.quantityKg,
    required this.storageTemperatureC,
    required this.maxFridgeDays,
    required this.timeSinceCooked,
    required this.description,
    required this.pickupLocation,
    required this.status,
    required this.riskLabel,
    required this.riskScore,
    this.matchedNGOId,
    this.matchedNGOName,
    this.assignedVolunteerId,
    this.assignedVolunteerName,
    required this.expiryMinutes,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.volunteerDroppedOff = false,
    this.ngoReceived = false,
  });

  factory DonationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DonationModel(
      id: doc.id,
      donorId: data['donorId'] ?? '',
      donorName: data['donorName'] ?? '',
      title: data['title'] ?? '',
      category: _categoryFromString(data['category'] ?? 'cooked_meal'),
      quantityKg: (data['quantity_kg'] as num?)?.toDouble() ?? 0.0,
      storageTemperatureC:
          (data['storage_temperature_C'] as num?)?.toDouble() ?? 4.0,
      maxFridgeDays: (data['max_fridge_days'] as num?)?.toDouble() ?? 3.0,
      timeSinceCooked: (data['time_since_cooked'] as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      pickupLocation: data['pickupLocation'] != null
          ? PickupLocation.fromMap(data['pickupLocation'])
          : const PickupLocation(lat: 13.05, lng: 80.21, address: 'Chennai'),
      status: _statusFromString(data['status'] ?? 'available'),
      riskLabel: _riskFromString(data['riskLabel'] ?? 'LOW'),
      riskScore: (data['riskScore'] as num?)?.toInt() ?? 0,
      matchedNGOId: data['matchedNGOId'],
      matchedNGOName: data['matchedNGOName'],
      assignedVolunteerId: data['assignedVolunteerId'],
      assignedVolunteerName: data['assignedVolunteerName'],
      expiryMinutes: (data['expiryMinutes'] as num?)?.toInt() ?? 120,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? 
                 ((data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()).add(
                   Duration(minutes: (data['expiryMinutes'] as num?)?.toInt() ?? 120)
                 ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      volunteerDroppedOff: data['volunteerDroppedOff'] ?? false,
      ngoReceived: data['ngoReceived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'donorId': donorId,
        'donorName': donorName,
        'title': title,
        'category': category.apiValue,
        'quantity_kg': quantityKg,
        'storage_temperature_C': storageTemperatureC,
        'max_fridge_days': maxFridgeDays,
        'time_since_cooked': timeSinceCooked,
        'description': description,
        'pickupLocation': pickupLocation.toMap(),
        'status': _statusToString(status),
        'riskLabel': riskLabel.name.toUpperCase(),
        'riskScore': riskScore,
        'matchedNGOId': matchedNGOId,
        'matchedNGOName': matchedNGOName,
        'assignedVolunteerId': assignedVolunteerId,
        'assignedVolunteerName': assignedVolunteerName,
        'expiryMinutes': expiryMinutes,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'volunteerDroppedOff': volunteerDroppedOff,
        'ngoReceived': ngoReceived,
      };

  DateTime get expiryTime => expiresAt;

  Duration get timeUntilExpiry => expiryTime.difference(DateTime.now());

  bool get isExpired => timeUntilExpiry.isNegative;

  bool get isUrgent =>
      !isExpired && timeUntilExpiry.inMinutes < 120;

  double distanceFrom({double lat = 13.05, double lng = 80.21}) {
    // Euclidean distance approximation in km
    final dlat = pickupLocation.lat - lat;
    final dlng = pickupLocation.lng - lng;
    return sqrt(dlat * dlat + dlng * dlng) * 111.0;
  }

  DonationModel copyWith({
    DonationStatus? status,
    String? matchedNGOId,
    String? matchedNGOName,
    String? assignedVolunteerId,
    String? assignedVolunteerName,
  }) {
    return DonationModel(
      id: id,
      donorId: donorId,
      donorName: donorName,
      title: title,
      category: category,
      quantityKg: quantityKg,
      storageTemperatureC: storageTemperatureC,
      maxFridgeDays: maxFridgeDays,
      timeSinceCooked: timeSinceCooked,
      description: description,
      pickupLocation: pickupLocation,
      status: status ?? this.status,
      riskLabel: riskLabel,
      riskScore: riskScore,
      matchedNGOId: matchedNGOId ?? this.matchedNGOId,
      matchedNGOName: matchedNGOName ?? this.matchedNGOName,
      assignedVolunteerId: assignedVolunteerId ?? this.assignedVolunteerId,
      assignedVolunteerName: assignedVolunteerName ?? this.assignedVolunteerName,
      expiryMinutes: expiryMinutes,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      volunteerDroppedOff: volunteerDroppedOff,
      ngoReceived: ngoReceived,
    );
  }

  static FoodCategory _categoryFromString(String s) {
    switch (s) {
      case 'raw_produce':
        return FoodCategory.rawProduce;
      case 'packaged':
        return FoodCategory.packagedFood;
      case 'bakery':
        return FoodCategory.bakery;
      case 'dairy':
        return FoodCategory.dairy;
      case 'beverages':
        return FoodCategory.beverages;
      default:
        return FoodCategory.cookedMeal;
    }
  }

  static DonationStatus _statusFromString(String s) {
    switch (s) {
      case 'matched':
        return DonationStatus.matched;
      case 'accepted':
        return DonationStatus.accepted;
      case 'picked_up':
        return DonationStatus.pickedUp;
      case 'delivered':
        return DonationStatus.delivered;
      default:
        return DonationStatus.available;
    }
  }

  static String _statusToString(DonationStatus s) {
    switch (s) {
      case DonationStatus.matched:
        return 'matched';
      case DonationStatus.accepted:
        return 'accepted';
      case DonationStatus.pickedUp:
        return 'picked_up';
      case DonationStatus.delivered:
        return 'delivered';
      default:
        return 'available';
    }
  }

  static RiskLabel _riskFromString(String s) {
    switch (s.toUpperCase()) {
      case 'HIGH':
        return RiskLabel.high;
      case 'MEDIUM':
        return RiskLabel.medium;
      default:
        return RiskLabel.low;
    }
  }
}
