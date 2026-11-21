import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/replay_gain_service.dart';

List<int> _u32le(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

List<int> _buildFlac(List<String> comments) {
  final vendor = 'test'.codeUnits;
  final commentBytes = <int>[];
  for (final c in comments) {
    final bytes = c.codeUnits;
    commentBytes.addAll(_u32le(bytes.length));
    commentBytes.addAll(bytes);
  }
  final payload = <int>[];
  payload.addAll(_u32le(vendor.length));
  payload.addAll(vendor);
  payload.addAll(_u32le(comments.length));
  payload.addAll(commentBytes);
  return [
    0x66, 0x4C, 0x61, 0x43,
    0x00, 0x00, 0x00, 0x22,
    ...List.filled(34, 0),
    0x84,
    (payload.length >> 16) & 0xFF, (payload.length >> 8) & 0xFF,
    payload.length & 0xFF,
    ...payload,
  ];
}

List<int> _buildId3(String description, String value) {
  final desc = description.codeUnits;
  final val = value.codeUnits;
  final content = [0, ...desc, 0, ...val];
  final frame = [
    0x54, 0x58, 0x58, 0x58,
    (content.length >> 24) & 0xFF, (content.length >> 16) & 0xFF,
    (content.length >> 8) & 0xFF, content.length & 0xFF,
    0, 0,
    ...content,
  ];
  final size = frame.length;
  return [
    0x49, 0x44, 0x33, 3, 0, 0,
    (size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F,
    ...frame,
  ];
}

Future<String> _tmp(List<int> bytes) async {
  final f = File(
      '${Directory.systemTemp.path}/rg_test_${DateTime.now().microsecondsSinceEpoch}.bin');
  await f.writeAsBytes(bytes);
  return f.path;
}

void main() {
  test('FLAC Vorbis Comment REPLAYGAIN_TRACK_GAIN okur', () async {
    final path = await _tmp(_buildFlac([
      'ARTIST=Test',
      'REPLAYGAIN_TRACK_GAIN=-6.50 dB',
    ]));
    expect(await ReplayGainService.readTrackGain(path), closeTo(-6.5, 0.01));
    await File(path).delete();
  });

  test('ID3v2.3 TXXX replaygain okur', () async {
    final path = await _tmp(
        _buildId3('replaygain_track_gain', '+2.25 dB'));
    expect(await ReplayGainService.readTrackGain(path), closeTo(2.25, 0.01));
    await File(path).delete();
  });

  test('tag yoksa null döner', () async {
    final path = await _tmp(List.filled(64, 0));
    expect(await ReplayGainService.readTrackGain(path), isNull);
    await File(path).delete();
  });
}
