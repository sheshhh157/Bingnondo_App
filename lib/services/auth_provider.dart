import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api_service.dart';
import '../mock/mock_data.dart';
import '../services/socket_service.dart';
import 'push_notification_service.dart';
import 'session_expiration.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  awaitingVerification,
}

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  AuthStatus _status = AuthStatus.initial;
  CustomerUser? _user;
  DateTime? _sessionExpiresAt;
  Timer? _sessionExpiryTimer;

  String? _pendingContact;

  AuthStatus get status => _status;
  CustomerUser? get user => _user;
  String? get pendingContact => _pendingContact;

  String? get pendingEmail => _pendingContact;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  final ApiService _api = ApiService.instance;

  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
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

    if (!_scheduleSessionExpiry(token)) {
      await _api.clearTokens();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _status = AuthStatus.authenticated;
    notifyListeners();
    unawaited(PushNotificationService.instance.registerCurrentDevice());
  }

  bool _scheduleSessionExpiry(String token) {
    final expiresAt = customerAccessTokenExpiry(token);
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      return false;
    }

    _sessionExpiryTimer?.cancel();
    _sessionExpiresAt = expiresAt;
    _sessionExpiryTimer = Timer(
      expiresAt.difference(DateTime.now().toUtc()),
      _expireSession,
    );
    return true;
  }

  void _expireSession() {
    if (_status != AuthStatus.authenticated) return;

    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    _sessionExpiresAt = null;
    _user = null;
    _pendingContact = null;
    _status = AuthStatus.unauthenticated;
    SocketService.instance.disconnect();
    notifyListeners();

    unawaited(_clearExpiredSessionTokens());
    if (!kUseMock) {
      unawaited(PushNotificationService.instance.unregisterCurrentDevice());
    }
  }

  Future<void> _clearExpiredSessionTokens() async {
    try {
      await _api.clearTokens();
    } catch (error, stackTrace) {
      debugPrint('[Auth] Failed to clear expired session tokens: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final expiresAt = _sessionExpiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      _expireSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionExpiryTimer?.cancel();
    super.dispose();
  }

  // ─── Sign In ─────────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    if (kUseMock) {
      await _mockLogin(email, password);
      return;
    }

    final response = await _api.login(email: email, password: password);

    if (response.user == null) {
      throw const ApiException(
        'Login failed. Please try again.',
        statusCode: 500,
      );
    }

    final accessToken = response.accessToken;
    if (accessToken == null || !_scheduleSessionExpiry(accessToken)) {
      await _api.clearTokens();
      throw const ApiException(
        'Login failed. Please try again.',
        statusCode: 500,
      );
    }

    _user = response.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
    unawaited(PushNotificationService.instance.registerCurrentDevice());

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
      _pendingContact = email.trim().toLowerCase();
      _status = AuthStatus.awaitingVerification;
      notifyListeners();
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();

    await _api.register(email: normalizedEmail, password: password);

    _pendingContact = normalizedEmail;
    _status = AuthStatus.awaitingVerification;
    notifyListeners();
  }

  // ─── OTP Verification ────────────────────────────────────────────────────

  Future<void> verifyOtp({required String otp}) async {
    if (_pendingContact == null) {
      throw const ApiException('Session expired. Please sign up again.');
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (otp.length == 6) return;
      throw const ApiException('Invalid OTP.', statusCode: 422);
    }

    final response = await _api.verifyOtp(
      contact: _pendingContact!,
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
    required String contact,
    required String otp,
  }) async {
    final normalizedContact = contact.trim().toLowerCase();
    final normalizedOtp = otp.trim();

    if (normalizedContact.isEmpty) {
      throw const ApiException('Contact is required.', statusCode: 422);
    }
    if (normalizedOtp.length != 6) {
      throw const ApiException(
        'Please enter the 6-digit OTP.',
        statusCode: 422,
      );
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

    await _api.resendOtp(
      contact: _pendingContact!,
      purpose: 'email_verification',
    );
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

    await _api.resendOtp(contact: normalizedContact, purpose: 'password_reset');

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
      _pendingContact = normalizedEmail;
      notifyListeners();
      return;
    }

    await _api.forgotPassword(email: normalizedEmail);

    _pendingContact = normalizedEmail;
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
      throw const ApiException(
        'Please enter the 6-digit OTP.',
        statusCode: 422,
      );
    }

    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _pendingContact = null;
      notifyListeners();
      return;
    }

    await _api.resetPassword(
      contact: _pendingContact!,
      otp: normalizedOtp,
      newPassword: newPassword,
    );

    _pendingContact = null;
    notifyListeners();
  }

  // ─── Logout ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    _sessionExpiresAt = null;

    if (!kUseMock) {
      await PushNotificationService.instance.unregisterCurrentDevice();
    }
    if (!kUseMock) await _api.clearTokens();

    SocketService.instance.disconnect();

    _user = null;
    _pendingContact = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  // ─── Mock Login ──────────────────────────────────────────────────────────

  Future<void> _mockLogin(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    _user = CustomerUser(
      id: 1,
      email: email,
      mobileNumber: null,
      emailVerified: true,
      profileCompleted: true,
      status: 'active',
      firstName: 'Test',
      lastName: 'User',
    );

    _status = AuthStatus.authenticated;
    notifyListeners();
    unawaited(PushNotificationService.instance.registerCurrentDevice());

    final socket = SocketService.instance;
    socket.connect();
    socket.joinSupportRoom(_user!.id);
    socket.joinCustomerRoom(_user!.id);
  }
}
