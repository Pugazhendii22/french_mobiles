import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Turns coordinates into a street address using OpenStreetMap's Nominatim.
///
/// Nominatim rather than a platform geocoder because it needs no API key and
/// no billing account, and the address sheet was already calling it — this
/// just puts the call in one place so the map picker and the "use my current
/// location" button cannot drift apart.
///
/// Its usage policy asks for at most one request per second and a User-Agent
/// that identifies the app, both of which are honoured here: callers are
/// expected to debounce, and [minimumInterval] enforces a floor regardless.
class ReverseGeocoder {
  ReverseGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Nominatim's published rate limit is one call per second.
  static const Duration minimumInterval = Duration(milliseconds: 1100);

  static const String _userAgent = 'french-mobiles-app/1.0';

  DateTime? _lastCall;

  /// The address at [latitude]/[longitude], or null if it could not be read.
  ///
  /// Null rather than a thrown error: a missing street name is not a failure
  /// worth interrupting the user for — the coordinates are still valid, and
  /// callers fall back to showing those.
  Future<String?> lookup(double latitude, double longitude) async {
    await _respectRateLimit();

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2&lat=$latitude&lon=$longitude',
    );

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final name = decoded['display_name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
      return null;
    } catch (_) {
      // Offline, rate limited, or a response shape we do not recognise.
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
