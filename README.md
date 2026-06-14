<h1 align="center">🎵 Melodi</h1>

<p align="center">
  <b>Premium Local Music Player for iOS</b><br>
  <i>Inspired by Spotify & Apple Music — crafted with Flutter</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS-black?style=flat-square&logo=apple">
  <img src="https://img.shields.io/badge/built%20with-Flutter-02569B?style=flat-square&logo=flutter">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square">
  <img src="https://img.shields.io/badge/status-active-success?style=flat-square">
</p>

<br>

## ✨ Features

| | |
|---|---|
| 🎶 **All Audio Formats** | MP3, M4A, FLAC, WAV, AAC, OGG, WMA, ALAC, AIFF, OPUS, APE |
| 📂 **Local Music Scan** | Apple Music library + Files app import |
| 🎨 **Spotify-Like UI** | Dark theme, smooth animations, modern design |
| ▶️ **Now Playing** | Full-screen player with album art, seek bar, queue |
| 📋 **Playlists** | Create, edit, reorder, delete |
| ❤️ **Favorites** | Mark songs as favorites |
| 🔍 **Search** | Search by song, artist, album |
| 🔀 **Queue** | Add to queue, reorder, shuffle, repeat |
| 📱 **Lock Screen** | Background playback with lock screen controls |
| 🗄️ **SQLite Database** | Persistent storage for songs, playlists, favorites |

<br>

## 🎨 Screenshots

<p align="center">
  <i>📸 Screenshots coming soon!</i>
</p>

<!-- 
![Home](screenshots/home.png)
![Now Playing](screenshots/now_playing.png)
![Library](screenshots/library.png)
![Search](screenshots/search.png)
-->

<br>

## 🚀 Getting Started

### Prerequisites

- Flutter 3.44+
- Xcode 16+
- iOS 16+

### Installation

```bash
# Clone the repository
git clone https://github.com/safakmert0/melodi.git
cd melodi

# Install dependencies
flutter pub get
cd ios && pod install && cd ..

# Run on device/simulator
flutter run
```

### Build Unsigned IPA

```bash
# Using build script
chmod +x build_ipa.sh
./build_ipa.sh

# Or manually
flutter build ios --debug --no-codesign
```

> **Note:** The IPA is unsigned. Use [Sideloadly](https://sideloadly.io) or [AltStore](https://altstore.io) to sideload.

<br>

## 🏗️ Built With

- [Flutter](https://flutter.dev) — UI Framework
- [just_audio](https://pub.dev/packages/just_audio) — Audio Playback
- [audio_service](https://pub.dev/packages/audio_service) — Background Audio
- [on_audio_query](https://pub.dev/packages/on_audio_query) — Media Library
- [sqflite](https://pub.dev/packages/sqflite) — Local Database
- [Provider](https://pub.dev/packages/provider) — State Management
- [file_picker](https://pub.dev/packages/file_picker) — File Import

<br>

## 📁 Project Structure

```
lib/
├── app.dart                  # App entry point with providers
├── main.dart                 # Main entry + audio service init
├── core/
│   ├── constants.dart        # Theme, colors, app constants
│   └── extensions/           # Duration extensions
├── models/
│   ├── song_model.dart
│   ├── album_model.dart
│   ├── artist_model.dart
│   ├── playlist_model.dart
│   └── genre_model.dart
├── providers/
│   ├── player_provider.dart
│   ├── library_provider.dart
│   ├── playlist_provider.dart
│   └── search_provider.dart
├── screens/
│   ├── home_screen.dart
│   ├── library_screen.dart
│   ├── now_playing_screen.dart
│   ├── search_screen.dart
│   ├── playlist_detail_screen.dart
│   └── settings_screen.dart
├── services/
│   ├── audio_handler.dart
│   ├── database_service.dart
│   ├── metadata_service.dart
│   └── music_scanner_service.dart
└── widgets/
    ├── mini_player.dart
    ├── seek_bar.dart
    ├── song_tile.dart
    ├── album_card.dart
    ├── artist_card.dart
    ├── playlist_card.dart
    ├── queue_sheet.dart
    └── image_with_fallback.dart
```

<br>

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

<br>

## 📄 License

[MIT](LICENSE)

<br>

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/safakmert0">safakmert0</a>
  <br>
  ⭐ Star this project if you like it!
</p>
