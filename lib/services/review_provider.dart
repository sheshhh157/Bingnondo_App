import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../mock/mock_data.dart';
import '../models/review_model.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://bingnondobackend-production.up.railway.app',
);

// ─── Eligibility result ────────────────────────────────────────────────────────
class ReviewEligibility {
  final bool canReview;
  final bool alreadyReviewed;

  const ReviewEligibility({
    required this.canReview,
    required this.alreadyReviewed,
  });
}

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

  /// GET /api/menu/items/:id/reviews/can-review
  /// Returns eligibility: can the logged-in customer review this item?
  Future<ReviewEligibility> checkEligibility(int itemId) async {
    if (kUseMock) {
      // In mock mode, always allow reviewing
      return const ReviewEligibility(canReview: true, alreadyReviewed: false);
    }

    try {
      final h = await _authHeaders();
      final r = await _client
          .get(
        Uri.parse('$_baseUrl/api/menu/items/$itemId/reviews/can-review'),
        headers: h,
      )
          .timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        return ReviewEligibility(
          canReview:       body['can_review'] as bool? ?? false,
          alreadyReviewed: body['already_reviewed'] as bool? ?? false,
        );
      }
      // 401 = not logged in → hide "Write a review" button gracefully
      return const ReviewEligibility(canReview: false, alreadyReviewed: false);
    } catch (_) {
      return const ReviewEligibility(canReview: false, alreadyReviewed: false);
    }
  }

  /// GET /api/menu/items/:id/reviews/my-review
  /// Returns the customer's existing review for pre-filling the edit form.
  /// Returns null if no review exists yet.
  Future<Review?> fetchMyReview(int itemId) async {
    if (kUseMock) return null;

    try {
      final h = await _authHeaders();
      final r = await _client
          .get(
        Uri.parse('$_baseUrl/api/menu/items/$itemId/reviews/my-review'),
        headers: h,
      )
          .timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        return Review.fromJson(
            jsonDecode(r.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/menu/items/:id/reviews
  /// Submit (or update) a review. Returns the saved [Review] on success.
  /// Throws a [ReviewSubmitException] with a user-friendly message on failure.
  Future<Review> submitReview({
    required int itemId,
    required int rating,
    required String comment,
  }) async {
    if (kUseMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      // Return a fake review so the UI can update immediately
      return Review(
        id:         999,
        authorName: 'You',
        rating:     rating.toDouble(),
        comment:    comment,
        createdAt:  DateTime.now(),
      );
    }

    try {
      final h = await _authHeaders();
      final r = await _client
          .post(
        Uri.parse('$_baseUrl/api/menu/items/$itemId/reviews'),
        headers: h,
        body: jsonEncode({'rating': rating, 'comment': comment}),
      )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 201 || r.statusCode == 200) {
        final body  = jsonDecode(r.body) as Map<String, dynamic>;
        final data  = body['review'] as Map<String, dynamic>? ?? body;
        return Review.fromJson(data);
      }

      // Parse error message from server
      String message = 'Failed to submit review. Please try again.';
      try {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        message = (body['message'] as String?) ?? message;
      } catch (_) {}

      if (r.statusCode == 403) {
        throw ReviewSubmitException(
          'You can only review items from a completed order.',
        );
      }
      if (r.statusCode == 401) {
        throw ReviewSubmitException('Please log in to submit a review.');
      }
      throw ReviewSubmitException(message);
    } on ReviewSubmitException {
      rethrow;
    } catch (_) {
      throw ReviewSubmitException(
        'Could not connect to the server. Please check your internet connection.',
      );
    }
  }
}

/// Thrown when review submission fails with a user-readable reason.
class ReviewSubmitException implements Exception {
  final String message;
  const ReviewSubmitException(this.message);
}

// ─── Provider ─────────────────────────────────────────────────────────────────
enum ReviewLoadState { initial, loading, loaded, error }

class ReviewProvider extends ChangeNotifier {
  final int itemId;
  ReviewProvider(this.itemId);

  ReviewLoadState _state = ReviewLoadState.initial;
  List<Review> _reviews = [];
  ReviewEligibility? _eligibility;
  bool _submitting = false;
  String? _submitError;

  ReviewLoadState get state       => _state;
  List<Review>   get reviews      => List.unmodifiable(_reviews);
  bool           get isLoading    => _state == ReviewLoadState.loading;
  bool           get hasReviews   => _reviews.isNotEmpty;
  int            get count        => _reviews.length;
  bool           get submitting   => _submitting;
  String?        get submitError  => _submitError;

  // Eligibility: null = not yet checked / user not logged in
  ReviewEligibility? get eligibility => _eligibility;
  bool get canWriteReview    => _eligibility?.canReview ?? false;
  bool get hasAlreadyReviewed => _eligibility?.alreadyReviewed ?? false;

  /// Average rating (0 when there are no reviews).
  double get average {
    if (_reviews.isEmpty) return 0;
    return _reviews.fold<double>(0, (s, r) => s + r.rating) / _reviews.length;
  }

  /// Number of reviews for a given star (1..5).
  int countFor(int star) =>
      _reviews.where((r) => r.rating.round() == star).length;

  /// Load reviews + check eligibility in parallel.
  Future<void> load() async {
    if (_state == ReviewLoadState.loading) return;
    _state = ReviewLoadState.loading;
    notifyListeners();

    try {
      // Run both requests concurrently
      final results = await Future.wait([
        ReviewService.instance.fetchReviews(itemId),
        ReviewService.instance.checkEligibility(itemId),
      ]);

      _reviews     = results[0] as List<Review>;
      _eligibility = results[1] as ReviewEligibility;
      _state       = ReviewLoadState.loaded;
    } catch (_) {
      _reviews = [];
      _state   = ReviewLoadState.error;
    }
    notifyListeners();
  }

  /// Reload just the review list after a submission (to show the new review).
  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        ReviewService.instance.fetchReviews(itemId),
        ReviewService.instance.checkEligibility(itemId),
      ]);
      _reviews     = results[0] as List<Review>;
      _eligibility = results[1] as ReviewEligibility;
      notifyListeners();
    } catch (_) {
      // Silently ignore refresh errors — the existing data stays visible
    }
  }

  /// Submit a review. Returns true on success, false on failure.
  /// Check [submitError] for the user-facing error message.
  Future<bool> submitReview({
    required int    rating,
    required String comment,
  }) async {
    _submitting  = true;
    _submitError = null;
    notifyListeners();

    try {
      final newReview = await ReviewService.instance.submitReview(
        itemId:  itemId,
        rating:  rating,
        comment: comment,
      );

      // Optimistically insert the new review at the top, or replace existing
      _reviews = [
        newReview,
        ..._reviews.where((r) => r.id != newReview.id),
      ];

      // Mark as already reviewed so the button label updates
      _eligibility = ReviewEligibility(
        canReview:       true,
        alreadyReviewed: true,
      );

      _submitting = false;
      notifyListeners();

      // Background refresh to get server-accurate data
      refresh();
      return true;
    } on ReviewSubmitException catch (e) {
      _submitError = e.message;
      _submitting  = false;
      notifyListeners();
      return false;
    }
  }
}