/**
 * address_picker_screen.dart  —  Pin-drop address picker
 * ─────────────────────────────────────────────────────────
 * Full-screen OpenStreetMap (flutter_map) with a fixed centre pin.
 * Drag the map → the pin stays centred → we reverse-geocode the centre into a
 * complete address via the backend (GET /api/geo/reverse).
 *
 * Extras:
 *   • Search box    → GET /api/geo/search
 *   • "Use my current location" → geolocator
 *
 * Returns a [PickedAddress] via Navigator.pop when the user confirms.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/geo_models.dart';
import '../../services/geo_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Default map centre — Santa Cruz, Laguna (our only delivery area for now).
const LatLng _kDefaultCenter = LatLng(14.2818, 121.4149);

/// Delivery area — the pin (map centre) is constrained to this box, so a
/// customer can only drop a pin inside Santa Cruz, Laguna.
///
/// Bounds from OpenStreetMap (relation 1506709):
///   south 14.21615, north 14.32335, west 121.36056, east 121.43361.
final LatLngBounds _kDeliveryArea = LatLngBounds(
  const LatLng(14.21615, 121.36056), // south-west
  const LatLng(14.32335, 121.43361), // north-east
);

/// "west,north,east,south" — box sent to the backend place search so it only
/// returns results inside [_kDeliveryArea].
String get _kDeliveryViewbox =>
    '${_kDeliveryArea.west},${_kDeliveryArea.north},'
    '${_kDeliveryArea.east},${_kDeliveryArea.south}';

class AddressPickerScreen extends StatefulWidget {
  /// Pre-selected address (editing an existing one). May be null for a fresh pin.
  final PickedAddress? initial;

  const AddressPickerScreen({super.key, this.initial});

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final MapController _mapController = MapController();

  late LatLng _center;

  PickedAddress? _resolved;     // last successfully resolved address
  bool           _isResolving = false;
  String?        _resolveError;

  Timer?         _debounce;
  int            _requestSeq = 0; // guards against out-of-order responses

  // Search
  final _searchCtrl = TextEditingController();
  bool  _searchMode    = false;
  bool  _isSearching   = false;
  String? _searchError;
  List<PlaceSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();

    // A saved pin outside the delivery area (e.g. a legacy address) can't be
    // kept — fall back to the default centre so the customer re-pins inside
    // Santa Cruz, Laguna.
    final initial = widget.initial;
    final initialInArea = initial?.hasCoordinates == true &&
        _kDeliveryArea.contains(LatLng(initial!.latitude!, initial.longitude!));

    _center = initialInArea
        ? LatLng(initial.latitude!, initial.longitude!)
        : _kDefaultCenter;

    _resolved = initialInArea ? initial : null;

    // If we don't have a resolved address yet, fetch it once the map is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resolved == null || !_resolved!.hasCoordinates) {
        _resolveCenter();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Reverse geocoding ──────────────────────────────────────────────────────

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    // Keep _center in sync so the Retry button re-resolves the current pin
    // (not the original one), even though the map is the source of truth.
    _center = camera.center;
    if (!hasGesture) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _resolveAt(camera.center);
    });
  }

  Future<void> _resolveCenter() => _resolveAt(_center);

  Future<void> _resolveAt(LatLng point) async {
    final seq = ++_requestSeq;
    setState(() {
      _isResolving  = true;
      _resolveError = null;
    });

    try {
      final picked = await GeoService.instance.reverse(
        latitude:  point.latitude,
        longitude: point.longitude,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _resolved     = picked;
        _isResolving  = false;
      });
    } on GeoApiException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _isResolving  = false;
        _resolveError = e.message;
      });
    }
  }

  // ─── Move helpers ───────────────────────────────────────────────────────────

  void _moveTo(LatLng point, {bool resolve = true}) {
    _mapController.move(point, _mapController.camera.zoom);
    // The camera constraint may have clamped the centre into the delivery area,
    // so resolve the *actual* centre, not the requested point.
    final center = _mapController.camera.center;
    setState(() => _center = center);
    if (resolve) _resolveAt(center);
  }

  Future<void> _goToMyLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission denied. You can still drag the map.');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Please turn on your location services.');
        return;
      }

      setState(() => _isResolving = true);
      final position = await Geolocator.getCurrentPosition();
      final here = LatLng(position.latitude, position.longitude);

      if (!_kDeliveryArea.contains(here)) {
        _snack('Sorry, we only deliver within Santa Cruz, Laguna. '
            'The pin was moved to the nearest point inside the area.');
      }
      _moveTo(here);
    } catch (_) {
      if (mounted) setState(() => _isResolving = false);
      _snack('Could not get your location. Please drag the map instead.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.karla(fontSize: 13)),
      backgroundColor: AppColors.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ));
  }

  // ─── Search ─────────────────────────────────────────────────────────────────

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) {
      setState(() => _searchError = 'Type at least 3 characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchError = null;
      _results     = const [];
    });

    try {
      final results = await GeoService.instance.search(
        q,
        nearLatitude:  _center.latitude,
        nearLongitude: _center.longitude,
        viewbox:       _kDeliveryViewbox,
        bounded:       true,
      );
      if (!mounted) return;
      setState(() {
        _results     = results;
        _isSearching = false;
        _searchError = results.isEmpty ? 'No places found. Try a different search.' : null;
      });
    } on GeoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.message;
      });
    }
  }

  void _pickSearchResult(PlaceSearchResult r) {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchMode = false;
      _results    = const [];
    });
    _moveTo(LatLng(r.latitude, r.longitude));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildMap(),
          _buildCenterPin(),
          _buildTopBar(),
          if (_searchMode) _buildSearchPanel(),
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 16,
        minZoom: 11,
        maxZoom: 19,
        // Keep the pin (map centre) inside the delivery area.
        cameraConstraint: CameraConstraint.containCenter(bounds: _kDeliveryArea),
        onPositionChanged: _onMapMoved,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bingnondo_app',
          maxZoom: 19,
        ),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  /// Fixed centre pin — the map moves underneath it.
  Widget _buildCenterPin() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('Pin here',
                    style: GoogleFonts.karla(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDark)),
              ),
              const SizedBox(height: 4),
              Icon(Icons.location_pin, size: 44, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _circleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            if (!_searchMode)
              _circleButton(
                icon: Icons.search_rounded,
                onTap: () => setState(() => _searchMode = true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xxl + AppSpacing.sm, AppSpacing.md, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      style: GoogleFonts.karla(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search within Santa Cruz, Laguna…',
                        hintStyle: GoogleFonts.karla(
                            fontSize: 13, color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textMuted),
                    onPressed: () => setState(() {
                      _searchMode = false;
                      _results    = const [];
                      _searchError = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2.5)),
              ),
            if (_searchError != null)
              _panelMessage(_searchError!),
            if (_results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                // Material gives the ListTiles a Material ancestor to paint
                // their ink splash on (the colored Container hides them).
                child: Material(
                  color: Colors.transparent,
                  child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined,
                          color: AppColors.gold, size: 20),
                      title: Text(
                        r.address.isNotEmpty ? r.address : r.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.karla(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                      subtitle: r.address.isNotEmpty && r.displayName.isNotEmpty
                          ? Text(r.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.karla(
                                  fontSize: 11, color: AppColors.textMuted))
                          : null,
                      onTap: () => _pickSearchResult(r),
                    );
                  },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panelMessage(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Text(msg,
          style: GoogleFonts.karla(
              fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
    );
  }

  Widget _buildBottomCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
            ),

            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text('Delivery pin',
                    style: AppTextStyles.label(context)),
              ],
            ),
            const SizedBox(height: 2),
            Text('Santa Cruz, Laguna only',
                style: GoogleFonts.karla(
                    fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),

            // Address preview
            _buildAddressPreview(),

            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: GoldOutlineButton(
                    label: 'USE MY LOCATION',
                    onPressed: _isResolving ? null : _goToMyLocation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'CONFIRM PIN',
              onPressed: (_resolved != null && !_resolved!.isEmpty && !_isResolving)
                  ? () => Navigator.pop(context, _resolved)
                  : null,
              isLoading: _isResolving && _resolved == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressPreview() {
    if (_isResolving && _resolved == null) {
      return Row(
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Finding the address…',
              style: AppTextStyles.bodyMedium(context)),
        ],
      );
    }

    if (_resolveError != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(_resolveError!,
                style: GoogleFonts.karla(
                    fontSize: 12, color: AppColors.error, height: 1.4)),
          ),
          TextButton(
            onPressed: _resolveCenter,
            child: Text('Retry',
                style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (_resolved?.address.isNotEmpty ?? false)
              ? _resolved!.address
              : 'Drag the map to place the pin on your delivery spot.',
          style: GoogleFonts.karla(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4),
        ),
        if (_resolved?.hasCoordinates == true) ...[
          const SizedBox(height: 4),
          Text(
            '${_resolved!.latitude!.toStringAsFixed(6)}, ${_resolved!.longitude!.toStringAsFixed(6)}',
            style: AppTextStyles.caption(context),
          ),
        ],
      ],
    );
  }
}
