import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/google_maps_config.dart';

/// Turns coordinates into a street address using Google's Geocoding API.
///
/// Previously OpenStreetMap's Nominatim, which needed no key but capped the
/// app at one request per second and returned noticeably coarser results for
/// Indian addresses — a pickup address that reads "Pudupalaiyam, Puducherry"
/// instead of a house number and street is the difference between an agent
/// finding the door and phoning the seller.
///
/// Every call costs money, so [minimumInterval] still throttles — no longer to
/// obey a usage policy, but to stop a caller that forgets to debounce from
/// quietly running up a bill while someone drags the map around.
class ReverseGeocoder {
  ReverseGeocoder({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? googleGeocodingApiKey;

  final http.Client _client;
  final String _apiKey;

  /// A floor between calls. Google permits far more than this; the limit here
  /// is about cost, not permission.
  static const Duration minimumInterval = Duration(milliseconds: 300);

  DateTime? _lastCall;

  /// The address at [latitude]/[longitude], or null if it could not be read.
  ///
  /// Null rather than a thrown error: a missing street name is not a failure
  /// worth interrupting the user for — the coordinates are still valid, and
  /// callers fall back to showing those.
  Future<String?> lookup(double latitude, double longitude) async {
    await _respectRateLimit();

    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '$latitude,$longitude',
      'language': 'en',
      'key': _apiKey,
    });

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final status = decoded['status'];

      // ZERO_RESULTS is an ordinary answer — a pin in the sea has no address.
      // Anything else non-OK means the key, the quota or the request is wrong,
      // and that must not vanish silently: addresses would just stop resolving
      // app-wide with nothing to point at. It still degrades to coordinates.
      if (status != 'OK') {
        if (status != 'ZERO_RESULTS') {
          debugPrint(
            'Geocoding failed: $status ${decoded['error_message'] ?? ''}'.trim(),
          );
        }
        return null;
      }

      final results = decoded['results'];
      if (results is! List || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map) return null;

      final address = first['formatted_address'];
      if (address is String && address.trim().isNotEmpty) return address.trim();
      return null;
    } catch (_) {
      // Offline, timed out, or a response shape we do not recognise.
      return null;
    }
  }

  /// A coordinate pair, for when there is no address to show.
  static String describeCoordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  Future<void> _respectRateLimit() async {
    final last = _lastCall;
    _lastCall = DateTime.now();
    if (last == null) return;

    final elapsed = DateTime.now().difference(last);
    if (elapsed < minimumInterval) {
      await Future<void>.delayed(minimumInterval - elapsed);
      _lastCall = DateTime.now();
    }
  }

  void dispose() => _client.close();
}
