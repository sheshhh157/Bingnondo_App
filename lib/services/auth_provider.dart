import 'package:flutter/foundation.dart';
import 'api_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  awaitingVerification,
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  CustomerUser? _user;
  String? _pendingEmail; // email waiting for OTP verification

  AuthStatus get status => _status;
  CustomerUser? get user => _user;
  String? get pendingEmail => _pendingEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  final ApiService _api = ApiService.instance;

  AuthProvider() {
    _checkExistingToken();
  }

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> _checkExistingToken() async {
    final token = await _api.getAccessToken();
    if (token != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Sign Up ───────────────────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _api.register(email: email, password: password);
    _pendingEmail = email;
    _status = AuthStatus.awaitingVerification;
    notifyListeners();
  }

  // ─── Verify OTP ────────────────────────────────────────────────────────────

  Future<void> verifyOtp({required String otp}) async {
    if (_pendingEmail == null) throw const ApiException('Session expired. Please sign up again.');

    final response = await _api.verifyOtp(email: _pendingEmail!, otp: otp);
    _user = response.user;
    _status = AuthStatus.authenticated;
    _pendingEmail = null;
    notifyListeners();
  }

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    await _api.verifyPasswordResetOtp(email: email, otp: otp);
  }

  Future<void> resendOtp() async {
    if (_pendingEmail == null) return;
    await _api.resendOtp(email: _pendingEmail!);
  }

  // ─── Sign In ───────────────────────────────────────────────────────────────

  Future<void> login({
    required String emailOrMobile,
    required String password,
  }) async {
    final response = await _api.login(
      emailOrMobile: emailOrMobile,
      password: password,
    );
    _user = response.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  // ─── Forgot / Reset Password ───────────────────────────────────────────────

  Future<void> forgotPassword({required String email}) async {
    await _api.forgotPassword(email: email);
    _pendingEmail = email;
    notifyListeners();
  }

  Future<void> resetPassword({
    required String otp,
    required String newPassword,
  }) async {
    if (_pendingEmail == null) throw const ApiException('Session expired.');
    await _api.resetPassword(
      email: _pendingEmail!,
      otp: otp,
      newPassword: newPassword,
    );
    _pendingEmail = null;
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _api.clearTokens();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void setPendingEmail(String email) {
    _pendingEmail = email;
    notifyListeners();
  }
}