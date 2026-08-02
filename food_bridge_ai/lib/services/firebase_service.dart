import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/donation_model.dart';
import '../models/match_model.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;

  // ─── Users ──────────────────────────────────────────────────────────────────

  static Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  static Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  static Future<void> updateUserLocation(String uid, UserLocation loc) async {
    await _db.collection('users').doc(uid).update({
      'location': loc.toMap(),
    });
  }

  static Future<void> updateAvailability(String uid, bool isAvailable) async {
    await _db
        .collection('users')
        .doc(uid)
        .set({'isAvailable': isAvailable}, SetOptions(merge: true));
  }

  static Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  static Stream<List<UserModel>> volunteersStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'volunteer')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }

  static Stream<List<UserModel>> leaderboardStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'volunteer')
        .orderBy('points', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }

  // ─── Donations ──────────────────────────────────────────────────────────────

  static Future<String> createDonation(DonationModel donation) async {
    final ref = _db.collection('donations').doc();
    final data = donation.toMap();
    data['id'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  static Future<void> updateDonationStatus(
    String donationId,
    DonationStatus status, {
    String? matchedNGOId,
    String? matchedNGOName,
    String? assignedVolunteerId,
    String? assignedVolunteerName,
  }) async {
    final data = <String, dynamic>{
      'status': _statusToString(status),
      'updatedAt': Timestamp.now(),
    };
    if (matchedNGOId != null) data['matchedNGOId'] = matchedNGOId;
    if (matchedNGOName != null) data['matchedNGOName'] = matchedNGOName;
    if (assignedVolunteerId != null) {
      data['assignedVolunteerId'] = assignedVolunteerId;
    }
    if (assignedVolunteerName != null) {
      data['assignedVolunteerName'] = assignedVolunteerName;
    }
    await _db.collection('donations').doc(donationId).update(data);
  }

  static Future<void> acceptTask(String donationId) async {
    await _db.collection('donations').doc(donationId).update({
      'status': 'accepted',
      'updatedAt': Timestamp.now(),
    });
  }

  static Future<void> declineTask(String donationId) async {
    await _db.collection('donations').doc(donationId).update({
      'status': 'matched',
      'assignedVolunteerId': FieldValue.delete(),
      'assignedVolunteerName': FieldValue.delete(),
      'updatedAt': Timestamp.now(),
      'volunteerDroppedOff': false,
      'ngoReceived': false,
    });
  }

  static Future<bool> volunteerConfirmDropoff(String docId) async {
    try {
      final docRef = _db.collection('donations').doc(docId);
      bool isFullyDelivered = false;
      double kgToAward = 0.0;
      String? volId;
      String? donId;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Donation not found');

        final data = snap.data()!;
        final ngoReceived = data['ngoReceived'] == true;
        volId = data['assignedVolunteerId'] as String?;
        donId = data['donorId'] as String?;
        kgToAward = (data['quantity_kg'] as num?)?.toDouble() ?? 0.0;

        if (ngoReceived) {
          isFullyDelivered = true;
          tx.update(docRef, {
            'volunteerDroppedOff': true,
            'status': 'delivered',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(docRef, {
            'volunteerDroppedOff': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (isFullyDelivered && volId != null && donId != null) {
        await awardImpact(
            donationId: docId,
            volunteerId: volId!,
            donorId: donId!,
            kg: kgToAward);
      }
      return true;
    } catch (e) {
      debugPrint('volunteerConfirmDropoff error: $e');
      return false;
    }
  }

  static Future<bool> ngoConfirmReceipt(String docId) async {
    try {
      final docRef = _db.collection('donations').doc(docId);
      bool isFullyDelivered = false;
      double kgToAward = 0.0;
      String? volId;
      String? donId;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Donation not found');

        final data = snap.data()!;
        final volunteerDroppedOff = data['volunteerDroppedOff'] == true;
        volId = data['assignedVolunteerId'] as String?;
        donId = data['donorId'] as String?;
        kgToAward = (data['quantity_kg'] as num?)?.toDouble() ?? 0.0;

        if (volunteerDroppedOff) {
          isFullyDelivered = true;
          tx.update(docRef, {
            'ngoReceived': true,
            'status': 'delivered',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(docRef, {
            'ngoReceived': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (isFullyDelivered && volId != null && donId != null) {
        await awardImpact(
            donationId: docId,
            volunteerId: volId!,
            donorId: donId!,
            kg: kgToAward);
      }
      return true;
    } catch (e) {
      debugPrint('ngoConfirmReceipt error: $e');
      return false;
    }
  }

  static Stream<List<DonationModel>> donorDonationsStream(String donorId) {
    if (donorId.isEmpty) return Stream.value([]);
    
    // Fetch and filter in memory to avoid composite index requirements.
    return _db
        .collection('donations')
        .snapshots()
        .map((snap) {
      try {
        return snap.docs
            .map((d) => DonationModel.fromFirestore(d))
            .where((d) => d.donorId == donorId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        debugPrint('donorDonationsStream parse error: $e');
        return [];
      }
    });
  }

  static Stream<List<DonationModel>> availableDonationsStream() {
    return _db
        .collection('donations')
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final list = <DonationModel>[];
      for (var d in snap.docs) {
        try {
          final model = DonationModel.fromFirestore(d);
          if (model.createdAt.add(Duration(minutes: model.expiryMinutes)).isAfter(now)) {
            list.add(model);
          }
        } catch (e) {
          debugPrint('Error parsing donation ${d.id}: $e');
        }
      }
      list.sort((a, b) => b.riskScore.compareTo(a.riskScore));
      return list;
    });
  }

  static Future<void> cleanupExpiredDonations() async {
    final now = DateTime.now();
    try {
      final snap = await _db
          .collection('donations')
          .where('status', whereIn: ['available', 'matched'])
          .get();
          
      final batch = _db.batch();
      int count = 0;
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final expiry = (data['expiryMinutes'] as num).toInt();
        
        if (createdAt.add(Duration(minutes: expiry)).isBefore(now)) {
          batch.delete(doc.reference);
          count++;
        }
      }
      
      if (count > 0) {
        await batch.commit();
        debugPrint('Cleaned up $count expired donations');
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  static Stream<List<DonationModel>> allActiveDonationsStream() {
    return _db
        .collection('donations')
        .where('status', whereIn: ['available', 'matched'])
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map((d) => DonationModel.fromFirestore(d))
          .where((d) => d.createdAt.add(Duration(minutes: d.expiryMinutes)).isAfter(now))
          .toList();
    });
  }

  static Stream<List<DonationModel>> ngoClaimedDonationsStream(String ngoId) {
    return _db
        .collection('donations')
        .where('matchedNGOId', isEqualTo: ngoId)
        .snapshots()
        .map((snap) {
      final list = <DonationModel>[];
      for (var d in snap.docs) {
        try {
          list.add(DonationModel.fromFirestore(d));
        } catch (e) {
          debugPrint('Error parsing NGO donation ${d.id}: $e');
        }
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  static Stream<List<DonationModel>> volunteerTasksStream(String volunteerId) {
    if (volunteerId.isEmpty) return Stream.value([]);
    
    // Fetch and filter in memory to avoid composite index requirements.
    return _db
        .collection('donations')
        .snapshots()
        .map((snap) {
      try {
        final now = DateTime.now();
        return snap.docs
            .map((d) => DonationModel.fromFirestore(d))
            .where((d) =>
                d.assignedVolunteerId == volunteerId &&
                (d.status == DonationStatus.matched ||
                    d.status == DonationStatus.accepted ||
                    d.status == DonationStatus.pickedUp) &&
                d.createdAt.add(Duration(minutes: d.expiryMinutes)).isAfter(now))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } catch (e) {
        debugPrint('volunteerTasksStream parse error: $e');
        return [];
      }
    });
  }

  static Stream<List<DonationModel>> completedDonationsStream(String uid, UserRole role) {
    if (uid.isEmpty) return Stream.value([]);
    
    final field = (role == UserRole.donor) ? 'donorId' : 'assignedVolunteerId';
    
    return _db
        .collection('donations')
        .where(field, isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snap) => snap.docs.map((d) => DonationModel.fromFirestore(d)).toList());
  }

  // ─── Matches ────────────────────────────────────────────────────────────────

  static Future<String> createMatch(MatchModel match) async {
    final ref = _db.collection('matches').doc();
    await ref.set(match.toMap());
    return ref.id;
  }

  // ─── Points / Gamification ──────────────────────────────────────────────────

  static Future<void> awardImpact({
    required String donationId,
    required String volunteerId,
    required String donorId,
    required double kg,
    int points = 50,
  }) async {
    final batch = _db.batch();
    
    // Update Volunteer
    batch.update(_db.collection('users').doc(volunteerId), {
      'points': FieldValue.increment(points),
      'deliveriesDone': FieldValue.increment(1),
    });
    
    // Update Donor
    batch.update(_db.collection('users').doc(donorId), {
      'points': FieldValue.increment(points ~/ 2), // Donors get half points for providing
      'deliveriesDone': FieldValue.increment(1), // Reuse deliveriesDone as 'activities' or add donationsDone
    });
    
    // Mark donation as processed for impact if needed, 
    // though status=delivered is usually enough.
    
    await batch.commit();
  }

  static Future<void> updateVolunteerRating(String uid, double newStar) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final user = UserModel.fromFirestore(doc);
    
    // Calculate new average
    // If it's their first rating, we replace the default 5.0
    // Otherwise we average it in.
    double updatedRating;
    if (user.deliveriesDone == 0) {
      updatedRating = newStar;
    } else {
      updatedRating = ((user.rating * user.deliveriesDone) + newStar) / (user.deliveriesDone + 1);
    }

    await _db.collection('users').doc(uid).update({
      'rating': updatedRating,
    });
  }

  // ─── Seed Data ──────────────────────────────────────────────────────────────

  static Future<bool> isSeeded() async {
    final doc = await _db.collection('meta').doc('seed').get();
    return doc.exists && (doc.data()?['seeded'] == true);
  }

  static Future<void> seedDemoData() async {
    final batch = _db.batch();

    // Mark as seeded
    batch.set(_db.collection('meta').doc('seed'), {'seeded': true});

    // Donors
    final donors = [
      {
        'uid': 'donor_taj',
        'name': 'Hotel Taj Chennai',
        'email': 'taj@foodbridge.ai',
        'phone': '9876543210',
        'role': 'donor',
        'orgName': 'Taj Hotels',
        'location': {'lat': 13.0603, 'lng': 80.2496},
        'rating': 4.9,
        'deliveriesDone': 0,
        'hasVehicle': false,
        'isAvailable': true,
        'points': 0,
        'createdAt': Timestamp.now(),
      },
      {
        'uid': 'donor_biryani',
        'name': 'Biryani House',
        'email': 'biryani@foodbridge.ai',
        'phone': '9876543211',
        'role': 'donor',
        'orgName': 'Biryani House Restaurant',
        'location': {'lat': 13.0569, 'lng': 80.2425},
        'rating': 4.7,
        'deliveriesDone': 0,
        'hasVehicle': false,
        'isAvailable': true,
        'points': 0,
        'createdAt': Timestamp.now(),
      },
      {
        'uid': 'donor_wedding',
        'name': 'Wedding Palace',
        'email': 'wedding@foodbridge.ai',
        'phone': '9876543212',
        'role': 'donor',
        'location': {'lat': 13.0450, 'lng': 80.2300},
        'rating': 4.8,
        'deliveriesDone': 0,
        'hasVehicle': false,
        'isAvailable': true,
        'points': 0,
        'createdAt': Timestamp.now(),
      },
    ];

    for (final d in donors) {
      batch.set(_db.collection('users').doc(d['uid'] as String), d);
    }

    // NGOs
    final ngos = [
      {
        'uid': 'ngo_greenhope',
        'name': 'GreenHope Foundation',
        'email': 'greenhope@foodbridge.ai',
        'phone': '9876543220',
        'role': 'ngo',
        'orgName': 'GreenHope Foundation',
        'location': {'lat': 13.0550, 'lng': 80.2320},
        'rating': 4.9,
        'deliveriesDone': 0,
        'hasVehicle': true,
        'isAvailable': true,
        'points': 0,
        'createdAt': Timestamp.now(),
      },
      {
        'uid': 'ngo_annadanam',
        'name': 'Annadanam Trust',
        'email': 'annadanam@foodbridge.ai',
        'phone': '9876543221',
        'role': 'ngo',
        'orgName': 'Annadanam Trust',
        'location': {'lat': 13.0620, 'lng': 80.2450},
        'rating': 4.8,
        'deliveriesDone': 0,
        'hasVehicle': true,
        'isAvailable': true,
        'points': 0,
        'createdAt': Timestamp.now(),
      },
    ];

    for (final n in ngos) {
      batch.set(_db.collection('users').doc(n['uid'] as String), n);
    }

    // Volunteers
    final volunteers = [
      {
        'uid': 'vol_priya',
        'name': 'Priya M.',
        'email': 'priya@foodbridge.ai',
        'phone': '9876543230',
        'role': 'volunteer',
        'location': {'lat': 13.0510, 'lng': 80.2380},
        'rating': 4.8,
        'deliveriesDone': 72,
        'hasVehicle': true,
        'isAvailable': true,
        'points': 3600,
        'createdAt': Timestamp.now(),
      },
      {
        'uid': 'vol_rahul',
        'name': 'Rahul K.',
        'email': 'rahul@foodbridge.ai',
        'phone': '9876543231',
        'role': 'volunteer',
        'location': {'lat': 13.0590, 'lng': 80.2460},
        'rating': 4.5,
        'deliveriesDone': 45,
        'hasVehicle': true,
        'isAvailable': true,
        'points': 2250,
        'createdAt': Timestamp.now(),
      },
      {
        'uid': 'vol_ananya',
        'name': 'Ananya S.',
        'email': 'ananya@foodbridge.ai',
        'phone': '9876543232',
        'role': 'volunteer',
        'location': {'lat': 13.0480, 'lng': 80.2270},
        'rating': 4.2,
        'deliveriesDone': 23,
        'hasVehicle': false,
        'isAvailable': true,
        'points': 1150,
        'createdAt': Timestamp.now(),
      },
    ];

    for (final v in volunteers) {
      batch.set(_db.collection('users').doc(v['uid'] as String), v);
    }

    await batch.commit();

    // Donations (separate batch)
    final batch2 = _db.batch();

    final donations = [
      {
        'donorId': 'donor_taj',
        'donorName': 'Hotel Taj Chennai',
        'title': 'Chicken Biryani (Fresh)',
        'category': 'cooked_meal',
        'quantity_kg': 40.0,
        'storage_temperature_C': 28.0,
        'max_fridge_days': 1.0,
        'time_since_cooked': 3.0,
        'description':
            'Freshly cooked chicken biryani from today\'s lunch service. Packed in food-grade containers.',
        'pickupLocation': {
          'lat': 13.0603,
          'lng': 80.2496,
          'address': '1 Anna Salai, Chennai - 600002',
        },
        'status': 'available',
        'riskLabel': 'HIGH',
        'riskScore': 2,
        'expiryMinutes': 90,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'donorId': 'donor_biryani',
        'donorName': 'Biryani House',
        'title': 'Fresh Mixed Vegetables',
        'category': 'raw_produce',
        'quantity_kg': 25.0,
        'storage_temperature_C': 8.0,
        'max_fridge_days': 5.0,
        'time_since_cooked': 0.0,
        'description':
            'Seasonal vegetables: carrots, beans, tomatoes, and greens. Fresh from morning delivery.',
        'pickupLocation': {
          'lat': 13.0569,
          'lng': 80.2425,
          'address': 'T. Nagar, Chennai - 600017',
        },
        'status': 'available',
        'riskLabel': 'LOW',
        'riskScore': 0,
        'expiryMinutes': 480,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
      {
        'donorId': 'donor_wedding',
        'donorName': 'Wedding Palace',
        'title': 'Assorted Bread Loaves',
        'category': 'bakery',
        'quantity_kg': 15.0,
        'storage_temperature_C': 22.0,
        'max_fridge_days': 2.0,
        'time_since_cooked': 5.0,
        'description':
            'Assorted bread loaves from this morning\'s bakery. Includes white, wheat, and multigrain.',
        'pickupLocation': {
          'lat': 13.0450,
          'lng': 80.2300,
          'address': 'Adyar, Chennai - 600020',
        },
        'status': 'available',
        'riskLabel': 'MEDIUM',
        'riskScore': 1,
        'expiryMinutes': 240,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      },
    ];

    for (final d in donations) {
      final ref = _db.collection('donations').doc();
      batch2.set(ref, d);
    }

    await batch2.commit();
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

  static Future<void> seedDataForUser(String uid, UserRole role) async {
    final batch = _db.batch();

    if (role == UserRole.donor) {
      // Create using the actual model to ensure snake_case fields are correct
      final donation1 = DonationModel(
        id: 'test_d1_$uid',
        donorId: uid,
        donorName: 'Your Test Account',
        title: 'Fresh Garden Veggies',
        category: FoodCategory.rawProduce,
        quantityKg: 5.5,
        storageTemperatureC: 4.0,
        maxFridgeDays: 5.0,
        timeSinceCooked: 0.0,
        description: 'Recently harvested tomatoes and cucumbers',
        pickupLocation: const PickupLocation(lat: 13.06, lng: 80.25, address: 'My Neighborhood'),
        status: DonationStatus.available,
        riskLabel: RiskLabel.low,
        riskScore: 10,
        expiryMinutes: 1440,
        expiresAt: DateTime.now().add(const Duration(minutes: 1440)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final donation2 = DonationModel(
        id: 'test_d2_$uid',
        donorId: uid,
        donorName: 'Your Test Account',
        title: 'Bakery Batch (Evening)',
        category: FoodCategory.bakery,
        quantityKg: 3.0,
        storageTemperatureC: 22.0,
        maxFridgeDays: 2.0,
        timeSinceCooked: 5.0,
        description: 'Assorted breads from our evening surplus',
        pickupLocation: const PickupLocation(lat: 13.07, lng: 80.26, address: 'Near Bakery St'),
        status: DonationStatus.matched,
        matchedNGOId: 'demo_ngo',
        matchedNGOName: 'Global Relief',
        riskLabel: RiskLabel.low,
        riskScore: 25,
        expiryMinutes: 360,
        expiresAt: DateTime.now().add(const Duration(minutes: 360)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      batch.set(_db.collection('donations').doc(donation1.id), donation1.toMap());
      batch.set(_db.collection('donations').doc(donation2.id), donation2.toMap());
      
    } else if (role == UserRole.volunteer) {
      final task = DonationModel(
        id: 'test_task_$uid',
        donorId: 'demo_donor',
        donorName: 'Green Cafe',
        title: 'Volunteer Task: Packed Lunches',
        category: FoodCategory.cookedMeal,
        quantityKg: 8.0,
        storageTemperatureC: 4.0,
        maxFridgeDays: 1.0,
        timeSinceCooked: 2.0,
        description: '15 packs of vegetarian meals for distribution',
        pickupLocation: const PickupLocation(lat: 13.05, lng: 80.24, address: 'Downtown Cafe'),
        status: DonationStatus.matched,
        assignedVolunteerId: uid,
        assignedVolunteerName: 'You',
        riskLabel: RiskLabel.medium,
        riskScore: 45,
        expiryMinutes: 180,
        expiresAt: DateTime.now().add(const Duration(minutes: 180)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      batch.set(_db.collection('donations').doc(task.id), task.toMap());
    }

    await batch.commit();
  }
}
