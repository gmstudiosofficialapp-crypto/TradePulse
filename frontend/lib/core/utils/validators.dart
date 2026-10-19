import '../../models/live_wallet_models.dart';
import '../../models/withdraw_models.dart';

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

  static const withdrawMin = 50.0;
  static const withdrawMax = 10000.0;
  static const usdToBdt = 124.0;
  static const withdrawP2pMinBdt = 5000.0;
  static const withdrawP2pMaxBdt = 50000.0;
  static const withdrawMinMessage = r'Minimum withdrawal amount is $50.00.';
  static const withdrawMaxMessage = r'Maximum withdrawal amount is $10,000.00.';
  static const withdrawP2pMinMessage = 'Minimum P2P withdrawal is ৳5,000.00.';
  static const withdrawP2pMaxMessage = 'Maximum P2P withdrawal is ৳50,000.00.';
  static const withdrawInsufficient = 'Insufficient Live Balance.';
  static const withdrawMethodRequired = 'Please select a payment method.';
  static const withdrawAddressRequired = 'Please enter your payment address.';
  static const withdrawDetailsRequired = 'Please enter your payment details.';
  static const withdrawBtcInvalid = 'Please enter a valid Bitcoin wallet address.';
  static const withdrawTrc20Invalid =
      'Please enter a valid USDT TRC20 wallet address.';
  static const withdrawEthInvalid =
      'Please enter a valid Ethereum ERC20 wallet address.';
  static const withdrawBkashInvalid = 'Please enter a valid bKash number.';
  static const withdrawNagadInvalid = 'Please enter a valid Nagad number.';
  static const withdrawPendingExists =
      'You already have a pending withdrawal request.';
  static const withdrawSubmittedTitle = '🎉 Withdrawal Request Submitted!';
  static const withdrawSubmittedBody =
      'Thank you! Your withdrawal request has been successfully received.\n'
      'Your withdrawal will be processed within 2–12 hours.\n'
      'Thank you.';
  static const withdrawRejectionRequired = 'Please enter a rejection reason.';
  static const withdrawDepositRequired =
      'You are not eligible for withdrawal. Please deposit a minimum of \$50.';

  static final _bdMobile = RegExp(r'^(?:\+?8801|01)[3-9]\d{8}$');

  static final _btcLegacy = RegExp(r'^[13][1-9A-HJ-NP-Za-km-z]{25,33}$');
  static final _btcBech32 = RegExp(r'^bc1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{11,71}$');
  static final _tron = RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$');
  static final _eth = RegExp(r'^0x[0-9a-fA-F]{40}$');

  static double? parseMoney(String? value) {
    if (value == null) return null;
    return double.tryParse(value.replaceAll(',', '').replaceAll('\$', '').trim());
  }

  static double usdToBdtAmount(double usd) =>
      double.parse((usd * usdToBdt).toStringAsFixed(2));

  static String? withdrawAmount(String? value, [WithdrawMethod? method]) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a withdrawal amount.';
    }
    final parsed = parseMoney(value);
    if (parsed == null) {
      return 'Please enter a valid withdrawal amount.';
    }
    if (method?.category == WithdrawCategory.p2p) {
      final bdt = usdToBdtAmount(parsed);
      if (bdt < withdrawP2pMinBdt) return withdrawP2pMinMessage;
      if (bdt > withdrawP2pMaxBdt) return withdrawP2pMaxMessage;
      return null;
    }
    if (parsed < withdrawMin) return withdrawMinMessage;
    if (parsed > withdrawMax) return withdrawMaxMessage;
    return null;
  }

  static String? withdrawAddress(String? value, Object? method) {
    if (method == null) return withdrawMethodRequired;
    if (method is LivePaymentAsset) {
      if (value == null || value.trim().isEmpty) return withdrawAddressRequired;
      final address = value.trim();
      return switch (method) {
        LivePaymentAsset.btc =>
          _isBtcAddress(address) ? null : withdrawBtcInvalid,
        LivePaymentAsset.usdtTrc20 =>
          _tron.hasMatch(address) ? null : withdrawTrc20Invalid,
        LivePaymentAsset.eth =>
          _eth.hasMatch(address) ? null : withdrawEthInvalid,
      };
    }
    if (method is WithdrawMethod) {
      return withdrawPaymentDetails(value, method);
    }
    return withdrawMethodRequired;
  }

  static String? withdrawPaymentDetails(String? value, WithdrawMethod? method) {
    if (method == null) return withdrawMethodRequired;
    if (value == null || value.trim().isEmpty) {
      return method.category == WithdrawCategory.p2p
          ? withdrawDetailsRequired
          : withdrawAddressRequired;
    }
    final details = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    return switch (method) {
      WithdrawMethod.btc => _isBtcAddress(value.trim()) ? null : withdrawBtcInvalid,
      WithdrawMethod.usdtTrc20 =>
        _tron.hasMatch(value.trim()) ? null : withdrawTrc20Invalid,
      WithdrawMethod.eth =>
        _eth.hasMatch(value.trim()) ? null : withdrawEthInvalid,
      WithdrawMethod.bkash =>
        _bdMobile.hasMatch(details) ? null : withdrawBkashInvalid,
      WithdrawMethod.nagad =>
        _bdMobile.hasMatch(details) ? null : withdrawNagadInvalid,
    };
  }

  static bool _isBtcAddress(String address) {
    return _btcLegacy.hasMatch(address) ||
        _btcBech32.hasMatch(address.toLowerCase());
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
