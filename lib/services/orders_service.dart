import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/order_summary_model.dart';
import 'gcash_receipt_service.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
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

  /// POST /api/orders/:id/reupload-receipt
  /// Called after staff rejects the GCash receipt.
  /// Uploads a new image, extracts ref + amount, saves to the order's payment row.
  Future<GcashExtractResult> reuploadReceipt({
    required int    orderId,
    required File   imageFile,
    required String mimeType,
  }) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final uri   = Uri.parse('$_baseUrl/api/orders/$orderId/reupload-receipt');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
          'receipt',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final body     = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return GcashExtractResult.fromJson(body);
      }

      throw OrdersApiException(
          body['message'] as String? ?? 'Upload failed.');
    } on SocketException {
      throw const OrdersApiException('No internet connection.');
    } on OrdersApiException {
      rethrow;
    } catch (e) {
      throw OrdersApiException('Upload failed: ${e.toString()}');
    }
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