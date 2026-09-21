import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/announcement_model.dart';
import '../mock/mock_data.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

// ─── Service ──────────────────────────────────────────────────────────────────
class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  final _client = http.Client();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/announcements?active=true
  Future<List<Announcement>> fetchAnnouncements() async {
    try {
      final h = await _authHeaders();
      final r = await _client
          .get(
        Uri.parse('$_baseUrl/api/announcements?active=true'),
        headers: h,
      )
          .timeout(const Duration(seconds: 10));

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final list = body['announcements'] as List<dynamic>? ?? [];
        return list
            .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class AnnouncementProvider extends ChangeNotifier {
  List<Announcement> _announcements = [];
  bool _hasNew = false;
  bool _panelOpen = false;
  bool _loaded = false;

  List<Announcement> get announcements => List.unmodifiable(_announcements);
  bool get hasNew => _hasNew;
  bool get panelOpen => _panelOpen;
  bool get hasAnnouncements => _announcements.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 400));
        _announcements = kMockAnnouncements
            .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
            .toList();
      } else {
        _announcements = await AnnouncementService.instance.fetchAnnouncements();
      }
      _hasNew = _announcements.any((a) => a.isNew);
    } catch (_) {
      _announcements = [];
      _hasNew = false;
    }
    notifyListeners();
  }

  void openPanel() {
    _panelOpen = true;
    notifyListeners();
  }

  void closePanel() {
    _panelOpen = false;
    notifyListeners();
  }

  void togglePanel() {
    _panelOpen = !_panelOpen;
    notifyListeners();
  }

  // Called when user has seen announcements — clear new badge
  void markSeen() {
    _hasNew = false;
    notifyListeners();
  }
}