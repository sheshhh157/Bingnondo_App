import 'package:flutter_test/flutter_test.dart';

import 'package:bingnondo_app/models/cart_models.dart';
import 'package:bingnondo_app/models/notification_settings_models.dart';

void main() {
  const mobileOnlyProfile = {
    'id': 42,
    'email': null,
    'first_name': null,
    'last_name': null,
    'mobile_number': '09171234567',
    'address': null,
    'latitude': null,
    'longitude': null,
    'profile_completed': false,
    'restriction_level': 'none',
  };

  test('cart profile supports a mobile-only customer', () {
    final profile = CustomerProfile.fromJson(mobileOnlyProfile);

    expect(profile.email, isNull);
    expect(profile.profileCompleted, isFalse);
    expect(profile.displayName, '09171234567');
  });

  test('account settings profile supports a mobile-only customer', () {
    final profile = AccountProfile.fromJson(mobileOnlyProfile);

    expect(profile.email, isNull);
    expect(profile.profileCompleted, isFalse);
    expect(profile.displayName, '09171234567');
    expect(profile.initials, 'M');
  });
}
