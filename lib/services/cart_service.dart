import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cart_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class CartApiException implements Exception {
  final String message;
  final int? statusCode;
  const CartApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
  bool get isProfileIncomplete => statusCode == 403 && message.contains('profile');
  bool get isSuspended => statusCode == 403 && message.contains('suspend');
}

class CartService {
  CartService._();
  static final CartService instance = CartService._();

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
    final message = body['message'] as String? ?? body['error'] as String? ?? 'Something went wrong.';
    throw CartApiException(message, statusCode: response.statusCode);
  }

  // ─── GET /api/customer/profile ────────────────────────────────────────────
  // Used for gate check: profile_completed + restriction_level
  Future<CustomerProfile> fetchProfile() async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/customer/profile'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      return CustomerProfile.fromJson(data);
    } on SocketException {
      throw const CartApiException('No internet connection.');
    } on TimeoutException {
      throw const CartApiException('Connection timed out.');
    }
  }

  // ─── POST /api/orders ─────────────────────────────────────────────────────
  Future<PlaceOrderResponse> placeOrder(PlaceOrderRequest request) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(
        Uri.parse('$_baseUrl/api/orders'),
        headers: headers,
        body: jsonEncode(request.toJson()),
      )
          .timeout(_timeout);
      final data = _handleResponse(response);
      return PlaceOrderResponse.fromJson(data);
    } on SocketException {
      throw const CartApiException('No internet connection.');
    } on TimeoutException {
      throw const CartApiException('Connection timed out. Please try again.');
    }
  }
}

class TimeoutException implements Exception {
  const TimeoutException();
}