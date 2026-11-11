/**
 * geo_service.dart  —  Address pin-drop API layer
 * ──────────────────────────────────────────────────────
 * Covers:
 *   GET /api/geo/reverse?lat=&lng=       → reverseGeocode()
 *   GET /api/geo/search?q=&lat=&lng=     → search()
 *
 * The backend proxies OpenStreetMap Nominatim so no API key is needed on the
 * device and the usage-policy throttling/caching stays server-side.
 */

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/geo_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
);

class GeoApiException implements Exception {
  final String message;
  final int?   statusCode;
  final String? code;

  const GeoApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

class GeoService {
  GeoService._();
  static final GeoService instance = GeoService._();

  final _client  = http.Client();
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

  Map<String, dynamic> _handle(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    throw GeoApiException(
      body['message'] as String? ?? 'Something went wrong.',
      statusCode: response.statusCode,
      code: body['code'] as String?,
    );
  }

  /// Reverse geocode a pin → complete address.
  Future<PickedAddress> reverse({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$_baseUrl/api/geo/reverse').replace(queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      });
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      return PickedAddress.fromJson(_handle(response));
    } on SocketException {
      throw const GeoApiException('No internet connection.');
    } on GeoApiException {
      rethrow;
    } catch (_) {
      throw const GeoApiException('Could not fetch the address. Please try again.');
    }
  }

  /// Forward search for a place / street / landmark.
  ///
  /// [viewbox] is "west,north,east,south". When [bounded] is true the backend
  /// only returns places inside that box — used to keep the search within the
  /// delivery area.
  Future<List<PlaceSearchResult>> search(
    String query, {
    double? nearLatitude,
    double? nearLongitude,
    String? viewbox,
    bool bounded = false,
  }) async {
    try {
      final headers = await _authHeaders();
      final params = <String, String>{'q': query};
      if (nearLatitude != null)  params['lat'] = nearLatitude.toString();
      if (nearLongitude != null) params['lng'] = nearLongitude.toString();
      if (viewbox != null && viewbox.isNotEmpty) {
        params['viewbox'] = viewbox;
        params['bounded'] = bounded ? '1' : '0';
      }

      final uri = Uri.parse('$_baseUrl/api/geo/search').replace(queryParameters: params);
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      final data = _handle(response);
      final list = data['results'] as List<dynamic>? ?? [];
      return list
          .map((e) => PlaceSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } on SocketException {
      throw const GeoApiException('No internet connection.');
    } on GeoApiException {
      rethrow;
    } catch (_) {
      throw const GeoApiException('Search failed. Please try again.');
    }
  }
}
