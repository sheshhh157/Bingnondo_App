import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../mock/mock_data.dart';
import '../models/review_model.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

// ─── Service ──────────────────────────────────────────────────────────────────
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

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

  /// GET /api/menu/items/:id/reviews
  /// Returns a list of reviews for the given menu item.
  Future<List<Review>> fetchReviews(int itemId) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return kMockReviewsForItem(itemId)
          .map((j) => Review.fromJson(j))
          .toList();
    }

    try {
      final h = await _authHeaders();
      final r = await _client
          .get(
            Uri.parse('$_baseUrl/api/menu/items/$itemId/reviews'),
            headers: h,
          )
          .timeout(const Duration(seconds: 10));

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final list = body['reviews'] as List<dynamic>? ?? [];
        return list
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
enum ReviewLoadState { initial, loading, loaded, error }

class ReviewProvider extends ChangeNotifier {
  final int itemId;
  ReviewProvider(this.itemId);

  ReviewLoadState _state = ReviewLoadState.initial;
  List<Review> _reviews = [];

  ReviewLoadState get state => _state;
  List<Review> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _state == ReviewLoadState.loading;
  bool get hasReviews => _reviews.isNotEmpty;
  int get count => _reviews.length;

  /// Average rating (0 when there are no reviews).
  double get average {
    if (_reviews.isEmpty) return 0;
    return _reviews.fold<double>(0, (s, r) => s + r.rating) / _reviews.length;
  }

  /// Number of reviews for a given star (1..5).
  int countFor(int star) =>
      _reviews.where((r) => r.rating.round() == star).length;

  Future<void> load() async {
    if (_state == ReviewLoadState.loading) return;
    _state = ReviewLoadState.loading;
    notifyListeners();

    try {
      _reviews = await ReviewService.instance.fetchReviews(itemId);
      _state = ReviewLoadState.loaded;
    } catch (_) {
      _reviews = [];
      _state = ReviewLoadState.error;
    }
    notifyListeners();
  }
}
