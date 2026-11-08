// ─── Business Hours Models ────────────────────────────────────────────────────
// Mirrors GET /api/business-hours. The backend is the source of truth for the
// weekly schedule and the current open/closed state (Asia/Manila time).

const List<String> _dayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// "07:30" → "7:30 AM"
String formatBusinessTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final parts = value.split(':');
  if (parts.length < 2) return value;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;

  final suffix = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

class BusinessHourDay {
  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  const BusinessHourDay({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  factory BusinessHourDay.fromJson(Map<String, dynamic> json) {
    return BusinessHourDay(
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      openTime: json['open_time'] as String?,
      closeTime: json['close_time'] as String?,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }

  String get dayName =>
      dayOfWeek >= 0 && dayOfWeek < _dayNames.length
          ? _dayNames[dayOfWeek]
          : '';

  /// "Open · 7:00 AM – 10:00 PM" style label for the schedule row.
  String get hoursLabel {
    if (isClosed) return 'Closed';
    if (openTime == null || closeTime == null) return 'Hours not set';
    return '${formatBusinessTime(openTime)} – ${formatBusinessTime(closeTime)}';
  }
}

class BusinessHoursStatus {
  final String timezone;
  final bool isOpen;
  final String message;
  final int currentDayOfWeek;
  final String? currentTime;
  final BusinessHourDay? today;
  final BusinessHourDay? nextOpen;
  final List<BusinessHourDay> days;

  const BusinessHoursStatus({
    required this.timezone,
    required this.isOpen,
    required this.message,
    required this.currentDayOfWeek,
    required this.currentTime,
    required this.today,
    required this.nextOpen,
    required this.days,
  });

  factory BusinessHoursStatus.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final currentMap =
        current is Map<String, dynamic> ? current : const <String, dynamic>{};

    final todayJson = json['today'];
    final nextOpenJson = json['next_open'];
    final daysJson = json['days'];

    return BusinessHoursStatus(
      timezone: json['timezone'] as String? ?? 'Asia/Manila',
      isOpen: json['is_open'] as bool? ?? true,
      message: json['message'] as String? ?? 'Open now',
      currentDayOfWeek:
          (currentMap['day_of_week'] as num?)?.toInt() ?? 0,
      currentTime: currentMap['time'] as String?,
      today: todayJson is Map<String, dynamic>
          ? BusinessHourDay.fromJson(todayJson)
          : null,
      nextOpen: nextOpenJson is Map<String, dynamic>
          ? BusinessHourDay.fromJson(nextOpenJson)
          : null,
      days: daysJson is List
          ? daysJson
              .whereType<Map<String, dynamic>>()
              .map(BusinessHourDay.fromJson)
              .toList()
          : const [],
    );
  }

  /// Human-friendly line for the home pill / banner tooltip.
  String get scheduleLabel {
    if (today == null) return message;
    return today!.isClosed
        ? 'Closed today'
        : 'Today: ${today!.hoursLabel}';
  }
}
