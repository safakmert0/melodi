import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> arguments) async {
  final videoId = arguments.isEmpty ? 'jNQXAC9IVRw' : arguments.first;
  final youtube = YoutubeExplode();
  try {
    final manifest = await youtube.videos.streams.getManifest(
      videoId,
      requireWatchPage: true,
      ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
    );
    final audio = manifest.audioOnly.toList()
      ..sort(
          (a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    if (audio.isEmpty) throw StateError('No audio streams for $videoId');
    final selected = audio.last;
    final client = HttpClient();
    try {
      final request = await client.getUrl(selected.url);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-4095');
      final response = await request.close();
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
      }
      stdout.writeln(
        'video=$videoId status=${response.statusCode} bytes=$received '
        'mime=${response.headers.contentType?.mimeType ?? selected.codec.mimeType}',
      );
      if (response.statusCode != HttpStatus.partialContent ||
          received != 4096) {
        exitCode = 1;
      }

      final fullRequest = await client.getUrl(selected.url);
      final fullResponse = await fullRequest.close();
      var fullBytes = 0;
      await for (final chunk in fullResponse) {
        fullBytes += chunk.length;
      }
      stdout.writeln(
        'download_status=${fullResponse.statusCode} bytes=$fullBytes',
      );
      if (fullResponse.statusCode != HttpStatus.ok || fullBytes < 1000) {
        exitCode = 1;
      }
    } finally {
      client.close(force: true);
    }
  } finally {
    youtube.close();
  }
}
