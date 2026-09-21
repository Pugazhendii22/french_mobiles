// Turning a map pin into an address, via Google's Geocoding API.
//
// Every failure here is a network or configuration failure, and none of them
// should reach the user as an error: a pin without a street name is still a
// valid pickup point. So what is tested is that it degrades to coordinates
// rather than throwing, that it sends the key and the coordinates it was
// given, and that it keeps a floor between calls — each one is billable.
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
    apiKey: 'test-key',
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

/// The shape Google returns for a successful reverse lookup.
Map<String, Object?> _result(String address) => {
      'status': 'OK',
      'results': [
        {'formatted_address': address}
      ],
    };

void main() {
  test('returns the formatted address Google sends back', () async {
    final geocoder = _geocoderReturning(
      (_) => _ok(_result('12 MG Road, Bengaluru, Karnataka 560001, India')),
    );

    expect(await geocoder.lookup(12.97, 77.59),
        '12 MG Road, Bengaluru, Karnataka 560001, India');
  });

  test('takes the first result when several are returned', () async {
    final geocoder = _geocoderReturning((_) => _ok({
          'status': 'OK',
          'results': [
            {'formatted_address': 'the street'},
            {'formatted_address': 'the district'},
            {'formatted_address': 'the country'},
          ],
        }));

    expect(await geocoder.lookup(1, 2), 'the street');
  });

  test('asks for the coordinates it was given, with the key', () async {
    final requests = <http.Request>[];
    final geocoder = _geocoderReturning(
      (_) => _ok(_result('somewhere')),
      record: requests,
    );

    await geocoder.lookup(12.9716, 77.5946);

    final params = requests.single.url.queryParameters;
    expect(params['latlng'], '12.9716,77.5946');
    expect(params['key'], 'test-key');
    expect(params['language'], 'en');
  });

  group('degrades instead of throwing', () {
    test('on a non-200', () async {
      final geocoder = _geocoderReturning((_) => http.Response('nope', 503));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on a body that is not JSON', () async {
      final geocoder = _geocoderReturning((_) => http.Response('<html>', 200));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on ZERO_RESULTS, which is an ordinary answer', () async {
      final geocoder = _geocoderReturning(
          (_) => _ok({'status': 'ZERO_RESULTS', 'results': []}));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    // The key being wrong, restricted or out of quota is the most likely way
    // this breaks in production, and it must not throw at the user.
    test('on REQUEST_DENIED', () async {
      final geocoder = _geocoderReturning((_) => _ok({
            'status': 'REQUEST_DENIED',
            'error_message': 'This API key is not authorized...',
          }));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on OVER_QUERY_LIMIT', () async {
      final geocoder =
          _geocoderReturning((_) => _ok({'status': 'OVER_QUERY_LIMIT'}));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on OK with an empty results list', () async {
      final geocoder =
          _geocoderReturning((_) => _ok({'status': 'OK', 'results': []}));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on a blank formatted_address', () async {
      final geocoder = _geocoderReturning((_) => _ok(_result('   ')));
      expect(await geocoder.lookup(1, 2), isNull);
    });

    test('on the request throwing outright', () async {
      final geocoder = ReverseGeocoder(
        apiKey: 'test-key',
        client: MockClient((_) async => throw const SocketExceptionLike()),
      );
      expect(await geocoder.lookup(1, 2), isNull);
    });
  });

  test('coordinates are the readable fallback', () {
    expect(ReverseGeocoder.describeCoordinates(12.9716, 77.5946),
        '12.97160, 77.59460');
  });

  test('a second lookup waits out the minimum interval', () async {
    final geocoder = _geocoderReturning((_) => _ok(_result('x')));

    final started = DateTime.now();
    await geocoder.lookup(1, 2);
    await geocoder.lookup(3, 4);
    final elapsed = DateTime.now().difference(started);

    expect(elapsed, greaterThanOrEqualTo(ReverseGeocoder.minimumInterval),
        reason: 'every lookup is billable, so a caller that forgets to '
            'debounce must not be able to spray requests');
  });
}

/// Stands in for a network error without importing dart:io.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
