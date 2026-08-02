import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  void setUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();
    _currentUser = await FirebaseService.getUser(uid);
    _isLoading = false;
    notifyListeners();
  }

  Stream<UserModel?> userStream(String uid) =>
      FirebaseService.userStream(uid);

  Future<void> updateAvailability(bool isAvailable) async {
    if (_currentUser == null) return;
    await FirebaseService.updateAvailability(_currentUser!.uid, isAvailable);
    _currentUser = _currentUser!.copyWith(isAvailable: isAvailable);
    notifyListeners();
  }

  // Impact stats are aggregated via Streams in the UI for real-time accuracy
  double get totalKgDonated => 0.0; 
  int get mealsProvided => 0;
  double get co2Saved => 0.0;

  // Badges
  List<String> get earnedBadges {
    final deliveries = _currentUser?.deliveriesDone ?? 0;
    final badges = <String>[];
    if (deliveries >= 10) badges.add('Food Hero');
    if (deliveries >= 50) badges.add('Community Champion');
    if (deliveries >= 100) badges.add('Zero Waste Warrior');
    if (deliveries >= 500) badges.add('Legend');
    return badges;
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? orgName,
    UserLocation? location,
  }) async {
    if (_currentUser == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (orgName != null) updates['orgName'] = orgName;
    if (location != null) updates['location'] = location.toMap();

    await FirebaseService.updateUser(_currentUser!.uid, updates);
    _currentUser = _currentUser!.copyWith(
      name: name,
      phone: phone,
      orgName: orgName,
      location: location,
    );
    notifyListeners();
  }

  Future<Stream<List<UserModel>>> getLeaderboardStream() async {
    return FirebaseService.leaderboardStream();
  }
}
