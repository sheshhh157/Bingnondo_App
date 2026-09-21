// ─── Announcement Model ────────────────────────────────────────────────────────

enum AnnouncementType { discount, newMenu, event, general }

extension AnnouncementTypeX on AnnouncementType {
  static AnnouncementType fromString(String v) {
    switch (v) {
      case 'discount':  return AnnouncementType.discount;
      case 'new_menu':  return AnnouncementType.newMenu;
      case 'event':     return AnnouncementType.event;
      default:          return AnnouncementType.general;
    }
  }

  String get badge {
    switch (this) {
      case AnnouncementType.discount:  return 'PROMO';
      case AnnouncementType.newMenu:   return 'NEW';
      case AnnouncementType.event:     return 'EVENT';
      case AnnouncementType.general:   return 'INFO';
    }
  }
}

class Announcement {
  final int id;
  final AnnouncementType type;
  final String title;
  final String body;
  final String? ctaLabel;   // e.g. "Order Now"
  final String? ctaRoute;   // internal route or URL
  final bool isNew;
  final DateTime publishedAt;

  const Announcement({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaRoute,
    required this.isNew,
    required this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as int,
      type: AnnouncementTypeX.fromString(json['type'] as String? ?? 'general'),
      title: json['title'] as String,
      body: json['body'] as String,
      ctaLabel: json['cta_label'] as String?,
      ctaRoute: json['cta_route'] as String?,
      isNew: json['is_new'] as bool? ?? false,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }
}