import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/business_hours_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
);

class BusinessHoursApiException implements Exception {
  final String message;
  const BusinessHoursApiException(this.message);

  @override
  String toString() => message;
}

/// GET /api/business-hours — weekly schedule + current open/closed state.
class BusinessHoursService {
  BusinessHoursService._();

  static final BusinessHoursService instance = BusinessHoursService._();

  final _client = http.Client();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<BusinessHoursStatus> fetchStatus() async {
    try {
      final headers = await _headers();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/business-hours'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const BusinessHoursApiException(
          'Could not check business hours.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const BusinessHoursApiException(
          'Invalid business hours response.',
        );
      }

      return BusinessHoursStatus.fromJson(decoded);
    } on SocketException {
      throw const BusinessHoursApiException('No internet connection.');
    } on TimeoutException {
      throw const BusinessHoursApiException('Connection timed out.');
    } on FormatException {
      throw const BusinessHoursApiException(
        'Invalid business hours response.',
      );
    }
  }
}
