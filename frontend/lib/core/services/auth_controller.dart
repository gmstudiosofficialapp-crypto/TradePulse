import 'package:flutter/foundation.dart';

import '../../models/user_profile.dart';
import 'auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  UserProfile? get user => _service.currentUser();
  bool get isAuthenticated => _service.isAuthenticated();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _service.login(email: email, password: password);
    notifyListeners();
  }

  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _service.signup(
      fullName: fullName,
      email: email,
      password: password,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    notifyListeners();
  }

  Future<void> resetPassword({required String email}) {
    return _service.resetPassword(email: email);
  }

  Future<void> updateProfile({
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
    await _service.updateProfile(
      fullName: fullName,
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
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
