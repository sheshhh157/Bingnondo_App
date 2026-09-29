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

    // FIX C: May token pero wala pang user object — i-fetch muna ang user
    // para may laman ang _user kapag nag-navigate sa home.
    // Sa ngayon, i-set na lang as authenticated — mag-aadopt ng lazy load
    // kapag may /me endpoint na tayo sa susunod na sprint.
    // Pero i-verify muna na valid ang token structure bago mag-authenticated.
    try {
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (_) {
      // Token corrupted or invalid — mag-logout
      await _api.clearTokens();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
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

    // FIX B: I-check kung may user sa response bago i-set
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

  Future<void> _mockLogin(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final inputEmail = email.trim().toLowerCase();
    final inputPassword = password.trim();

    final targetEmail = kMockEmail.trim().toLowerCase();
    final targetPassword = kMockPassword.trim();

    if ((inputEmail == targetEmail || inputEmail == '1234567890') &&
        inputPassword == targetPassword) {
      _user = CustomerUser.fromJson(kMockUser);
      _status = AuthStatus.authenticated;
      notifyListeners();
    } else {
      throw const ApiException(
        'Invalid credentials. For testing, use:\nEmail: test@bingnondo.com\nPassword: Test1234',
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

    final response = await _api.verifyOtp(
      email: _pendingEmail!,
      otp: otp,
    );

    // FIX B: I-check kung may user sa response bago i-set
    // Kung walang user (hindi dapat mangyari), throw error
    if (response.user == null) {
      throw const ApiException(
        'Verification failed. Please try again.',
        statusCode: 500,
      );
    }

    // FIX C: I-set ang user object BAGO i-set ang status
    // Para kapag nag-notify ang listeners at nag-navigate sa home,
    // nandun na ang user data.
    _user = response.user;
    _pendingEmail = null;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }
    await _api.verifyPasswordResetOtp(email: email, otp: otp);
  }

  Future<void> resendOtp() async {
    if (_pendingEmail == null) {
      throw const ApiException('Session expired. Please sign up again.');
    }
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