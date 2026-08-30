import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/api.dart';
import '../music_source.dart';

class JioSaavnSource implements MusicSource {
  static const _searchUrl =
      'https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0.407434645520672&cc=in&includeMetaTags=1&query=';
  static const _songUrl =
      'https://www.jiosaavn.com/api.php?__call=song.getDetails&cc=in&_marker=0.3648156743570088&api_version=4&_format=json&pids=';

  @override
  MusicSourceType get type => MusicSourceType.jiosaavn;

  @override
  String get name => 'JioSaavn';

  @override
  Future<List<OnlineTrack>> search(String query, {int limit = 20}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_searchUrl${Uri.encodeComponent(query)}');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent',
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return [];
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final songs = data['songs']?['data'] as List?;
      if (songs == null) return [];
      final results = <OnlineTrack>[];
      for (final song in songs) {
        if (results.length >= limit) break;
        final id = song['id']?.toString() ?? '';
        final title = song['title']?.toString() ?? '';
        final artist = song['description']?.toString() ?? '';
        final duration = Duration(
            seconds: int.tryParse(song['duration']?.toString() ?? '0') ?? 0);
        final image = song['image']?['quality'] != null ? song['image'] : null;
        String? thumbUrl;
        if (image != null) {
          // Try to get medium quality image
          final imageMap = image as Map<String, dynamic>;
          thumbUrl =
              imageMap['medium']?.toString() ?? imageMap['small']?.toString();
          // Convert protocol-relative URLs
          if (thumbUrl != null && thumbUrl.startsWith('//')) {
            thumbUrl = 'https:$thumbUrl';
          }
        }
        results.add(OnlineTrack(
          id: 'jio_$id',
          title: title,
          artist: artist,
          duration: duration,
          thumbnailUrl: thumbUrl,
          source: MusicSourceType.jiosaavn,
        ));
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  String? _decrypt(String? enc) {
    if (enc == null || enc.isEmpty) return null;
    try {
      final keyBytes = Uint8List.fromList(utf8.encode('38346591'));
      final key24 = Uint8List(24);
      for (var i = 0; i < 24; i++) key24[i] = keyBytes[i % 8];
      final encrypted = base64Decode(enc);
      if (encrypted.length % 8 != 0) return null;
      final cipher = ECBBlockCipher(DESedeEngine())..init(false, KeyParameter(key24));
      final decrypted = Uint8List(encrypted.length);
      for (var offset = 0; offset < encrypted.length; offset += 8) {
        cipher.processBlock(encrypted, offset, decrypted, offset);
      }
      final pad = decrypted[decrypted.length - 1];
      String text;
      if (pad > 0 && pad <= 8) {
        var valid = true;
        for (var i = decrypted.length - pad; i < decrypted.length; i++) {
          if (decrypted[i] != pad) valid = false;
        }
        if (valid) {
          text = utf8.decode(decrypted.sublist(0, decrypted.length - pad), allowMalformed: true);
        } else {
          text = utf8.decode(decrypted, allowMalformed: true);
        }
      } else {
        text = utf8.decode(decrypted, allowMalformed: true);
      }
      final clean = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
      if (clean.startsWith('http')) return clean;
      final match = RegExp(r'https?://[^\s]+').firstMatch(text);
      return match?.group(0);
    } catch (_) {
      return null;
    }
  }

  String _qualityUrl(String baseUrl, String quality) {
    // Saavn decrypt yields 96kbps (_96.mp4). Replace suffix for higher quality
    // 96 -> 320 if available, 160, etc. Try 320 first.
    if (quality == 'high' && baseUrl.contains('_96.mp4')) {
      return baseUrl.replaceAll('_96.mp4', '_320.mp4');
    }
    if (quality == 'high' && baseUrl.contains('_96')) {
      return baseUrl.replaceAll('_96', '_320');
    }
    return baseUrl;
  }

  @override
  Future<String?> getStreamUrl(OnlineTrack track) async {
    try {
      final songId = track.id.replaceFirst('jio_', '');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse('$_songUrl$songId');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent',
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)');
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final songData = data[songId] as Map<String, dynamic>?;
      if (songData == null) return null;
      // Önce düz media_url dene
      var url = songData['media_url']?.toString();
      if (url != null && url.isNotEmpty && url.startsWith('http')) return url;
      // Şifreli alanları çöz
      for (final key in ['encrypted_media_url', 'encrypted_cache_url', 'encrypted_drm_media_url']) {
        final enc = songData[key]?.toString();
        final dec = _decrypt(enc);
        if (dec != null && dec.isNotEmpty) {
          final high = _qualityUrl(dec, 'high');
          if (high.startsWith('http')) return high;
          return dec;
        }
      }
      final previewEnc = songData['encrypted_media_preview_url']?.toString();
      final previewDec = _decrypt(previewEnc);
      if (previewDec != null && previewDec.startsWith('http')) return previewDec;
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {}
}
