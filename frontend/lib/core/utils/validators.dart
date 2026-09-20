class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_email.hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Use at least 8 characters';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'Use letters and numbers';
    }
    return null;
  }

  static String? liveDepositAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a deposit amount';
    }
    final parsed = double.tryParse(value.replaceAll(',', '').replaceAll('\$', '').trim());
    if (parsed == null) {
      return 'Enter a valid amount';
    }
    if (parsed < 50) {
      return 'Minimum deposit is \$50.';
    }
    if (parsed > 5000) {
      return 'Maximum deposit is \$5,000.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != original) {
      return 'Passwords do not match';
    }
    return null;
  }
}
