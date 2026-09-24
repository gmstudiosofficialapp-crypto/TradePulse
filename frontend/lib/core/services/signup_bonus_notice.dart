import 'dart:convert';

class SignupBonusNotice {
  SignupBonusNotice._();

  static final SignupBonusNotice instance = SignupBonusNotice._();

  bool _pending = false;
  bool _consumed = false;

  bool get isPending => _pending && !_consumed;
  bool get wasConsumed => _consumed;

  void offerFromServer({required bool justGranted}) {
    if (!justGranted || _consumed) return;
    _pending = true;
  }

  bool take() {
    if (!_pending || _consumed) return false;
    _pending = false;
    _consumed = true;
    return true;
  }

  void clearSession() {
    _pending = false;
    _consumed = false;
  }

  void resetForTest() {
    clearSession();
  }
}

void applySignupBonusPayload(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return;
    final justGranted = decoded['signup_bonus_just_granted'] == true;
    SignupBonusNotice.instance.offerFromServer(justGranted: justGranted);
  } catch (_) {
    // Ignore malformed bootstrap payloads; never invent a bonus locally.
  }
}
