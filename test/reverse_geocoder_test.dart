// Turning a map pin into an address.
//
// Every failure here is a network failure, and none of them should reach the
// user as an error: a pin without a street name is still a valid pickup
// point. So what is tested is that it degrades to coordinates rather than
// throwing, and that it honours Nominatim's rate limit — exceeding that gets
// an app blocked from the service entirely.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/services/reverse_geocoder.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ReverseGeocoder _geocoderReturning(
  http.Response Function(http.Request request) respond, {
  List<http.Request>? record,
}) {
  return ReverseGeocoder(
    client: MockClient((request) async {
      record?.add(request);
      return respond(request);
    }),
  );
}

http.Response _ok(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {
      'content-type': 'application/json',
    });

void main() {
  test('returns the display name Nominatim sends back', () async {
    final geocoder = _geocoderReturning(
      (_) => _ok({'display_name': '12 MG Road, Bengaluru, 560001'}),
    );

    expect(await geocoder.lookup(12.97, 77.59),
        '12 MG Road, Bengaluru, 560001');
  });

  test('asks for the coordinates it was given', () async {
    final requests = <http.Request>[];
    final geocoder = _geocoderReturning(
      (_) => _ok({'display_name': 'somewhere'}),
      record: requests,
    );

    await geocoder.lookup(12.9716, 77.5946);

    expect(requests.single.url.queryParameters['lat'], '12.9716');
    expect(requests.single.url.queryParameters['lon'], '77.5946');
    expect(requests.single.url.queryParameters['format'], 'jsonv2');
  });

  test('identifies the app, which Nominatim requires', () async {
    final requests = <http.Request>[];
    final geocoder = _geocoderReturning(
      (_) => _ok({'display_name': 'somewhere'}),
      record: requests,
    );

    await geocoder.lookup(1, 2);

    final agent = requests.single.headers['User-Agent'];
    expect(agent, isNotNull);
    expect(agent, contains('french-mobiles'),
        reason: 'requests without a real User-Agent get blocked');
  });

  group('degrades instead of throwing', () {
    test('on a non-200', () async {
      final geocoder =
          _geocoderReturning((_) => http.Response('nope', 503));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on a body that is not JSON', () async {
      final geocoder =
          _geocoderReturning((_) => http.Response('<html>', 200));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on JSON with no display_name', () async {
      final geocoder = _geocoderReturning((_) => _ok({'error': 'nothing'}));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on a blank display_name', () async {
      final geocoder = _geocoderReturning((_) => _ok({'display_name': '   '}));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on the request throwing outright', () async {
      final geocoder = ReverseGeocoder(
        client: MockClient((_) async => throw const SocketExceptionLike()),
      );
      expect(await geocoder.lookup(1, 2), isNull);
    });
  });

  test('coordinates are the readable fallback', () {
    expect(ReverseGeocoder.describeCoordinates(12.9716, 77.5946),
        '12.97160, 77.59460');
  });

  test('a second lookup waits out the rate limit', () async {
    final geocoder = _geocoderReturning((_) => _ok({'display_name': 'x'}));

    final started = DateTime.now();
    await geocoder.lookup(1, 2);
    await geocoder.lookup(3, 4);
    final elapsed = DateTime.now().difference(started);

    expect(elapsed, greaterThanOrEqualTo(ReverseGeocoder.minimumInterval),
        reason: 'Nominatim allows one request a second and blocks apps that '
            'ignore that');
  });
}

/// Stands in for a network error without importing dart:io.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
