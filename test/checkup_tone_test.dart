// The synthesised audio the speaker and earpiece tests play.
//
// Nobody can hear a test run, and a malformed WAV either plays as a burst of
// noise or refuses to play at all — both of which read on a real device as
// "the speaker is broken". So the bytes are checked here instead: the header
// a player parses, and the shape of the audio a user is asked to count.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/checkup_tone.dart';

/// Reads the 16-bit samples back out of a WAV, skipping the 44-byte header.
List<int> _samples(Uint8List wav) {
  final data = ByteData.sublistView(wav, 44);
  return [
    for (var i = 0; i < data.lengthInBytes ~/ 2; i++)
      data.getInt16(i * 2, Endian.little),
  ];
}

String _ascii(Uint8List wav, int offset, int length) =>
    String.fromCharCodes(wav.sublist(offset, offset + length));

void main() {
  group('WAV header', () {
    final wav = CheckupTone.steady(seconds: 0.1);

    test('carries the RIFF/WAVE chunks a player looks for', () {
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(_ascii(wav, 36, 4), 'data');
    });

    test('declares 16-bit mono PCM at the sample rate it generated', () {
      final data = ByteData.sublistView(wav);
      expect(data.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), CheckupTone.sampleRate);
      expect(data.getUint16(34, Endian.little), 16, reason: 'bits per sample');
    });

    test('the declared sizes match the bytes actually present', () {
      final data = ByteData.sublistView(wav);
      expect(data.getUint32(4, Endian.little), wav.length - 8,
          reason: 'RIFF size is everything after the first 8 bytes');
      expect(data.getUint32(40, Endian.little), wav.length - 44,
          reason: 'a data size that overruns the buffer is what makes a '
              'player emit noise');
    });

    test('length follows the requested duration', () {
      final tenth = CheckupTone.steady(seconds: 0.1);
      final fifth = CheckupTone.steady(seconds: 0.2);
      expect(fifth.length - 44, (tenth.length - 44) * 2);
    });
  });

  group('beeps', () {
    /// Counts the bursts a listener would count.
    ///
    /// Measured over 10ms windows rather than per sample: a sine wave passes
    /// through zero twice per cycle, so individual samples go quiet a
    /// thousand times a second without the beep stopping.
    int audibleRuns(Uint8List wav) {
      const window = CheckupTone.sampleRate ~/ 100;
      final samples = _samples(wav);

      var runs = 0;
      var inRun = false;
      for (var start = 0; start < samples.length; start += window) {
        final end = (start + window).clamp(0, samples.length);
        var peak = 0;
        for (var i = start; i < end; i++) {
          final level = samples[i].abs();
          if (level > peak) peak = level;
        }
        final audible = peak > 1000;
        if (audible && !inRun) runs++;
        inRun = audible;
      }
      return runs;
    }

    for (final count in [2, 3, 4, 5]) {
      test('$count beeps are $count separate bursts', () {
        expect(audibleRuns(CheckupTone.beeps(count: count)), count,
            reason: 'the user is asked to count these; if they run together '
                'the test is unanswerable');
      });
    }

    test('starts and ends silent so neither edge clicks', () {
      final samples = _samples(CheckupTone.beeps(count: 3));
      expect(samples.first.abs(), lessThan(100));
      expect(samples.last.abs(), lessThan(100));
    });

    test('is loud enough in the middle of a beep to be heard', () {
      final samples = _samples(CheckupTone.beeps(count: 2));
      final peak = samples.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(10000),
          reason: 'a receiver is quiet; a faint tone is indistinguishable '
              'from a dead one');
    });

    test('a steady tone is one continuous run, not beeps', () {
      expect(audibleRuns(CheckupTone.steady(seconds: 0.5)), 1);
    });
  });
}
