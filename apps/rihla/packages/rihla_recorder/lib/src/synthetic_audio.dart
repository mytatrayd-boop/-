import 'dart:typed_data';

/// صوت اصطناعي: صمت مع "نقرة" (1kHz، 10ms) عند كل ثانية كاملة. أحادي s16le.
class SyntheticAudioSource {
  const SyntheticAudioSource({this.sampleRate = 48000, this.muted = false});

  final int sampleRate;

  /// الكتم: عينات صمت بنفس المدة تماماً.
  final bool muted;

  Int16List samples(Duration duration) {
    final n = duration.inMicroseconds * sampleRate ~/ 1000000;
    final out = Int16List(n);
    if (muted) return out;
    final clickLen = sampleRate ~/ 100;
    for (var start = 0; start < n; start += sampleRate) {
      for (var k = 0; k < clickLen && start + k < n; k++) {
        // موجة مربعة تقريبية 1kHz بسعة كبيرة.
        out[start + k] = ((k * 1000 ~/ sampleRate) % 2 == 0) ? 24000 : -24000;
      }
    }
    return out;
  }

  /// ترميز WAV (PCM 16 بت أحادي) لتمريره للمشفِّر.
  Uint8List toWav(Int16List s) {
    final dataLen = s.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVEfmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < s.length; i++) {
      b.setInt16(44 + i * 2, s[i], Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
