import 'dart:convert';
import 'dart:io';

/// REPLAYGAIN_TRACK_GAIN etiketini okur (FLAC Vorbis Comment + ID3v2 TXXX).
///
/// Gain uygulaması playback hattında (audio_handler) yapılır; bu servis
/// sadece tag okur. Desteklenmeyen kapsayıcılarda null döner (uygulanmaz).
class ReplayGainService {
  ReplayGainService._();

  static final Map<String, double?> _store = {};
  static const int _headSize = 131072;

  /// Dosyadan REPLAYGAIN_TRACK_GAIN (dB) okur; tag yoksa null.
  static Future<double?> readTrackGain(String path) async {
    if (_store.containsKey(path)) return _store[path];
    double? gain;
    try {
      final file = File(path);
      if (await file.exists()) {
        final raf = await file.open();
        try {
          final size = await raf.length();
          final len = size < _headSize ? size : _headSize;
          gain = _parseGain(await raf.read(len));
        } finally {
          await raf.close();
        }
      }
    } catch (_) {}
    if (_store.length > 500) _store.clear();
    _store[path] = gain;
    return gain;
  }

  static double? _parseGain(List<int> b) {
    if (b.length > 4 &&
        b[0] == 0x66 &&
        b[1] == 0x4C &&
        b[2] == 0x61 &&
        b[3] == 0x43) {
      return _flacGain(b);
    }
    if (b.length > 10 &&
        b[0] == 0x49 &&
        b[1] == 0x44 &&
        b[2] == 0x33) {
      return _id3Gain(b);
    }
    return null;
  }

  static double? _flacGain(List<int> b) {
    var off = 4;
    while (off + 4 <= b.length) {
      final isLast = (b[off] & 0x80) != 0;
      final type = b[off] & 0x7F;
      final len = (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];
      off += 4;
      if (off + len > b.length) break;
      if (type == 4) return _vorbisCommentGain(b, off, len);
      if (isLast) break;
      off += len;
    }
    return null;
  }

  static double? _vorbisCommentGain(List<int> b, int start, int len) {
    final end = start + len;
    var p = start;
    int u32() {
      final v = (b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24))
          .toUnsigned(32);
      p += 4;
      return v;
    }

    if (p + 4 > end) return null;
    final vendorLen = u32();
    p += vendorLen;
    if (p < 0 || p + 4 > end) return null;
    final count = u32();
    for (var i = 0; i < count && p + 4 <= end; i++) {
      final l = u32();
      if (l <= 0 || l > end - p) break;
      final s = utf8.decode(b.sublist(p, p + l), allowMalformed: true);
      p += l;
      final eq = s.indexOf('=');
      if (eq > 0 &&
          s.substring(0, eq).toUpperCase() == 'REPLAYGAIN_TRACK_GAIN') {
        return _parseDb(s.substring(eq + 1));
      }
    }
    return null;
  }

  static double? _id3Gain(List<int> b) {
    final ver = b[3];
    if (ver != 3 && ver != 4) return null;
    final tagSize = ((b[6] & 0x7F) << 21) |
        ((b[7] & 0x7F) << 14) |
        ((b[8] & 0x7F) << 7) |
        (b[9] & 0x7F);
    var p = 10;
    final tagEnd = 10 + tagSize;
    if ((b[5] & 0x40) != 0) {
      if (p + 4 > tagEnd) return null;
      final extSize = ver == 4
          ? ((b[p] & 0x7F) << 21) |
              ((b[p + 1] & 0x7F) << 14) |
              ((b[p + 2] & 0x7F) << 7) |
              (b[p + 3] & 0x7F)
          : ((b[p] << 24) |
                  (b[p + 1] << 16) |
                  (b[p + 2] << 8) |
                  b[p + 3])
              .toUnsigned(32);
      p += ver == 4 ? extSize : extSize + 4;
    }
    while (p + 10 <= tagEnd && p + 10 <= b.length) {
      final id = String.fromCharCodes(b.sublist(p, p + 4));
      final size = ver == 4
          ? ((b[p + 4] & 0x7F) << 21) |
              ((b[p + 5] & 0x7F) << 14) |
              ((b[p + 6] & 0x7F) << 7) |
              (b[p + 7] & 0x7F)
          : ((b[p + 4] << 24) |
                  (b[p + 5] << 16) |
                  (b[p + 6] << 8) |
                  b[p + 7])
              .toUnsigned(32);
      if (size <= 0 || p + 10 + size > b.length) break;
      if (id == 'TXXX') {
        final frame = b.sublist(p + 10, p + 10 + size);
        final gain = _txxxGain(frame);
        if (gain != null) return gain;
      }
      p += 10 + size;
    }
    return null;
  }

  static double? _txxxGain(List<int> f) {
    if (f.length < 3) return null;
    final enc = f[0];
    if (enc == 0 || enc == 3) {
      var end = f.indexOf(0, 1);
      if (end < 0) return null;
      final desc = String.fromCharCodes(f.sublist(1, end));
      if (desc.toUpperCase() != 'REPLAYGAIN_TRACK_GAIN') return null;
      end += 1;
      return _parseDb(String.fromCharCodes(f.sublist(end)));
    }
    return null;
  }

  static double? _parseDb(String raw) {
    final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }
}
