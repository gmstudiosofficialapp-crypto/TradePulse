import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../models/user_profile.dart';
import '../constants/app_constants.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, http.Client? httpClient})
      : _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _http;

  UserProfile? _profile;

  @override
  Future<void> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      _profile = null;
      return;
    }
    _profile = _fromUser(user);
    await _syncRemote();
  }

  @override
  Future<String?> idToken() async {
    return _auth.currentUser?.getIdToken();
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _profile = _fromUser(credential.user!);
      await _syncRemote();
      return _profile!;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_message(error));
    }
  }

  @override
  Future<UserProfile> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.reload();
      _profile = _fromUser(_auth.currentUser!);
      await _syncRemote();
      return _profile!;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_message(error));
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    _profile = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_message(error));
    }
  }

  @override
  Future<UserProfile> updateProfile({
    required String fullName,
    String? username,
    String? phone,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? gender,
    String? country,
    String? division,
    String? district,
    String? thana,
    String? city,
    String? area,
    String? fullAddress,
    String? postalCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _profile == null) {
      throw const AuthException('You are not signed in');
    }
    await user.updateDisplayName(fullName.trim());
    final token = await user.getIdToken();
    final response = await _http.patch(
      Uri.parse('${AppConstants.apiBase}/api/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fullName': fullName.trim(),
        'username': username,
        'phone': phone,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'country': country,
        'division': division,
        'district': district,
        'thana': thana,
        'city': city,
        'area': area,
        'fullAddress': fullAddress,
        'postalCode': postalCode,
      }),
    );
    if (response.statusCode >= 400) {
      throw const AuthException('Unable to update profile');
    }
    _profile = _profile!.copyWith(
      fullName: fullName.trim(),
      username: username,
      phone: phone,
      dateOfBirth: dateOfBirth,
      clearDateOfBirth: clearDateOfBirth,
      gender: gender,
      country: country,
      division: division,
      district: district,
      thana: thana,
      city: city,
      area: area,
      fullAddress: fullAddress,
      postalCode: postalCode,
    );
    return _profile!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('You are not signed in');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_message(error));
    }
  }

  @override
  bool isAuthenticated() => _auth.currentUser != null && _profile != null;

  @override
  UserProfile? currentUser() => _profile;

  Future<void> _syncRemote() async {
    final token = await idToken();
    if (token == null) return;
    try {
      await _http.post(
        Uri.parse('${AppConstants.apiBase}/api/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {
      // Account bootstrap is retried on the next authenticated API call.
    }
  }

  UserProfile _fromUser(User user) {
    return UserProfile(
      uid: user.uid,
      fullName: user.displayName ?? '',
      email: user.email ?? '',
      memberSince: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  String _message(FirebaseAuthException error) {
    return switch (error.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Incorrect email or password',
      'email-already-in-use' => 'An account with this email already exists',
      'weak-password' => 'Password is too weak',
      'requires-recent-login' => 'Current password is incorrect',
      'invalid-email' => 'Enter a valid email',
      'network-request-failed' => 'Network failure. Try again.',
      _ => error.message ?? 'Authentication failed',
    };
  }
}
