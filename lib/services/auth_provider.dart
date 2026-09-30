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

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated;

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
      await _mockLogin(
        emailOrMobile,
        password,
      );
      return;
    }

    final response = await _api.login(
      emailOrMobile: emailOrMobile,
      password: password,
    );

    if (response.user == null) {
      throw const ApiException(
        'Login failed. Please try again.',
        statusCode: 500,
      );
    }

    _user = response.user;

    _status = AuthStatus.authenticated;

    notifyListeners();
  }

  // ─── Sign Up ─────────────────────────────────────────────────────────────

  Future<void> register({
    required String email,
    required String password,
  }) async {
    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 600),
      );

      _pendingEmail = email.trim().toLowerCase();

      _status = AuthStatus.awaitingVerification;

      notifyListeners();

      return;
    }

    final normalizedEmail =
    email.trim().toLowerCase();

    final response = await _api.register(
      email: normalizedEmail,
      password: password,
    );

    if (response.user == null) {
      throw const ApiException(
        'Registration failed. Please try again.',
        statusCode: 500,
      );
    }

    _pendingEmail = normalizedEmail;

    _status = AuthStatus.awaitingVerification;

    notifyListeners();
  }

  // ─── OTP Verification ────────────────────────────────────────────────────

  Future<void> verifyOtp({
    required String otp,
  }) async {
    if (_pendingEmail == null) {
      throw const ApiException(
        'Session expired. Please sign up again.',
      );
    }

    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 600),
      );

      if (otp.length == 6) {
        return;
      }

      throw const ApiException(
        'Invalid OTP.',
        statusCode: 422,
      );
    }

    final response = await _api.verifyOtp(
      email: _pendingEmail!,
      otp: otp,
      purpose: 'email_verification',
    );

    if (response.user == null) {
      throw const ApiException(
        'Verification failed. Please try again.',
        statusCode: 500,
      );
    }

    await _api.clearTokens();

    _user = null;

    _status = AuthStatus.unauthenticated;

    notifyListeners();
  }

  // ─── Password Reset OTP Verification ─────────────────────────────────────

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    final normalizedEmail =
    email.trim().toLowerCase();

    final normalizedOtp =
    otp.trim();

    if (normalizedEmail.isEmpty) {
      throw const ApiException(
        'Email address is required.',
        statusCode: 422,
      );
    }

    if (normalizedOtp.length != 6) {
      throw const ApiException(
        'Please enter the 6-digit OTP.',
        statusCode: 422,
      );
    }

    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      return;
    }

    /*
     * IMPORTANT:
     *
     * This specifically verifies a PASSWORD RESET OTP.
     *
     * It does NOT use the normal email-verification
     * endpoint behavior.
     *
     * ApiService sends:
     *
     * purpose = password_reset
     */
    await _api.verifyPasswordResetOtp(
      email: normalizedEmail,
      otp: normalizedOtp,
    );
  }

  // ─── Resend Email Verification OTP ───────────────────────────────────────

  Future<void> resendOtp() async {
    if (_pendingEmail == null) {
      throw const ApiException(
        'Session expired. Please sign up again.',
      );
    }

    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      return;
    }

    /*
     * This method is ONLY for normal
     * email verification.
     */
    await _api.resendOtp(
      email: _pendingEmail!,
      purpose: 'email_verification',
    );
  }

  // ─── Resend Password Reset OTP ───────────────────────────────────────────

  Future<void> resendPasswordResetOtp({
    required String email,
  }) async {
    final normalizedEmail =
    email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const ApiException(
        'Email address is required.',
        statusCode: 422,
      );
    }

    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      _pendingEmail = normalizedEmail;

      notifyListeners();

      return;
    }

    /*
     * IMPORTANT:
     *
     * Forgot Password MUST resend using:
     *
     * purpose = password_reset
     *
     * This prevents the new OTP from accidentally
     * being created as email_verification.
     */
    await _api.resendOtp(
      email: normalizedEmail,
      purpose: 'password_reset',
    );

    _pendingEmail = normalizedEmail;

    notifyListeners();
  }

  // ─── Forgot Password ─────────────────────────────────────────────────────

  Future<void> forgotPassword({
    required String email,
  }) async {
    final normalizedEmail =
    email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const ApiException(
        'Email address is required.',
        statusCode: 422,
      );
    }

    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 600),
      );

      _pendingEmail = normalizedEmail;

      notifyListeners();

      return;
    }

    /*
     * The backend checks whether the account exists.
     *
     * Existing account:
     *     request succeeds
     *
     * Non-existing account:
     *     backend returns 404
     *
     * If the backend returns 404, this function throws
     * and the code below is NOT executed.
     */
    await _api.forgotPassword(
      email: normalizedEmail,
    );

    /*
     * Reached ONLY when the backend successfully
     * processed the password reset request.
     */
    _pendingEmail = normalizedEmail;

    notifyListeners();
  }

  // ─── Reset Password ──────────────────────────────────────────────────────

  Future<void> resetPassword({
    required String otp,
    required String newPassword,
  }) async {
    if (_pendingEmail == null) {
      throw const ApiException(
        'Session expired.',
      );
    }

    final normalizedOtp =
    otp.trim();

    if (normalizedOtp.length != 6) {
      throw const ApiException(
        'Please enter the 6-digit OTP.',
        statusCode: 422,
      );
    }

    if (kUseMock) {
      await Future.delayed(
        const Duration(milliseconds: 600),
      );

      _pendingEmail = null;

      notifyListeners();

      return;
    }

    await _api.resetPassword(
      email: _pendingEmail!,
      otp: normalizedOtp,
      newPassword: newPassword,
    );

    _pendingEmail = null;

    notifyListeners();
  }

  // ─── Logout ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    if (!kUseMock) {
      await _api.clearTokens();
    }

    _user = null;

    _pendingEmail = null;

    _status = AuthStatus.unauthenticated;

    notifyListeners();
  }

  // ─── Pending Email ───────────────────────────────────────────────────────

  void setPendingEmail(String email) {
    _pendingEmail =
        email.trim().toLowerCase();

    notifyListeners();
  }

  // ─── Mock Login ──────────────────────────────────────────────────────────

  Future<void> _mockLogin(
      String emailOrMobile,
      String password,
      ) async {
    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    _user = CustomerUser(
      id: 1,
      email: emailOrMobile,
      emailVerified: true,
      profileCompleted: true,
      status: 'active',
      firstName: 'Test',
      lastName: 'User',
    );

    _status = AuthStatus.authenticated;

    notifyListeners();
  }
}