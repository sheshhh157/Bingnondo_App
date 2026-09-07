import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../mock/mock_data.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  awaitingVerification,
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  CustomerUser? _user;
  String? _pendingEmail;

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
    if (kUseMock) {
      // In mock mode: skip stored token check, go straight to unauthenticated
      // so the login screen shows and testers can use mock credentials.
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final token = await _api.getAccessToken();
    _status =
    token != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Sign In ───────────────────────────────────────────────────────────────

  Future<void> login({
    required String emailOrMobile,
    required String password,
  }) async {
    if (kUseMock) {
      await _mockLogin(emailOrMobile, password);
      return;
    }

    final response = await _api.login(
      emailOrMobile: emailOrMobile,
      password: password,
    );
    _user = response.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _mockLogin(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (email.trim().toLowerCase() == kMockEmail &&
        password == kMockPassword) {
      _user = CustomerUser.fromJson(kMockUser);
      _status = AuthStatus.authenticated;
      notifyListeners();
    } else {
      throw const ApiException(
        'Incorrect email or password. Use test@bingnondo.com / Test1234',
        statusCode: 401,
      );
    }
  }

  // ─── Sign Up ───────────────────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
  }) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingEmail = email;
      _status = AuthStatus.awaitingVerification;
      notifyListeners();
      return;
    }

    await _api.register(email: email, password: password);
    _pendingEmail = email;
    _status = AuthStatus.awaitingVerification;
    notifyListeners();
  }

  // ─── Verify OTP ────────────────────────────────────────────────────────────

  Future<void> verifyOtp({required String otp}) async {
    if (_pendingEmail == null) {
      throw const ApiException('Session expired. Please sign up again.');
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      // Any 6-digit code works in mock mode
      if (otp.length == 6) {
        _user = CustomerUser.fromJson({
          ...kMockUser,
          'email': _pendingEmail,
          'email_verified': true,
        });
        _status = AuthStatus.authenticated;
        _pendingEmail = null;
        notifyListeners();
      } else {
        throw const ApiException('Invalid OTP.', statusCode: 422);
      }
      return;
    }

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
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return; // Always succeeds in mock
    }
    await _api.verifyPasswordResetOtp(email: email, otp: otp);
  }

  Future<void> resendOtp() async {
    if (_pendingEmail == null) return;
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    await _api.resendOtp(email: _pendingEmail!);
  }

  // ─── Forgot / Reset ────────────────────────────────────────────────────────

  Future<void> forgotPassword({required String email}) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingEmail = email;
      notifyListeners();
      return;
    }
    await _api.forgotPassword(email: email);
    _pendingEmail = email;
    notifyListeners();
  }

  Future<void> resetPassword({
    required String otp,
    required String newPassword,
  }) async {
    if (_pendingEmail == null) throw const ApiException('Session expired.');
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingEmail = null;
      return;
    }
    await _api.resetPassword(
      email: _pendingEmail!,
      otp: otp,
      newPassword: newPassword,
    );
    _pendingEmail = null;
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (!kUseMock) await _api.clearTokens();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void setPendingEmail(String email) {
    _pendingEmail = email;
    notifyListeners();
  }
}