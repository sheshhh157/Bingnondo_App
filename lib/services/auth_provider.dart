import 'package:flutter/foundation.dart';

import 'api_service.dart';
import '../mock/mock_data.dart';
import '../services/socket_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  awaitingVerification,
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  CustomerUser? _user;

  // Stores email OR mobile number depending on the registration flow
  String? _pendingContact;

  // Tracks whether the pending flow is mobile-based
  bool _pendingIsMobile = false;

  AuthStatus get status        => _status;
  CustomerUser? get user       => _user;
  String? get pendingContact   => _pendingContact;
  bool get pendingIsMobile     => _pendingIsMobile;

  /// Legacy getter — returns pendingContact when it's an email (backward compat)
  String? get pendingEmail =>
      (_pendingIsMobile == false) ? _pendingContact : null;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  final ApiService _api = ApiService.instance;

  AuthProvider() {
    _checkExistingToken();
  }

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> _checkExistingToken() async {
    if (kUseMock) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final token = await _api.getAccessToken();

    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (_) {
      await _api.clearTokens();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ─── Sign In ─────────────────────────────────────────────────────────────

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

    if (response.user == null) {
      throw const ApiException('Login failed. Please try again.', statusCode: 500);
    }

    _user = response.user;
    _status = AuthStatus.authenticated;
    notifyListeners();

    final socket = SocketService.instance;
    socket.connect();
    socket.joinSupportRoom(_user!.id);
    socket.joinCustomerRoom(_user!.id);
  }

  // ─── Register via Email ───────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
  }) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingContact  = email.trim().toLowerCase();
      _pendingIsMobile = false;
      _status = AuthStatus.awaitingVerification;
      notifyListeners();
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();

    await _api.register(email: normalizedEmail, password: password);

    _pendingContact  = normalizedEmail;
    _pendingIsMobile = false;
    _status = AuthStatus.awaitingVerification;
    notifyListeners();
  }

  // ─── Register via Mobile ──────────────────────────────────────────────────

  Future<void> registerMobile({
    required String mobileNumber,
    required String password,
  }) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingContact  = mobileNumber.trim();
      _pendingIsMobile = true;
      _status = AuthStatus.awaitingVerification;
      notifyListeners();
      return;
    }

    await _api.registerMobile(
      mobileNumber: mobileNumber.trim(),
      password: password,
    );

    _pendingContact  = mobileNumber.trim();
    _pendingIsMobile = true;
    _status = AuthStatus.awaitingVerification;
    notifyListeners();
  }

  // ─── OTP Verification (email or mobile) ──────────────────────────────────

  Future<void> verifyOtp({required String otp}) async {
    if (_pendingContact == null) {
      throw const ApiException('Session expired. Please sign up again.');
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (otp.length == 6) return;
      throw const ApiException('Invalid OTP.', statusCode: 422);
    }

    final purpose = _pendingIsMobile
        ? 'mobile_verification'
        : 'email_verification';

    final response = await _api.verifyOtp(
      contact: _pendingContact!,
      otp: otp,
      purpose: purpose,
    );

    if (response.user == null) {
      throw const ApiException('Verification failed. Please try again.', statusCode: 500);
    }

    await _api.clearTokens();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Password Reset OTP Verification ─────────────────────────────────────

  Future<void> verifyPasswordResetOtp({
    required String contact,
    required String otp,
  }) async {
    final normalizedContact = contact.trim().toLowerCase();
    final normalizedOtp     = otp.trim();

    if (normalizedContact.isEmpty) {
      throw const ApiException('Contact is required.', statusCode: 422);
    }
    if (normalizedOtp.length != 6) {
      throw const ApiException('Please enter the 6-digit OTP.', statusCode: 422);
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    await _api.verifyPasswordResetOtp(
      contact: normalizedContact,
      otp: normalizedOtp,
    );
  }

  // ─── Resend OTP ───────────────────────────────────────────────────────────

  Future<void> resendOtp() async {
    if (_pendingContact == null) {
      throw const ApiException('Session expired. Please sign up again.');
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }

    final purpose = _pendingIsMobile
        ? 'mobile_verification'
        : 'email_verification';

    await _api.resendOtp(contact: _pendingContact!, purpose: purpose);
  }

  // ─── Resend Password Reset OTP ───────────────────────────────────────────

  Future<void> resendPasswordResetOtp({required String contact}) async {
    final normalizedContact = contact.trim().toLowerCase();

    if (normalizedContact.isEmpty) {
      throw const ApiException('Contact is required.', statusCode: 422);
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      _pendingContact = normalizedContact;
      notifyListeners();
      return;
    }

    await _api.resendOtp(
      contact: normalizedContact,
      purpose: 'password_reset',
    );

    _pendingContact = normalizedContact;
    notifyListeners();
  }

  // ─── Forgot Password via Email ────────────────────────────────────────────

  Future<void> forgotPassword({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const ApiException('Email address is required.', statusCode: 422);
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingContact  = normalizedEmail;
      _pendingIsMobile = false;
      notifyListeners();
      return;
    }

    await _api.forgotPassword(email: normalizedEmail);

    _pendingContact  = normalizedEmail;
    _pendingIsMobile = false;
    notifyListeners();
  }

  // ─── Forgot Password via Mobile ───────────────────────────────────────────

  Future<void> forgotPasswordMobile({required String mobileNumber}) async {
    final normalized = mobileNumber.trim();

    if (normalized.isEmpty) {
      throw const ApiException('Mobile number is required.', statusCode: 422);
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingContact  = normalized;
      _pendingIsMobile = true;
      notifyListeners();
      return;
    }

    await _api.forgotPasswordMobile(mobileNumber: normalized);

    _pendingContact  = normalized;
    _pendingIsMobile = true;
    notifyListeners();
  }

  // ─── Reset Password ───────────────────────────────────────────────────────

  Future<void> resetPassword({
    required String otp,
    required String newPassword,
  }) async {
    if (_pendingContact == null) {
      throw const ApiException('Session expired.');
    }

    final normalizedOtp = otp.trim();
    if (normalizedOtp.length != 6) {
      throw const ApiException('Please enter the 6-digit OTP.', statusCode: 422);
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingContact = null;
      notifyListeners();
      return;
    }

    await _api.resetPassword(
      contact:     _pendingContact!,
      otp:         normalizedOtp,
      newPassword: newPassword,
    );

    _pendingContact  = null;
    _pendingIsMobile = false;
    notifyListeners();
  }

  // ─── Logout ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (!kUseMock) await _api.clearTokens();

    SocketService.instance.disconnect();

    _user            = null;
    _pendingContact  = null;
    _pendingIsMobile = false;
    _status          = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void setPendingContact(String contact, {bool isMobile = false}) {
    _pendingContact  = contact.trim().toLowerCase();
    _pendingIsMobile = isMobile;
    notifyListeners();
  }

  // Legacy compat
  void setPendingEmail(String email) => setPendingContact(email);

  // ─── Mock Login ──────────────────────────────────────────────────────────

  Future<void> _mockLogin(String emailOrMobile, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    _user = CustomerUser(
      id: 1,
      email: emailOrMobile.contains('@') ? emailOrMobile : null,
      mobileNumber: emailOrMobile.contains('@') ? null : emailOrMobile,
      emailVerified:    true,
      mobileVerified:   true,
      profileCompleted: true,
      status:           'active',
      firstName:        'Test',
      lastName:         'User',
    );

    _status = AuthStatus.authenticated;
    notifyListeners();

    final socket = SocketService.instance;
    socket.connect();
    socket.joinSupportRoom(_user!.id);
    socket.joinCustomerRoom(_user!.id);
  }
}
