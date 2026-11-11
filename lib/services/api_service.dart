import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── API Configuration ──────────────────────────────────────────────────────

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
);

// ─── API Exception ──────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() => message;

  bool get isNetworkError  => statusCode == null;
  bool get isAuthError     => statusCode == 401;
  bool get isConflict      => statusCode == 409;
  bool get isValidationError => statusCode == 422;
  bool get isNotFound      => statusCode == 404;
}

// ─── Auth Responses ─────────────────────────────────────────────────────────

class AuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final CustomerUser? user;
  final String? message;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken:  json['accessToken']  as String?,
      refreshToken: json['refreshToken'] as String?,
      user: json['user'] != null
          ? CustomerUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

// ─── Customer User ──────────────────────────────────────────────────────────

class CustomerUser {
  final int id;
  final String? email;
  final String? mobileNumber;
  final bool emailVerified;
  final bool profileCompleted;
  final String status;
  final String? firstName;
  final String? lastName;

  CustomerUser({
    required this.id,
    this.email,
    this.mobileNumber,
    required this.emailVerified,
    required this.profileCompleted,
    required this.status,
    this.firstName,
    this.lastName,
  });

  factory CustomerUser.fromJson(Map<String, dynamic> json) {
    return CustomerUser(
      id:               json['id'] as int,
      email:            json['email'] as String?,
      mobileNumber:     json['mobile_number'] as String?,
      emailVerified:    json['email_verified']   as bool? ?? false,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      status:           json['status'] as String? ?? 'awaiting_verification',
      firstName:        json['first_name'] as String?,
      lastName:         json['last_name']  as String?,
    );
  }
}

// ─── API Service ────────────────────────────────────────────────────────────

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final _client = http.Client();
  static const Duration _timeout = Duration(seconds: 15);

  // ─── Token Management ────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token',  value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: 'access_token');
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  // ─── HTTP Helpers ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
      String path,
      Map<String, dynamic> body, {
        bool requiresAuth = false,
      }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };

    if (requiresAuth) {
      final token = await getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('No internet connection. Please check your network.');
    } on HttpException {
      throw const ApiException('Network error. Please try again.');
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please try again.');
    } on FormatException {
      throw const ApiException('Invalid response from server. Please try again.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = {};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message =
        body['message'] as String? ??
        body['error']   as String? ??
        'Something went wrong. Please try again.';

    throw ApiException(message, statusCode: response.statusCode);
  }

  // ─── Auth Endpoints ──────────────────────────────────────────────────────

  /// POST /api/auth/customer/register
  /// Email registration — sends OTP to email
  Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    final data = await _post(
      '/api/auth/customer/register',
      {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(data);
  }

  /// POST /api/auth/customer/verify-otp
  /// purpose: email_verification | password_reset
  Future<AuthResponse> verifyOtp({
    required String contact,
    required String otp,
    String purpose = 'email_verification',
  }) async {
    final data = await _post(
      '/api/auth/customer/verify-otp',
      {'contact': contact, 'otp': otp, 'purpose': purpose},
    );

    final response = AuthResponse.fromJson(data);

    if (response.accessToken != null && response.refreshToken != null) {
      await saveTokens(
        accessToken:  response.accessToken!,
        refreshToken: response.refreshToken!,
      );
    }

    return response;
  }

  /// POST /api/auth/customer/login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _post(
      '/api/auth/customer/login',
      {'email': email, 'password': password},
    );

    final response = AuthResponse.fromJson(data);

    if (response.accessToken != null && response.refreshToken != null) {
      await saveTokens(
        accessToken:  response.accessToken!,
        refreshToken: response.refreshToken!,
      );
    }

    return response;
  }

  /// POST /api/auth/customer/verify-otp  (purpose = password_reset)
  Future<void> verifyPasswordResetOtp({
    required String contact,
    required String otp,
  }) async {
    await _post(
      '/api/auth/customer/verify-otp',
      {'contact': contact, 'otp': otp, 'purpose': 'password_reset'},
    );
  }

  /// POST /api/auth/forgot-password  (via email)
  Future<void> forgotPassword({required String email}) async {
    await _post(
      '/api/auth/forgot-password',
      {'email': email.trim().toLowerCase()},
    );
  }

  /// POST /api/auth/reset-password
  /// contact = email address
  Future<void> resetPassword({
    required String contact,
    required String otp,
    required String newPassword,
  }) async {
    await _post(
      '/api/auth/reset-password',
      {'contact': contact, 'otp': otp, 'new_password': newPassword},
    );
  }

  /// POST /api/auth/customer/resend-otp
  Future<void> resendOtp({
    required String contact,
    String purpose = 'email_verification',
  }) async {
    await _post(
      '/api/auth/customer/resend-otp',
      {'contact': contact, 'purpose': purpose},
    );
  }
}
