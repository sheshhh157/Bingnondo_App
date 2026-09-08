import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/tracking_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class TrackingApiException implements Exception {
  final String message;
  final int? statusCode;
  const TrackingApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

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

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message =
        body['message'] as String? ?? body['error'] as String? ?? 'Something went wrong.';
    throw TrackingApiException(message, statusCode: response.statusCode);
  }

  // ─── §1.6 Order Tracking ──────────────────────────────────────────────────

  /// GET /api/orders/:id
  Future<OrderDetail> fetchOrder(int orderId) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/orders/$orderId'), headers: headers)
          .timeout(_timeout);
      return OrderDetail.fromJson(_handleResponse(response));
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on _TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// POST /api/orders/:id/cancel
  Future<void> cancelOrder(int orderId) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(Uri.parse('$_baseUrl/api/orders/$orderId/cancel'),
          headers: headers)
          .timeout(_timeout);
      _handleResponse(response);
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on _TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  // ─── §1.7 Support Chat ────────────────────────────────────────────────────

  /// GET /api/support-chat
  Future<SupportChat?> fetchSupportChat() async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/support-chat'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 404) return null;
      return SupportChat.fromJson(_handleResponse(response));
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on _TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// POST /api/support-chat/message
  Future<SupportMessage> sendSupportMessage({
    required String content,
    int? relatedOrderId,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(
        Uri.parse('$_baseUrl/api/support-chat/message'),
        headers: headers,
        body: jsonEncode({
          'content': content,
          if (relatedOrderId != null) 'related_order_id': relatedOrderId,
        }),
      )
          .timeout(_timeout);
      final data = _handleResponse(response);
      return SupportMessage.fromJson(data['message'] as Map<String, dynamic>);
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on _TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// PUT /api/notifications/:id/read  (mark support messages read)
  Future<void> markMessagesRead() async {
    try {
      final headers = await _authHeaders();
      await _client
          .put(Uri.parse('$_baseUrl/api/support-chat/read'), headers: headers)
          .timeout(_timeout);
    } catch (_) {
      // silently fail — read receipts are non-critical
    }
  }
}

class _TimeoutException implements Exception {
  const _TimeoutException();
}