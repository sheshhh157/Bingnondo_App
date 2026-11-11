import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import '../models/tracking_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
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
        body['message'] as String? ??
        body['error'] as String? ??
        'Something went wrong.';
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
    } on TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// GET /api/orders/:id/timeline
  Future<OrderTimeline> fetchOrderTimeline(int orderId) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/orders/$orderId/timeline'),
            headers: headers,
          )
          .timeout(_timeout);
      return OrderTimeline.fromJson(_handleResponse(response));
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// GET /api/orders/:id/status
  Future<OrderStatusPoll> fetchOrderStatus(int orderId) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/orders/$orderId/status'),
            headers: headers,
          )
          .timeout(_timeout);
      return OrderStatusPoll.fromJson(_handleResponse(response));
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// POST /api/orders/:id/cancel
  Future<void> cancelOrder(int orderId) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/orders/$orderId/cancel'),
            headers: headers,
          )
          .timeout(_timeout);
      _handleResponse(response);
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on TimeoutException {
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
    } on TimeoutException {
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
    } on TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// PUT /api/support-chat/read
  Future<void> markMessagesRead() async {
    try {
      final headers = await _authHeaders();
      await _client
          .put(Uri.parse('$_baseUrl/api/support-chat/read'), headers: headers)
          .timeout(_timeout);
    } catch (_) {}
  }

  // ─── §1.9 Rider Live Location ─────────────────────────────────────────────

  /// GET /api/orders/:id/rider-location
  Future<RiderLocation?> fetchRiderLocation(int orderId) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/orders/$orderId/rider-location'),
            headers: headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 204 || response.statusCode == 404) return null;
      return RiderLocation.fromJson(_handleResponse(response));
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on TimeoutException {
      throw const TrackingApiException('Connection timed out.');
    }
  }

  /// Get a drivable road route between the rider and the delivery pin.
  Future<List<LatLng>> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!_isValidPoint(origin) || !_isValidPoint(destination)) {
      throw const TrackingApiException('Delivery location is invalid.');
    }

    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}',
      {'overview': 'full', 'geometries': 'geojson'},
    );

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TrackingApiException(
          'Could not load the rider route.',
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['code'] != 'Ok') {
        throw const TrackingApiException('No driving route is available.');
      }

      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) {
        throw const TrackingApiException('No driving route is available.');
      }
      final firstRoute = routes.first;
      final geometry = firstRoute is Map<String, dynamic>
          ? firstRoute['geometry']
          : null;
      final coordinates = geometry is Map<String, dynamic>
          ? geometry['coordinates']
          : null;
      if (coordinates is! List || coordinates.length < 2) {
        throw const TrackingApiException('No driving route is available.');
      }

      return coordinates
          .map((coordinate) {
            if (coordinate is! List ||
                coordinate.length < 2 ||
                coordinate[0] is! num ||
                coordinate[1] is! num) {
              throw const TrackingApiException('The rider route is invalid.');
            }
            return LatLng(
              (coordinate[1] as num).toDouble(),
              (coordinate[0] as num).toDouble(),
            );
          })
          .toList(growable: false);
    } on SocketException {
      throw const TrackingApiException('No internet connection.');
    } on TimeoutException {
      throw const TrackingApiException('Route request timed out.');
    } on http.ClientException {
      throw const TrackingApiException(
        'Could not connect to the routing service.',
      );
    } on FormatException {
      throw const TrackingApiException('Could not read the rider route.');
    }
  }

  bool _isValidPoint(LatLng point) =>
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;
}
