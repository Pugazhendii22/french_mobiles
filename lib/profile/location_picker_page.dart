import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../shared/services/reverse_geocoder.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

/// What the picker hands back.
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;

  /// The reverse-geocoded street address, or a coordinate pair when none
  /// could be read.
  final String address;
}

/// Pick a point on a map.
///
/// The pin is fixed to the centre of the screen and the map moves underneath
/// it, which is how every delivery and ride app does this. A draggable marker
/// is worse on a phone: the finger covers the thing being placed, and the pin
/// can be dragged off-screen.
///
/// Tiles come from OpenStreetMap — no API key, no billing account — matching
/// the Nominatim geocoding the address sheet already used.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  /// Where to open. Falls back to the device's location, then to a wide view
  /// of India, so the map is never staring at the middle of the ocean.
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  /// Centre of India at a zoom that shows the country, for the case where
  /// there is no saved address and location is unavailable.
  static const LatLng _fallbackCentre = LatLng(20.5937, 78.9629);
  static const double _countryZoom = 4;
  static const double _streetZoom = 16;

  /// How long the map must sit still before the address is looked up. Long
  /// enough that panning across a city is one request, not fifty.
  static const Duration _settleDelay = Duration(milliseconds: 700);

  final MapController _map = MapController();
  final ReverseGeocoder _geocoder = ReverseGeocoder();

  Timer? _settleTimer;
  LatLng _centre = _fallbackCentre;
  String? _address;
  bool _lookingUp = false;
  bool _locating = false;

  /// Guards against a slow lookup landing after the map has moved on and
  /// overwriting a newer address with an older one.
  int _lookupGeneration = 0;

  @override
  void initState() {
    super.initState();

    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null) {
      _centre = LatLng(lat, lng);
      _lookUp(_centre);
    } else {
      // Nothing saved: open on wherever the phone is, if it will say.
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _geocoder.dispose();
    _map.dispose();
    super.dispose();
  }

  bool get _hasInitialPoint =>
      widget.initialLatitude != null && widget.initialLongitude != null;

  /// Called continuously while the map moves; the lookup waits for it to stop.
  void _onMoved(MapCamera camera, bool hasGesture) {
    _centre = camera.center;
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, () => _lookUp(_centre));
    if (_address != null) setState(() => _address = null);
  }

  Future<void> _lookUp(LatLng point) async {
    final generation = ++_lookupGeneration;
    setState(() => _lookingUp = true);

    final found = await _geocoder.lookup(point.latitude, point.longitude);

    // A newer lookup started while this one was in flight.
    if (!mounted || generation != _lookupGeneration) return;
    setState(() {
      _address = found ??
          ReverseGeocoder.describeCoordinates(point.latitude, point.longitude);
      _lookingUp = false;
    });
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _complain('Location permission is needed to centre the map on you');
        return;
      }

      // No isLocationServiceEnabled() pre-check: asking for a position while
      // services are off is what makes Android offer to switch them on.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      _centre = point;
      _map.move(point, _streetZoom);
      _settleTimer?.cancel();
      await _lookUp(point);
    } catch (e) {
      if (!mounted) return;
      _complain('Could not find your location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirm() {
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _centre.latitude,
        longitude: _centre.longitude,
        address: _address ??
            ReverseGeocoder.describeCoordinates(
                _centre.latitude, _centre.longitude),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.lg),
            child: AppScreenHeader(title: 'Set location'),
          ),
          Expanded(child: _mapArea()),
          _confirmBar(),
        ],
      ),
    );
  }

  Widget _mapArea() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _centre,
            initialZoom: _hasInitialPoint ? _streetZoom : _countryZoom,
            onPositionChanged: _onMoved,
            interactionOptions: const InteractionOptions(
              // Rotation is only ever an accident here, and a rotated map
              // makes a fixed centre pin confusing.
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.french_mobiles',
            ),
            // OpenStreetMap's licence requires visible credit.
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        const IgnorePointer(child: Center(child: _CentrePin())),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: _myLocationButton(),
        ),
      ],
    );
  }

  Widget _myLocationButton() {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _locating ? null : _goToMyLocation,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _locating
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.my_location_rounded,
                  size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _confirmBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PICKUP AT',
              style: AppTextStyles.overline
                  .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            // Two lines' worth, always: without it the button jumps up and
            // down as addresses of different lengths arrive.
            height: 40,
            child: _lookingUp
                ? Row(
                    children: [
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Finding address…', style: AppTextStyles.bodySmall),
                    ],
                  )
                : Text(
                    _address ?? 'Move the map to place the pin',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Confirm location',
            // Confirmable even while the address is still resolving: the
            // coordinates are already correct, and that is what pickup needs.
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}

/// The pin sitting at the centre of the map.
///
/// Lifted slightly so its point, not its middle, marks the spot.
class _CentrePin extends StatelessWidget {
  const _CentrePin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on_rounded,
            size: 44, color: AppColors.primaryDark),
        // The pin's tip is at the bottom of the glyph; this shadow marks the
        // exact point it refers to.
        Container(
          height: 5,
          width: 5,
          decoration: const BoxDecoration(
            color: AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 44),
      ],
    );
  }
}
