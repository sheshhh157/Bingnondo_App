/**
 * cart_service.dart  —  §1.5 Cart & Checkout API layer
 * ──────────────────────────────────────────────────────
 * Covers:
 *   GET  /api/customer/profile       → fetchProfile()
 *   PUT  /api/customer/profile       → updateProfile()
 *   POST /api/orders                 → placeOrder()
 *
 * Flip kUseMock = false in mock_data.dart to connect to the real backend.
 *
 * GCash receipt upload (POST /api/payments/gcash-receipt) is a separate
 * service call — see gcash_receipt_service.dart (§ future).
 */

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cart_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

// ─── Exception ────────────────────────────────────────────────────────────────

class CartApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code; // backend error code, e.g. 'profile_incomplete', 'items_unavailable'

  const CartApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;

  bool get isProfileIncomplete => code == 'profile_incomplete' || (statusCode == 403 && message.contains('profile'));
  bool get isSuspended         => code == 'suspended'          || (statusCode == 403 && message.contains('suspend'));
  bool get isCodRestricted     => code == 'cod_restricted';
  bool get isItemsUnavailable  => code == 'items_unavailable';
}

// ─── CartService ─────────────────────────────────────────────────────────────

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  final _client  = http.Client();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const Duration _timeout = Duration(seconds: 15);

  // ── Auth headers ───────────────────────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Response handler ───────────────────────────────────────────────────────
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message = body['message'] as String?
        ?? body['error'] as String?
        ?? 'Something went wrong.';
    final code = body['code'] as String?;
    throw CartApiException(message, statusCode: response.statusCode, code: code);
  }

  // ─── GET /api/payments/qr-code ────────────────────────────────────────────
  // Returns { id, name, number, image_url }
  Future<Map<String, dynamic>> fetchActiveQrCode() async {
    try {
      final headers  = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/payments/qr-code'), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const CartApiException('No internet connection.');
    } on CartApiException {
      rethrow;
    } catch (_) {
      throw const CartApiException('Could not fetch QR code.');
    }
  }

  // ─── GET /api/payments/delivery-fee ───────────────────────────────────────
  // Returns { amount: double, enabled: bool }
  Future<Map<String, dynamic>> fetchDeliveryFee() async {
    try {
      final headers  = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/payments/delivery-fee'), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const CartApiException('No internet connection.');
    } on CartApiException {
      rethrow;
    } catch (_) {
      throw const CartApiException('Could not fetch delivery fee.');
    }
  }

  // ─── GET /api/customer/profile ─────────────────────────────────────────────
  // Returns profile + restriction_level.
  // Called by CartProvider.checkProfileGate() before checkout.
  Future<CustomerProfile> fetchProfile() async {
    try {
      final headers  = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/customer/profile'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      return CustomerProfile.fromJson(data);
    } on SocketException {
      throw const CartApiException('No internet connection.');
    } on CartApiException {
      rethrow;
    } catch (_) {
      throw const CartApiException('Connection timed out. Please try again.');
    }
  }

  // ─── PUT /api/customer/profile ─────────────────────────────────────────────
  // Saves first_name, last_name, mobile_number, address (+ optional lat/lng pin).
  // Used by CompleteProfileScreen (§1.1b) and AccountSettingsScreen (§1.9).
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final headers  = await _authHeaders();
      final response = await _client
          .put(
        Uri.parse('$_baseUrl/api/customer/profile'),
        headers: headers,
        body: jsonEncode({
          'first_name':    firstName.trim(),
          'last_name':     lastName.trim(),
          'mobile_number': mobileNumber.trim(),
          'address':       address.trim(),
          if (latitude  != null) 'latitude':  latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      )
          .timeout(_timeout);
      final data = _handleResponse(response);
      return CustomerProfile.fromJson(data);
    } on SocketException {
      throw const CartApiException('No internet connection.');
    } on CartApiException {
      rethrow;
    } catch (_) {
      throw const CartApiException('Connection timed out. Please try again.');
    }
  }

  // ─── POST /api/orders ──────────────────────────────────────────────────────
  // Places a new online order.
  // Body is constructed from PlaceOrderRequest.toJson().
  Future<PlaceOrderResponse> placeOrder(PlaceOrderRequest request) async {
    try {
      final headers  = await _authHeaders();
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
    } on CartApiException {
      rethrow;
    } catch (_) {
      throw const CartApiException('Connection timed out. Please try again.');
    }
  }
}