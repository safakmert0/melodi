import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flac_embedder.dart';

class ArtworkEmbeddingService {
  ArtworkEmbeddingService._();

  static const MethodChannel _channel =
      MethodChannel('com.melodi/metadata_writer');

  static Future<bool> embedCoverArt({
    required String filePath,
    required Uint8List artwork,
  }) async {
    if (artwork.isEmpty) return false;
    final extension = filePath.split('.').last.toLowerCase();

    try {
      if (extension == 'flac') {
        await FlacEmbedder.embedCoverArt(filePath, artwork);
        return true;
      }
      if (extension == 'mp3') {
        return await Id3CoverArtEmbedder.embedCoverArt(filePath, artwork);
      }
      if (!kIsWeb && Platform.isIOS && extension == 'm4a') {
        return await _channel.invokeMethod<bool>('embedArtwork', {
              'path': filePath,
              'coverArt': artwork,
            }) ??
            false;
      }
    } catch (error) {
      debugPrint('Artwork metadata writer failed: $error');
    }
    return false;
  }
}

class Id3CoverArtEmbedder {
  Id3CoverArtEmbedder._();

  static Future<bool> embedCoverArt(String filePath, Uint8List artwork) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    final source = await file.readAsBytes();
    final tagged = addCoverArt(source, artwork);
    if (tagged == null) return false;
    if (identical(tagged, source)) return true;

    final temporary = File(
        '$filePath.melodi-art-${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await temporary.writeAsBytes(tagged, flush: true);
      await temporary.copy(filePath);
      return true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @visibleForTesting
  static Uint8List? addCoverArt(Uint8List source, Uint8List artwork) {
    if (artwork.isEmpty) return null;

    var version = 3;
    var flags = 0;
    var audioStart = 0;
    var existingPayload = Uint8List(0);

    final hasId3 = source.length >= 10 &&
        source[0] == 0x49 &&
        source[1] == 0x44 &&
        source[2] == 0x33;
    if (hasId3) {
      version = source[3];
      if (version != 3 && version != 4) return null;
      flags = source[5];
      // Rewriting unsynchronised or extended tags without a complete ID3
      // codec risks corrupting the audio. Keep those files untouched.
      if ((flags & 0x80) != 0 || (flags & 0x40) != 0) return null;

      final tagSize = _decodeSynchsafe(source, 6);
      final hasFooter = version == 4 && (flags & 0x10) != 0;
      audioStart = 10 + tagSize + (hasFooter ? 10 : 0);
      if (tagSize < 0 || audioStart > source.length) return null;
      existingPayload = Uint8List.fromList(source.sublist(10, 10 + tagSize));

      final parsed = _usedFrameBytes(existingPayload, version);
      if (parsed == null) return null;
      if (parsed.hasArtwork) return source;
      existingPayload =
          Uint8List.fromList(existingPayload.sublist(0, parsed.usedBytes));
      flags &= ~0x10;
    }

    final artworkFrame = _buildArtworkFrame(artwork, version);
    final payload = BytesBuilder(copy: false)
      ..add(existingPayload)
      ..add(artworkFrame);
    final payloadBytes = payload.takeBytes();
    final header = Uint8List(10)
      ..setRange(0, 3, ascii.encode('ID3'))
      ..[3] = version
      ..[4] = 0
      ..[5] = flags;
    _writeSynchsafe(header, 6, payloadBytes.length);

    final output = BytesBuilder(copy: false)
      ..add(header)
      ..add(payloadBytes)
      ..add(source.sublist(audioStart));
    return output.takeBytes();
  }

  static ({int usedBytes, bool hasArtwork})? _usedFrameBytes(
      Uint8List payload, int version) {
    var offset = 0;
    while (offset + 10 <= payload.length) {
      if (payload.sublist(offset, offset + 4).every((byte) => byte == 0)) {
        return (usedBytes: offset, hasArtwork: false);
      }
      final id =
          ascii.decode(payload.sublist(offset, offset + 4), allowInvalid: true);
      if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) return null;
      final frameSize = version == 4
          ? _decodeSynchsafe(payload, offset + 4)
          : _decodeBigEndian(payload, offset + 4);
      if (frameSize < 0 || offset + 10 + frameSize > payload.length) {
        return null;
      }
      if (id == 'APIC') {
        return (usedBytes: offset, hasArtwork: true);
      }
      offset += 10 + frameSize;
    }
    if (offset == payload.length ||
        payload.sublist(offset).every((byte) => byte == 0)) {
      return (usedBytes: offset, hasArtwork: false);
    }
    return null;
  }

  static Uint8List _buildArtworkFrame(Uint8List artwork, int version) {
    final mime = _isPng(artwork) ? 'image/png' : 'image/jpeg';
    final body = BytesBuilder(copy: false)
      ..addByte(0)
      ..add(latin1.encode(mime))
      ..addByte(0)
      ..addByte(3)
      ..addByte(0)
      ..add(artwork);
    final bodyBytes = body.takeBytes();
    final frame = Uint8List(10)..setRange(0, 4, ascii.encode('APIC'));
    if (version == 4) {
      _writeSynchsafe(frame, 4, bodyBytes.length);
    } else {
      _writeBigEndian(frame, 4, bodyBytes.length);
    }
    return (BytesBuilder(copy: false)
          ..add(frame)
          ..add(bodyBytes))
        .takeBytes();
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47;

  static int _decodeSynchsafe(List<int> bytes, int offset) {
    if (offset + 4 > bytes.length) return -1;
    final values = bytes.sublist(offset, offset + 4);
    if (values.any((value) => value > 0x7f)) return -1;
    return (values[0] << 21) | (values[1] << 14) | (values[2] << 7) | values[3];
  }

  static int _decodeBigEndian(List<int> bytes, int offset) {
    if (offset + 4 > bytes.length) return -1;
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static void _writeSynchsafe(Uint8List target, int offset, int value) {
    target[offset] = (value >> 21) & 0x7f;
    target[offset + 1] = (value >> 14) & 0x7f;
    target[offset + 2] = (value >> 7) & 0x7f;
    target[offset + 3] = value & 0x7f;
  }

  static void _writeBigEndian(Uint8List target, int offset, int value) {
    target[offset] = (value >> 24) & 0xff;
    target[offset + 1] = (value >> 16) & 0xff;
    target[offset + 2] = (value >> 8) & 0xff;
    target[offset + 3] = value & 0xff;
  }
}
