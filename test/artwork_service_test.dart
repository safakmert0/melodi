import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/services/artwork_service.dart';

void main() {
  group('Artwork matching', () {
    test('accepts the same song and artist with harmless title suffixes', () {
      expect(
        ArtworkService.isConfidentMatch(
          title: 'Keşke',
          artist: 'BLOK3',
          album: 'Keşke',
          duration: const Duration(minutes: 3, seconds: 27),
          candidateTitle: 'Keşke (Official Audio)',
          candidateArtist: 'BLOK3',
          candidateAlbum: 'Keşke - Single',
          candidateDuration: const Duration(minutes: 3, seconds: 28),
        ),
        isTrue,
      );
    });

    test('rejects an unrelated first search result', () {
      expect(
        ArtworkService.isConfidentMatch(
          title: 'Keşke',
          artist: 'BLOK3',
          album: 'Keşke',
          candidateTitle: 'Başka Bir Şarkı',
          candidateArtist: 'Başka Sanatçı',
          candidateAlbum: 'Rastgele Albüm',
        ),
        isFalse,
      );
    });

    test('does not search placeholder-only local metadata', () {
      expect(
        ArtworkService.canSearch(
          title: 'track-01',
          artist: 'Unknown Artist',
          album: 'Unknown Album',
        ),
        isFalse,
      );
    });

    test('rejects a grossly different duration', () {
      expect(
        ArtworkService.isConfidentMatch(
          title: 'Keşke',
          artist: 'BLOK3',
          album: 'Keşke',
          duration: const Duration(minutes: 3, seconds: 27),
          candidateTitle: 'Keşke',
          candidateArtist: 'BLOK3',
          candidateAlbum: 'Keşke',
          candidateDuration: const Duration(minutes: 8),
        ),
        isFalse,
      );
    });
  });
}
