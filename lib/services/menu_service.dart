import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/menu_models.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
);

class MenuApiException implements Exception {
  final String message;
  final int? statusCode;
  const MenuApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class MenuService {
  MenuService._();
  static final MenuService instance = MenuService._();

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
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = body['message'] as String? ??
        body['error'] as String? ??
        'Something went wrong.';
    throw MenuApiException(message, statusCode: response.statusCode);
  }

  // ─── 1.3 Digital Menu ─────────────────────────────────────────────────────
  // GET /api/menu
  Future<MenuData> fetchMenu() async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/menu'), headers: headers)
          .timeout(_timeout);
      final data = _handleResponse(response);
      return MenuData.fromJson(data);
    } on SocketException {
      throw const MenuApiException('No internet connection.');
    } on TimeoutException {
      throw const MenuApiException('Connection timed out.');
    }
  }

  // ─── 1.3 Pre-checkout availability check ──────────────────────────────────
  // POST /api/menu/availability-check  { item_ids: [...] }
  // Returns List<Map> with { id, name, is_available } per item.
  Future<List<Map<String, dynamic>>> checkAvailability(List<int> itemIds) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(
        Uri.parse('$_baseUrl/api/menu/availability-check'),
        headers: headers,
        body: jsonEncode({'item_ids': itemIds}),
      )
          .timeout(_timeout);
      final data = _handleResponse(response);
      final items = data['items'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    } on SocketException {
      throw const MenuApiException('No internet connection.');
    } on TimeoutException {
      throw const MenuApiException('Connection timed out.');
    }
  }

  // ─── 1.4 Chatbot ──────────────────────────────────────────────────────────
  // POST /api/chatbot/message
  Future<String> sendChatMessage(String message) async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .post(
        Uri.parse('$_baseUrl/api/chatbot/message'),
        headers: headers,
        body: jsonEncode({'message': message}),
      )
          .timeout(const Duration(seconds: 30)); // chatbot can take longer
      final data = _handleResponse(response);
      return data['reply'] as String? ??
          data['message'] as String? ??
          'Sorry, I couldn\'t process that.';
    } on SocketException {
      throw const MenuApiException('No internet connection.');
    } on TimeoutException {
      throw const MenuApiException('The response took too long.');
    }
  }

  // GET /api/chatbot/history
  Future<ChatHistory?> fetchChatHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/chatbot/history'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 404) return null;
      final data = _handleResponse(response);
      return ChatHistory.fromJson(data);
    } on SocketException {
      return null; // silently fail history load
    } on TimeoutException {
      return null;
    }
  }
}

class TimeoutException implements Exception {
  const TimeoutException();
}