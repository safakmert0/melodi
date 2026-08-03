import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodi/core/localization.dart';
import 'package:melodi/providers/connection_provider.dart';
import 'package:melodi/services/spotify_service.dart';
import 'package:melodi/services/ytmusic_service.dart';
import 'package:melodi/widgets/home/home_header.dart';

void main() {
  testWidgets('home toolbar controls stay above the headline', (tester) async {
    AppLocale.currentLocale = 'tr';
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final connection = ConnectionProvider(
      spotifyService: SpotifyService(),
      ytmusicService: YTMusicService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [HomeHeader(connection: connection)],
          ),
        ),
      ),
    );

    final headline = find.text('Bugün ne dinleyeceksin?');
    expect(headline, findsOneWidget);
    final controlsBottom = [
      tester.getRect(find.byIcon(Icons.hub_outlined)).bottom,
      tester.getRect(find.byIcon(Icons.person_rounded)).bottom,
      tester.getRect(find.byIcon(Icons.settings_rounded)).bottom,
    ].reduce((left, right) => left > right ? left : right);
    expect(controlsBottom, lessThan(tester.getRect(headline).top));
  });
}
