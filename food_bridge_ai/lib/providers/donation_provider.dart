import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/donation_model.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/ml_service.dart';

class DonationProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _lastRiskResult;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get lastRiskResult => _lastRiskResult;

  DonationProvider() {
    // Lazy cleanup on startup
    cleanupExpired();
  }

  // ML risk prediction
  Future<Map<String, dynamic>> predictRisk({
    required String category,
    required double storageTemperatureC,
    required double maxFridgeDays,
    required double timeSinceCooked,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await MLService.predictFoodRisk(
      category: category,
      storageTemperatureC: storageTemperatureC,
      maxFridgeDays: maxFridgeDays,
      timeSinceCooked: timeSinceCooked,
    );

    _lastRiskResult = result;
    _isLoading = false;
    notifyListeners();
    return result;
  }

  // Post a donation
  Future<String?> postDonation(DonationModel donation) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final id = await FirebaseService.createDonation(donation);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      throw Exception('Failed to post donation');
    }
  }

  // NGO starts a server-side volunteer search.
  Future<bool> requestVolunteerSearch({
    required String donationId,
    required String ngoId,
    required String ngoName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseService.requestVolunteerSearch(
        donationId: donationId,
        ngoId: ngoId,
        ngoName: ngoName,
      );
      return true;
    } catch (_) {
      _error = 'Could not start volunteer search.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy immediate matcher. New claims use requestVolunteerSearch above.
  Future<UserModel?> claimDonation({
    required String donationId,
    required String ngoId,
    required String ngoName,
    required DonationModel donation,
    required List<UserModel> availableVolunteers,
    bool Function()? isCancelled,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (availableVolunteers.isEmpty) {
      _error = 'No volunteers available in your area right now.';
      _isLoading = false;
      notifyListeners();
      return null;
    }

    try {
      // Build volunteer list for ML
      final volList = availableVolunteers.map((v) {
        return {
          'vol_id': v.uid,
          'lat': v.location?.lat ?? 13.05,
          'lng': v.location?.lng ?? 80.21,
          'rating': v.rating,
          'deliveries_done': v.deliveriesDone,
          'has_vehicle': v.hasVehicle,
          'is_available': v.isAvailable,
        };
      }).toList();

      UserModel? bestVolunteer;

      final matches = await MLService.matchVolunteers(
        pickupLat: donation.pickupLocation.lat,
        pickupLng: donation.pickupLocation.lng,
        foodWeightKg: donation.quantityKg,
        riskScore: donation.riskScore,
        expiryHours: donation.expiryMinutes / 60.0,
        volunteers: volList,
      );

      if (isCancelled != null && isCancelled()) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      if (matches.isNotEmpty) {
        final bestId = matches.first['vol_id'] as String;
        for (final volunteer in availableVolunteers) {
          if (volunteer.uid == bestId) {
            bestVolunteer = volunteer;
            break;
          }
        }
      }

      // Fallback if ML didn't return a valid ID or no matches
      bestVolunteer ??=
          availableVolunteers.isNotEmpty ? availableVolunteers.first : null;

      if (bestVolunteer == null) {
        _error = 'Could not find a suitable volunteer.';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final matchScore = matches.isNotEmpty
          ? (matches.first['match_score'] as int)
          : 85;

      // FINAL CHECK BEFORE DATABASE UPDATE
      if (isCancelled != null && isCancelled()) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Update donation in Firestore ONLY if we have a volunteer and NOT cancelled
      await FirebaseService.updateDonationStatus(
        donationId,
        DonationStatus.matched,
        matchedNGOId: ngoId,
        matchedNGOName: ngoName,
        assignedVolunteerId: bestVolunteer.uid,
        assignedVolunteerName: bestVolunteer.name,
      );

      // Create match doc
      final match = MatchModel(
        id: const Uuid().v4(),
        donationId: donationId,
        ngoId: ngoId,
        volunteerId: bestVolunteer.uid,
        volunteerName: bestVolunteer.name,
        volunteerMatchScore: matchScore,
        status: MatchStatus.assigned,
        createdAt: DateTime.now(),
      );
      await FirebaseService.createMatch(match);

      _isLoading = false;
      notifyListeners();
      return bestVolunteer;
    } catch (e) {
      _error = 'Failed to assign volunteer';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Submit volunteer rating
  Future<bool> rateVolunteer({
    required String volunteerId,
    required double rating,
  }) async {
    try {
      await FirebaseService.updateVolunteerRating(volunteerId, rating);
      return true;
    } catch (e) {
      _error = 'Failed to submit rating.';
      notifyListeners();
      return false;
    }
  }

  // Volunteer accepts a task
  Future<bool> acceptTask(String donationId) async {
    try {
      await FirebaseService.acceptTask(donationId);
      return true;
    } catch (e) {
      _error = 'Failed to accept task.';
      notifyListeners();
      return false;
    }
  }

  // Volunteer marks as picked up
  Future<bool> markPickedUp(String donationId) async {
    try {
      await FirebaseService.updateDonationStatus(
          donationId, DonationStatus.pickedUp);
      return true;
    } catch (e) {
      _error = 'Failed to update status.';
      notifyListeners();
      return false;
    }
  }

  // Volunteer marks drop-off
  Future<bool> volunteerConfirmDropoff(String donationId) async {
    try {
      final ok = await FirebaseService.volunteerConfirmDropoff(donationId);
      if (!ok) {
        _error = 'Failed to confirm drop-off.';
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = 'Failed to confirm drop-off.';
      notifyListeners();
      return false;
    }
  }

  // NGO marks receipt
  Future<bool> ngoConfirmReceipt(String donationId) async {
    try {
      final ok = await FirebaseService.ngoConfirmReceipt(donationId);
      if (!ok) {
        _error = 'Failed to confirm receipt.';
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = 'Failed to confirm receipt.';
      notifyListeners();
      return false;
    }
  }

  Future<void> cleanupExpired() async {
    await FirebaseService.cleanupExpiredDonations();
  }

  Stream<List<DonationModel>> donorStream(String donorId) =>
      FirebaseService.donorDonationsStream(donorId);

  Stream<List<DonationModel>> get availableStream =>
      FirebaseService.availableDonationsStream();

  Stream<List<DonationModel>> ngoClaimedStream(String ngoId) =>
      FirebaseService.ngoClaimedDonationsStream(ngoId);

  Stream<List<DonationModel>> volunteerTasksStream(String volunteerId) =>
      FirebaseService.volunteerTasksStream(volunteerId);

  Stream<List<DonationModel>> get allActiveStream =>
      FirebaseService.allActiveDonationsStream();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
