// ─── Review Model ─────────────────────────────────────────────────────────────
// Ratings & reviews for a menu item.
//
// NOTE: The backend endpoint for this is not built yet. The UI + provider are
// wired so that dropping in the real API only requires `ReviewService`.

class Review {
  final int id;
  final String authorName;
  final double rating; // 1.0 .. 5.0
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      authorName:
          (json['author_name'] ?? json['customer_name'] ?? 'Anonymous') as String,
      rating: (json['rating'] as num).toDouble(),
      comment: (json['comment'] ?? '') as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
