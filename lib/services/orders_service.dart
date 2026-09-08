import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/order_summary_model.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class OrdersApiException implements Exception {
  final String message;
  const OrdersApiException(this.message);
  @override
  String toString() => message;
}

class OrdersService {
  OrdersService._();
  static final OrdersService instance = OrdersService._();

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

  /// GET /api/orders
  /// Returns all customer orders sorted newest first.
  Future<List<OrderSummary>> fetchOrders() async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/orders'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final list = body['orders'] as List<dynamic>? ?? [];
        return list
            .map((o) => OrderSummary.fromJson(o as Map<String, dynamic>))
            .toList();
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw OrdersApiException(
          body['message'] as String? ?? 'Could not fetch orders.');
    } on SocketException {
      throw const OrdersApiException('No internet connection.');
    } on _Timeout {
      throw const OrdersApiException('Connection timed out.');
    }
  }
}

class _Timeout implements Exception {
  const _Timeout();
}