import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/notification_settings_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class SettingsApiException implements Exception {
  final String message;
  final int? statusCode;
  const SettingsApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class NotificationsSettingsService {
  NotificationsSettingsService._();
  static final NotificationsSettingsService instance =
  NotificationsSettingsService._();

  final _client = http.Client();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _handleResponse(http.Response r) {
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    throw SettingsApiException(
      body['message'] as String? ?? 'Something went wrong.',
      statusCode: r.statusCode,
    );
  }

  // ─── §1.8 Notifications ───────────────────────────────────────────────────

  /// GET /api/customer/notifications
  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final h = await _authHeaders();
      final r = await _client
          .get(Uri.parse('$_baseUrl/api/customer/notifications'), headers: h)
          .timeout(_timeout);
      final data = _handleResponse(r);
      final list = data['notifications'] as List<dynamic>? ?? [];
      return list
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
    } on SocketException {
      throw const SettingsApiException('No internet connection.');
    } on _Timeout {
      throw const SettingsApiException('Connection timed out.');
    }
  }

  /// PUT /api/notifications/:id/read  (single)
  Future<void> markRead(int notificationId) async {
    try {
      final h = await _authHeaders();
      await _client
          .put(
        Uri.parse('$_baseUrl/api/notifications/$notificationId/read'),
        headers: h,
      )
          .timeout(_timeout);
    } catch (_) {
      // silently fail — non-critical
    }
  }

  /// PUT /api/notifications/read-all
  Future<void> markAllRead() async {
    try {
      final h = await _authHeaders();
      await _client
          .put(
        Uri.parse('$_baseUrl/api/notifications/read-all'),
        headers: h,
      )
          .timeout(_timeout);
    } catch (_) {}
  }

  // ─── §1.9 Account Settings ────────────────────────────────────────────────

  /// GET /api/customer/profile
  Future<AccountProfile> fetchProfile() async {
    try {
      final h = await _authHeaders();
      final r = await _client
          .get(Uri.parse('$_baseUrl/api/customer/profile'), headers: h)
          .timeout(_timeout);
      return AccountProfile.fromJson(_handleResponse(r));
    } on SocketException {
      throw const SettingsApiException('No internet connection.');
    } on _Timeout {
      throw const SettingsApiException('Connection timed out.');
    }
  }

  /// PUT /api/customer/profile
  Future<AccountProfile> updateProfile(UpdateProfileRequest req) async {
    try {
      final h = await _authHeaders();
      final r = await _client
          .put(
        Uri.parse('$_baseUrl/api/customer/profile'),
        headers: h,
        body: jsonEncode(req.toJson()),
      )
          .timeout(_timeout);
      return AccountProfile.fromJson(_handleResponse(r));
    } on SocketException {
      throw const SettingsApiException('No internet connection.');
    } on _Timeout {
      throw const SettingsApiException('Connection timed out.');
    }
  }

  /// POST /api/auth/change-password
  Future<void> changePassword(ChangePasswordRequest req) async {
    try {
      final h = await _authHeaders();
      final r = await _client
          .post(
        Uri.parse('$_baseUrl/api/auth/change-password'),
        headers: h,
        body: jsonEncode(req.toJson()),
      )
          .timeout(_timeout);
      _handleResponse(r);
    } on SocketException {
      throw const SettingsApiException('No internet connection.');
    } on _Timeout {
      throw const SettingsApiException('Connection timed out.');
    }
  }

  /// DELETE /api/customer/saved-payment
  Future<void> removeSavedPayment() async {
    try {
      final h = await _authHeaders();
      await _client
          .delete(
        Uri.parse('$_baseUrl/api/customer/saved-payment'),
        headers: h,
      )
          .timeout(_timeout);
    } on SocketException {
      throw const SettingsApiException('No internet connection.');
    } on _Timeout {
      throw const SettingsApiException('Connection timed out.');
    }
  }
}

class _Timeout implements Exception {
  const _Timeout();
}