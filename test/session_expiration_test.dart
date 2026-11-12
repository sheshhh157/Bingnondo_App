import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bingnondo_app/services/session_expiration.dart';

String _tokenWithExpiry(Object? expiry) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': expiry})))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  test('reads the token expiry as a UTC date', () {
    final expectedExpiry = DateTime.utc(2026, 11, 12, 16);
    final expirySeconds = expectedExpiry.millisecondsSinceEpoch ~/ 1000;
    final expiry = customerAccessTokenExpiry(_tokenWithExpiry(expirySeconds));

    expect(expiry, expectedExpiry);
  });

  test('returns null for malformed or missing expiry claims', () {
    expect(customerAccessTokenExpiry('not-a-jwt'), isNull);
    expect(customerAccessTokenExpiry(_tokenWithExpiry(null)), isNull);
  });
}
