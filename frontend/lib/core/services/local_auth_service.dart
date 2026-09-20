import '../../models/user_profile.dart';
import 'auth_service.dart';

class _StoredAccount {
  _StoredAccount({
    required this.profile,
    required this.password,
  });

  UserProfile profile;
  String password;
}

class LocalAuthService implements AuthService {
  final Map<String, _StoredAccount> _accounts = {};
  UserProfile? _session;
  final Map<String, String> _resetCodes = {};
  final Set<String> _usedCodes = {};

  String _key(String email) => email.trim().toLowerCase();

  Future<void> _pause() => Future<void>.delayed(
        const Duration(milliseconds: 420),
      );

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    await _pause();
    final account = _accounts[_key(email)];
    if (account == null || account.password != password) {
      throw const AuthException('Incorrect email or password');
    }
    _session = account.profile;
    return account.profile;
  }

  @override
  Future<UserProfile> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _pause();
    final key = _key(email);
    if (_accounts.containsKey(key)) {
      throw const AuthException('An account with this email already exists');
    }
    final profile = UserProfile(
      uid: key,
      fullName: fullName.trim(),
      email: email.trim(),
      memberSince: DateTime.now(),
    );
    _accounts[key] = _StoredAccount(profile: profile, password: password);
    _session = profile;
    return profile;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _session = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    await _pause();
    final key = _key(email);
    if (!_accounts.containsKey(key)) {
      throw const AuthException('No account found for that email');
    }
    _resetCodes[key] = 'action-$key';
  }

  @override
  Future<String> verifyResetActionCode(String oobCode) async {
    await _pause();
    return _emailForCode(oobCode);
  }

  @override
  Future<void> confirmPasswordReset({
    required String oobCode,
    required String newPassword,
  }) async {
    await _pause();
    final email = _emailForCode(oobCode);
    final account = _accounts[_key(email)];
    if (account == null) {
      throw const AuthException(
        'This reset link is invalid or has already been used.',
      );
    }
    account.password = newPassword;
    _usedCodes.add(oobCode);
    _resetCodes.remove(_key(email));
  }

  String _emailForCode(String oobCode) {
    if (oobCode == 'expired') {
      throw const AuthException(
        'This reset link has expired. Request a new email.',
      );
    }
    if (oobCode.isEmpty || oobCode == 'invalid' || _usedCodes.contains(oobCode)) {
      throw const AuthException(
        'This reset link is invalid or has already been used.',
      );
    }
    for (final entry in _resetCodes.entries) {
      if (entry.value == oobCode) return entry.key;
    }
    if (oobCode.startsWith('action-')) {
      return oobCode.substring('action-'.length);
    }
    throw const AuthException(
      'This reset link is invalid or has already been used.',
    );
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
    await _pause();
    final session = _session;
    if (session == null) {
      throw const AuthException('You are not signed in');
    }
    final account = _accounts[_key(session.email)];
    if (account == null) {
      throw const AuthException('Account not found');
    }
    final updated = session.copyWith(
      fullName: fullName.trim(),
      username: username ?? session.username,
      phone: phone ?? session.phone,
      dateOfBirth: dateOfBirth,
      clearDateOfBirth: clearDateOfBirth,
      gender: gender ?? session.gender,
      country: country ?? session.country,
      division: division ?? session.division,
      district: district ?? session.district,
      thana: thana ?? session.thana,
      city: city ?? session.city,
      area: area ?? session.area,
      fullAddress: fullAddress ?? session.fullAddress,
      postalCode: postalCode ?? session.postalCode,
    );
    account.profile = updated;
    _session = updated;
    return updated;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _pause();
    final session = _session;
    if (session == null) {
      throw const AuthException('You are not signed in');
    }
    final account = _accounts[_key(session.email)];
    if (account == null || account.password != currentPassword) {
      throw const AuthException('Current password is incorrect');
    }
    account.password = newPassword;
  }

  @override
  bool isAuthenticated() => _session != null;

  @override
  UserProfile? currentUser() => _session;

  @override
  Future<void> restoreSession() async {}

  @override
  Future<String?> idToken() async => null;
}
