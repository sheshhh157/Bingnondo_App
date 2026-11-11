import 'package:flutter_test/flutter_test.dart';

import '../lib/models/tracking_models.dart';

void main() {
  group('OrderDetail delivery location', () {
    test('reads the delivery pin from order-level fields', () {
      final order = OrderDetail.fromJson({
        'id': 42,
        'order_number': 'BNG-42',
        'status': 'out_for_delivery',
        'payment_method': 'cod',
        'total_amount': 250,
        'items': <dynamic>[],
        'delivery_address': 'Santa Cruz, Laguna',
        'delivery_latitude': 14.2788,
        'delivery_longitude': 121.4117,
        'delivery': {'preference': 'own_delivery', 'status': 'assigned'},
      });

      expect(order.delivery?.deliveryAddress, 'Santa Cruz, Laguna');
      expect(order.delivery?.destinationLatitude, 14.2788);
      expect(order.delivery?.destinationLongitude, 121.4117);
    });

    test('reads string coordinates from nested delivery data', () {
      final order = OrderDetail.fromJson({
        'id': 42,
        'order_number': 'BNG-42',
        'status': 'out_for_delivery',
        'payment_method': 'cod',
        'total_amount': 250,
        'items': <dynamic>[],
        'delivery': {
          'preference': 'own_delivery',
          'status': 'assigned',
          'delivery_address': 'Santa Cruz, Laguna',
          'latitude': '14.2788',
          'longitude': '121.4117',
        },
      });

      expect(order.delivery?.destinationLatitude, 14.2788);
      expect(order.delivery?.destinationLongitude, 121.4117);
    });
  });
}
