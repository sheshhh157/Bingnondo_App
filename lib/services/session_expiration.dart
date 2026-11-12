import 'dart:convert';

DateTime? customerAccessTokenExpiry(String? token) {
  if (token == null) return null;

  final segments = token.split('.');
  if (segments.length != 3) return null;

  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
    );
    if (payload is! Map<String, dynamic>) return null;

    final expirySeconds = payload['exp'];
    if (expirySeconds is! num || !expirySeconds.isFinite) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      expirySeconds.toInt() * 1000,
      isUtc: true,
    );
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}
