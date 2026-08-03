import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/artwork_embedding_service.dart';
import 'package:melodi/services/flac_embedder.dart';

void main() {
  test('MP3 cover embedding preserves the original audio payload', () {
    final audio = Uint8List.fromList([0xff, 0xfb, 0x90, 0x64, 1, 2, 3, 4]);
    final artwork = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

    final tagged = Id3CoverArtEmbedder.addCoverArt(audio, artwork);

    expect(tagged, isNotNull);
    expect(ascii.decode(tagged!.sublist(0, 3)), 'ID3');
    expect(ascii.decode(tagged, allowInvalid: true), contains('APIC'));
    expect(tagged.sublist(tagged.length - audio.length), audio);
  });

  test('MP3 cover embedding refuses risky extended ID3 tags', () {
    final source = Uint8List.fromList([
      0x49,
      0x44,
      0x33,
      3,
      0,
      0x40,
      0,
      0,
      0,
      0,
      0xff,
      0xfb,
      0x90,
      0x64,
    ]);
    final artwork = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

    expect(Id3CoverArtEmbedder.addCoverArt(source, artwork), isNull);
  });

  test('FLAC cover embedding preserves existing Vorbis tags', () async {
    final directory = await Directory.systemTemp.createTemp('melodi-flac-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/track.flac');
    final streamInfo = FlacMetadataBlock(
      type: 0,
      isLast: false,
      data: Uint8List(34),
    );
    final comments = FlacMetadataBlock(
      type: 4,
      isLast: true,
      data: const FlacVorbisComment(tags: {
        'TITLE': 'Keşke',
        'ARTIST': 'BLOK3',
        'ALBUM': 'Keşke',
      }).encode(),
    );
    final bytes = BytesBuilder()
      ..add(ascii.encode('fLaC'))
      ..add(streamInfo.encode())
      ..add(comments.encode())
      ..add([0xff, 0xf8, 1, 2, 3, 4]);
    await file.writeAsBytes(bytes.takeBytes());

    await FlacEmbedder.embedCoverArt(
      file.path,
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
    );

    final tags = await FlacEmbedder.readTags(file.path);
    expect(tags['TITLE'], 'Keşke');
    expect(tags['ARTIST'], 'BLOK3');
    expect(tags['ALBUM'], 'Keşke');
  });
}
