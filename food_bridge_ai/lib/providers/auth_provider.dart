import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthStatus _status = AuthStatus.initial;
  User? _firebaseUser;
  UserModel? _userModel;
  String? _error;
  bool _isLoading = false;

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
      notifyListeners();
    } else {
      // Load user model BEFORE notifying that we are authenticated
      await _loadUserModel(user.uid);
      _status = AuthStatus.authenticated;
      
      // Token saving is safe here, but permissions are now deferred to the Dashboard
      NotificationService.saveToken().catchError((_) => null);
      
      notifyListeners();
    }
  }

  Future<void> _loadUserModel(String uid) async {
    _userModel = await FirebaseService.getUser(uid);
  }

  Future<bool> signIn(String email, String password, {UserRole? requiredRole}) async {
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Enforce role check if a specific role is required
      if (requiredRole != null) {
        final existing = await FirebaseService.getUser(cred.user!.uid);
        if (existing != null && existing.role != requiredRole) {
          await signOut();
          _error = 'This account is registered as a ${existing.role.name}. Please use the correct portal.';
          notifyListeners();
          return false;
        }
      }
      
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyAuthError(e.code);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    String? orgName,
  }) async {
    _setLoading(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.updateDisplayName(name);

      final user = UserModel(
        uid: cred.user!.uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        orgName: orgName,
        createdAt: DateTime.now(),
      );
      await FirebaseService.createUser(user);
      _userModel = user;
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyAuthError(e.code);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle({UserRole role = UserRole.donor}) async {
    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final uid = cred.user!.uid;

      final existing = await FirebaseService.getUser(uid);
      if (existing == null) {
        final user = UserModel(
          uid: uid,
          name: googleUser.displayName ?? 'User',
          email: googleUser.email,
          phone: '',
          role: role,
          createdAt: DateTime.now(),
        );
        await FirebaseService.createUser(user);
      } else if (existing.role != role) {
        await signOut();
        _error = 'This account is registered as a ${existing.role.name}. Please use the correct portal.';
        notifyListeners();
        return false;
      }

      _clearError();
      return true;
    } catch (e, stackTrace) {
      debugPrint('GOOGLE SIGN IN ERROR: $e');
      debugPrint('STACKTRACE: $stackTrace');
      _error = 'Google sign-in failed. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectRole(UserRole role) async {
    if (_firebaseUser == null) return;
    await FirebaseService.updateUser(_firebaseUser!.uid, {'role': role.name});
    _userModel = _userModel?.copyWith();
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Add timeout to prevent hanging on physical devices with poor connection
      await _googleSignIn.signOut().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
    } catch (e) {
      debugPrint('Google Sign out error (ignoring): $e');
    }
    
    try {
      await _auth.signOut();
      _userModel = null;
      _status = AuthStatus.unauthenticated;
      _clearError();
    } catch (e) {
      _error = 'Sign out failed. Check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  static String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
