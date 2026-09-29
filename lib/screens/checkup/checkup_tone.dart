import 'dart:math';
import 'dart:typed_data';

/// Synthesised test audio for the speaker and earpiece tests.
///
/// Generated rather than shipped as an asset, so there is no binary blob in
/// the repo and the frequency, length and pattern stay adjustable. Both tests
/// hand the result to audioplayers as a `BytesSource`; nothing is written to
/// disk.
class CheckupTone {
  CheckupTone._();

  /// 1 kHz: near the ear's most sensitive range, and high enough that a blown
  /// or muffled driver is obvious.
  static const double defaultFrequency = 1000;
  static const int sampleRate = 44100;

  /// A single steady tone.
  static Uint8List steady({
    double frequency = defaultFrequency,
    double seconds = 2,
  }) {
    final frames = (sampleRate * seconds).round();
    return _wav(frames, (i) => _fade(i, frames) * sin(_phase(frequency, i)));
  }

  /// [count] separate beeps with silence between them.
  ///
  /// The gap is what makes them countable: the listener has to hear each one
  /// start and stop, which a receiver that crackles or cuts out cannot fake.
  static Uint8List beeps({
    int count = 3,
    double frequency = defaultFrequency,
    double beepSeconds = 0.35,
    double gapSeconds = 0.3,
  }) {
    final beepFrames = (sampleRate * beepSeconds).round();
    final gapFrames = (sampleRate * gapSeconds).round();
    final total = count * beepFrames + (count - 1) * gapFrames;

    return _wav(total, (i) {
      final cycle = beepFrames + gapFrames;
      final offset = i % cycle;
      // Inside the silent tail of a cycle.
      if (offset >= beepFrames) return 0;
      return _fade(offset, beepFrames) * sin(_phase(frequency, offset));
    });
  }

  static double _phase(double frequency, int frame) =>
      2 * pi * frequency * frame / sampleRate;

  /// Ramps the first and last 20ms of a beep so it does not start or end on a
  /// click — a click is itself easy to mistake for a speaker fault.
  static double _fade(int frame, int length) {
    const ramp = sampleRate * 0.02;
    return min(1.0, min(frame, length - frame) / ramp).clamp(0.0, 1.0);
  }

  /// Wraps 16-bit mono PCM samples in a WAV header.
  ///
  /// [sample] returns amplitude in -1..1 for a frame index.
  static Uint8List _wav(int frames, double Function(int frame) sample) {
    final data = ByteData(44 + frames * 2);

    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + frames * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little); // PCM chunk size
    data.setUint16(20, 1, Endian.little); // format: PCM
    data.setUint16(22, 1, Endian.little); // channels: mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    data.setUint32(40, frames * 2, Endian.little);

    for (var i = 0; i < frames; i++) {
      data.setInt16(
          44 + i * 2, (sample(i) * 0.6 * 32767).round(), Endian.little);
    }

    return data.buffer.asUint8List();
  }
}
