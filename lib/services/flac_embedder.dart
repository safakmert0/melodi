import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class FlacMetadataBlock {
  final int type;
  final bool isLast;
  final Uint8List data;

  const FlacMetadataBlock({
    required this.type,
    required this.isLast,
    required this.data,
  });

  int get length => data.length;

  Uint8List encode() {
    final header = Uint8List(4);
    header[0] = (isLast ? 0x80 : 0x00) | (type & 0x7F);
    header[1] = (length >> 16) & 0xFF;
    header[2] = (length >> 8) & 0xFF;
    header[3] = length & 0xFF;

    final result = Uint8List(4 + length);
    result.setRange(0, 4, header);
    result.setRange(4, 4 + length, data);
    return result;
  }
}

Uint8List _u32le(int value) {
  final bd = ByteData(4);
  bd.setUint32(0, value, Endian.little);
  return bd.buffer.asUint8List();
}

Uint8List _u32be(int value) {
  final bd = ByteData(4);
  bd.setUint32(0, value, Endian.big);
  return bd.buffer.asUint8List();
}

class FlacVorbisComment {
  final String vendorString;
  final Map<String, String> tags;

  const FlacVorbisComment({
    this.vendorString = 'Melodi',
    this.tags = const {},
  });

  Uint8List encode() {
    final bytes = BytesBuilder();

    final vendorBytes = utf8.encode(vendorString);
    bytes.add(_u32le(vendorBytes.length));
    bytes.add(vendorBytes);

    final tagEntries = tags.entries.toList();
    bytes.add(_u32le(tagEntries.length));

    for (final entry in tagEntries) {
      final tagStr = '${entry.key}=${entry.value}';
      final tagBytes = utf8.encode(tagStr);
      bytes.add(_u32le(tagBytes.length));
      bytes.add(tagBytes);
    }

    return bytes.toBytes();
  }

  factory FlacVorbisComment.decode(Uint8List data) {
    var offset = 0;

    final vendorLen = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.little);
    offset += 4;
    final vendorString = utf8.decode(data.sublist(offset, offset + vendorLen));
    offset += vendorLen;

    final numTags = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.little);
    offset += 4;

    final tags = <String, String>{};
    for (var i = 0; i < numTags; i++) {
      if (offset + 4 > data.length) break;
      final tagLen = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.little);
      offset += 4;

      if (offset + tagLen > data.length) break;
      final tagStr = utf8.decode(data.sublist(offset, offset + tagLen));
      offset += tagLen;

      final eqIdx = tagStr.indexOf('=');
      if (eqIdx > 0) {
        tags[tagStr.substring(0, eqIdx)] = tagStr.substring(eqIdx + 1);
      }
    }

    return FlacVorbisComment(vendorString: vendorString, tags: tags);
  }
}

class FlacPicture {
  final int pictureType;
  final String mimeType;
  final String description;
  final int width;
  final int height;
  final int colorDepth;
  final int colorsUsed;
  final Uint8List pictureData;

  const FlacPicture({
    this.pictureType = 3,
    this.mimeType = 'image/jpeg',
    this.description = '',
    this.width = 0,
    this.height = 0,
    this.colorDepth = 0,
    this.colorsUsed = 0,
    required this.pictureData,
  });

  Uint8List encode() {
    final bytes = BytesBuilder();

    bytes.add(_u32be(pictureType));

    final mimeBytes = utf8.encode(mimeType);
    bytes.add(_u32be(mimeBytes.length));
    bytes.add(mimeBytes);

    final descBytes = utf8.encode(description);
    bytes.add(_u32be(descBytes.length));
    bytes.add(descBytes);

    bytes.add(_u32be(width));
    bytes.add(_u32be(height));
    bytes.add(_u32be(colorDepth));
    bytes.add(_u32be(colorsUsed));
    bytes.add(_u32be(pictureData.length));
    bytes.add(pictureData);

    return bytes.toBytes();
  }

  factory FlacPicture.decode(Uint8List data) {
    var offset = 0;

    final pictureType = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;

    final mimeLen = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    final mimeType = utf8.decode(data.sublist(offset, offset + mimeLen));
    offset += mimeLen;

    final descLen = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    final description = utf8.decode(data.sublist(offset, offset + descLen));
    offset += descLen;

    final width = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    final height = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    final colorDepth = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    final colorsUsed = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;

    final picLen = ByteData.sublistView(data, offset, offset + 4).getUint32(0, Endian.big);
    offset += 4;
    final pictureData = data.sublist(offset, offset + picLen);

    return FlacPicture(
      pictureType: pictureType,
      mimeType: mimeType,
      description: description,
      width: width,
      height: height,
      colorDepth: colorDepth,
      colorsUsed: colorsUsed,
      pictureData: Uint8List.fromList(pictureData),
    );
  }
}

class FlacEmbedder {
  FlacEmbedder._();

  static const int _blockTypeStreamInfo = 0;
  static const int _blockTypePadding = 1;
  static const int _blockTypeSeektable = 3;
  static const int _blockTypeVorbisComment = 4;
  static const int _blockTypePicture = 6;

  static const String _flacMagic = 'fLaC';

  static Future<Map<String, String>> readTags(String flacPath) async {
    try {
      final blocks = await _readMetadataBlocks(flacPath);
      for (final block in blocks) {
        if (block.type == _blockTypeVorbisComment) {
          final comment = FlacVorbisComment.decode(block.data);
          return Map.from(comment.tags);
        }
      }
    } catch (e) {
      debugPrint('readTags failed: $e');
    }
    return {};
  }

  static Future<List<FlacMetadataBlock>> _readMetadataBlocks(
      String flacPath) async {
    final file = File(flacPath);
    final bytes = await file.readAsBytes();

    if (bytes.length < 4) {
      throw FormatException('File too small to be a FLAC file');
    }

    final magic = utf8.decode(bytes.sublist(0, 4));
    if (magic != _flacMagic) {
      throw FormatException('Not a valid FLAC file');
    }

    final blocks = <FlacMetadataBlock>[];
    var offset = 4;

    while (offset + 4 <= bytes.length) {
      final isLast = (bytes[offset] & 0x80) != 0;
      final blockType = bytes[offset] & 0x7F;
      final blockLen = (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];

      offset += 4;

      if (offset + blockLen > bytes.length) break;

      final blockData = bytes.sublist(offset, offset + blockLen);
      blocks.add(FlacMetadataBlock(
        type: blockType,
        isLast: isLast,
        data: Uint8List.fromList(blockData),
      ));

      offset += blockLen;

      if (isLast) break;
    }

    return blocks;
  }

  static Future<void> embedMetadata(
    String flacPath, {
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? comment,
    String? lyrics,
    Uint8List? coverArt,
  }) async {
    try {
      final blocks = await _readMetadataBlocks(flacPath);
      final file = File(flacPath);
      final fileBytes = await file.readAsBytes();

      final tags = <String, String>{};
      if (title != null) tags['TITLE'] = title;
      if (artist != null) tags['ARTIST'] = artist;
      if (album != null) tags['ALBUM'] = album;
      if (genre != null) tags['GENRE'] = genre;
      if (year != null) tags['DATE'] = year.toString();
      if (trackNumber != null) tags['TRACKNUMBER'] = trackNumber.toString();
      if (discNumber != null) tags['DISCNUMBER'] = discNumber.toString();
      if (comment != null) tags['DESCRIPTION'] = comment;
      if (lyrics != null) tags['LYRICS'] = lyrics;

      final commentBlock = FlacVorbisComment(tags: tags);
      final commentData = commentBlock.encode();

      final newBlocks = <FlacMetadataBlock>[];
      var replacedComment = false;
      var replacedPicture = false;

      for (final block in blocks) {
        if (block.type == _blockTypeStreamInfo) {
          newBlocks.add(FlacMetadataBlock(
            type: block.type,
            isLast: false,
            data: block.data,
          ));
        } else if (block.type == _blockTypeVorbisComment) {
          newBlocks.add(FlacMetadataBlock(
            type: block.type,
            isLast: false,
            data: commentData,
          ));
          replacedComment = true;
        } else if (block.type == _blockTypePicture) {
          if (coverArt != null) {
            replacedPicture = true;
          }
        } else if (block.type != _blockTypePadding) {
          newBlocks.add(block);
        }
      }

      if (!replacedComment) {
        newBlocks.add(FlacMetadataBlock(
          type: _blockTypeVorbisComment,
          isLast: false,
          data: commentData,
        ));
      }

      if (coverArt != null) {
        _detectImageDimensions(coverArt);
        final picture = FlacPicture(
          pictureData: coverArt,
          mimeType: _detectMimeType(coverArt),
        );
        newBlocks.add(FlacMetadataBlock(
          type: _blockTypePicture,
          isLast: false,
          data: picture.encode(),
        ));
      }

      if (newBlocks.isNotEmpty) {
        newBlocks.last = FlacMetadataBlock(
          type: newBlocks.last.type,
          isLast: true,
          data: newBlocks.last.data,
        );
      }

      final output = BytesBuilder();
      output.add(utf8.encode(_flacMagic));
      for (final block in newBlocks) {
        output.add(block.encode());
      }

      final audioStart = _findAudioStart(fileBytes);
      if (audioStart > 0) {
        output.add(fileBytes.sublist(audioStart));
      }

      await file.writeAsBytes(output.toBytes());
    } catch (e) {
      debugPrint('embedMetadata failed: $e');
      rethrow;
    }
  }

  static Future<void> embedCoverArt(
      String flacPath, Uint8List imageData) async {
    await embedMetadata(flacPath, coverArt: imageData);
  }

  static int _findAudioStart(List<int> bytes) {
    var offset = 4;
    while (offset + 4 <= bytes.length) {
      final isLast = (bytes[offset] & 0x80) != 0;
      final blockLen = (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      offset += 4 + blockLen;
      if (isLast) break;
    }
    return offset;
  }

  static String _detectMimeType(Uint8List data) {
    if (data.length < 8) return 'image/jpeg';
    if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
      return 'image/png';
    }
    if (data[0] == 0xFF && data[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static (int, int) _detectImageDimensions(Uint8List data) {
    try {
      if (data[0] == 0xFF && data[1] == 0xD8) {
        var offset = 2;
        while (offset + 4 < data.length) {
          if (data[offset] == 0xFF && data[offset + 1] == 0xC0 ||
              data[offset] == 0xFF && data[offset + 1] == 0xC2) {
            final height = (data[offset + 5] << 8) | data[offset + 6];
            final width = (data[offset + 7] << 8) | data[offset + 8];
            return (width, height);
          }
          offset += 2 + ((data[offset + 2] << 8) | data[offset + 3]);
        }
      } else if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
        final width = (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19];
        final height = (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
        return (width, height);
      }
    } catch (_) {}
    return (0, 0);
  }

  static Future<void> addReplayGain(String flacPath) async {
    try {
      final process = await Process.start('metaflac', [
        '--add-replay-gain',
        flacPath,
      ]);
      await process.exitCode;
    } catch (e) {
      debugPrint('addReplayGain failed: $e');
    }
  }

}
