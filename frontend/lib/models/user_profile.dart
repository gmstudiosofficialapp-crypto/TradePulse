class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.memberSince,
    this.uid = '',
    this.accountType = 'DEMO',
    this.username = '',
    this.phone = '',
    this.dateOfBirth,
    this.gender = '',
    this.country = '',
    this.division = '',
    this.district = '',
    this.thana = '',
    this.city = '',
    this.area = '',
    this.fullAddress = '',
    this.postalCode = '',
  });

  final String uid;
  final String fullName;
  final String email;
  final DateTime memberSince;
  final String accountType;
  final String username;
  final String phone;
  final DateTime? dateOfBirth;
  final String gender;
  final String country;
  final String division;
  final String district;
  final String thana;
  final String city;
  final String area;
  final String fullAddress;
  final String postalCode;

  UserProfile copyWith({
    String? fullName,
    String? email,
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
  }) {
    return UserProfile(
      uid: uid.isEmpty ? this.email : uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      memberSince: memberSince,
      accountType: accountType,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      gender: gender ?? this.gender,
      country: country ?? this.country,
      division: division ?? this.division,
      district: district ?? this.district,
      thana: thana ?? this.thana,
      city: city ?? this.city,
      area: area ?? this.area,
      fullAddress: fullAddress ?? this.fullAddress,
      postalCode: postalCode ?? this.postalCode,
    );
  }

  factory UserProfile.fromServer(
    Map<String, dynamic> json, {
    UserProfile? current,
  }) {
    String read(String key, [String fallback = '']) {
      final value = json[key];
      if (value == null) return fallback;
      final text = '$value'.trim();
      return text.isEmpty ? fallback : text;
    }

    DateTime? parseTime(Object? raw) {
      if (raw == null || '$raw'.trim().isEmpty) return null;
      return DateTime.tryParse('$raw');
    }

    final fullName = read('displayName', read('fullName', current?.fullName ?? ''));
    final created = parseTime(json['createdAt']) ?? current?.memberSince ?? DateTime.now();
    return UserProfile(
      uid: read('uid', current?.uid ?? ''),
      fullName: fullName,
      email: read('email', current?.email ?? ''),
      memberSince: created,
      accountType: current?.accountType ?? 'DEMO',
      username: read('username', current?.username ?? ''),
      phone: read('phone', current?.phone ?? ''),
      dateOfBirth: parseTime(json['dateOfBirth']) ?? current?.dateOfBirth,
      gender: read('gender', current?.gender ?? ''),
      country: read('country', current?.country ?? ''),
      division: read('division', current?.division ?? ''),
      district: read('district', current?.district ?? ''),
      thana: read('thana', current?.thana ?? ''),
      city: read('city', current?.city ?? ''),
      area: read('area', current?.area ?? ''),
      fullAddress: read('fullAddress', current?.fullAddress ?? ''),
      postalCode: read('postalCode', current?.postalCode ?? ''),
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : 'T';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
