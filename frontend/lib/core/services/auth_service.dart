import '../../models/user_profile.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthService {
  Future<UserProfile> login({
    required String email,
    required String password,
  });

  Future<UserProfile> signup({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<void> resetPassword({required String email});

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
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  bool isAuthenticated();

  UserProfile? currentUser();

  Future<void> restoreSession();

  Future<String?> idToken();
}
