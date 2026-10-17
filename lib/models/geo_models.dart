// ─── Geo / Address Picker Models ──────────────────────────────────────────────

/// A delivery location chosen by pin-drop on the map (or from the saved profile).
///
/// [latitude]/[longitude] may be null for legacy saved addresses that predate
/// the map picker — in that case only [address] is known.
class PickedAddress {
  final String  address;
  final double? latitude;
  final double? longitude;
  final String? displayName;

  const PickedAddress({
    required this.address,
    this.latitude,
    this.longitude,
    this.displayName,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isEmpty        => address.trim().isEmpty;

  factory PickedAddress.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    return PickedAddress(
      address:     (json['address'] as String?) ?? '',
      latitude:    lat is num ? lat.toDouble() : null,
      longitude:   lng is num ? lng.toDouble() : null,
      displayName: json['display_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'address':   address,
        if (latitude  != null) 'latitude':  latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// One hit from the address search box.
class PlaceSearchResult {
  final String  displayName;
  final String  address;
  final double  latitude;
  final double  longitude;

  const PlaceSearchResult({
    required this.displayName,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    return PlaceSearchResult(
      displayName: (json['display_name'] as String?) ?? '',
      address:     (json['address'] as String?) ?? (json['display_name'] as String?) ?? '',
      latitude:    (json['latitude'] as num).toDouble(),
      longitude:   (json['longitude'] as num).toDouble(),
    );
  }
}
