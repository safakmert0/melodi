## Goal
- Add LRCLib auto lyrics, iTunes artwork, and CarPlay to Melodi, then fix the resulting crashes and black screen

## Constraints & Preferences
- Build via GitHub Actions on `macos-15-intel`, Flutter 3.44.2, `flutter create . --platforms=ios` before build
- IPA unsigned, requires manual codesigning for device
- User tests on physical iOS device
- User's local IPA files at `C:\Users\safak\Downloads\` (Windows, accessible at `/mnt/c/Users/safak/Downloads/` under WSL)

## Progress
### Done
- v1.7.6: removed `UIApplicationSceneManifest` from `Info.plist` → black screen fixed (Flutter 3.44.2's `flutter create` does NOT overwrite existing `ios/` files, so `SceneDelegate.swift` is never generated; referencing non-existent class causes black screen)
- v1.7.6-test confirmed: minimal "Merhaba" screen without `UIApplicationSceneManifest` works on device
- LocalAudioPlayer-1.5.8.ipa extracted and analyzed: native Swift app, uses `UIApplicationSceneManifest` without `UISceneDelegateClassName`, has CarPlay, min iOS 16.0
- Stash repo (rawnaldclark/Stash) reviewed: Android-only LRCLIB/Spotify/YT Music
- Settings "Ses Eşitleyici" (equalizer), playback speed, volume boost removed (controls already in NowPlayingScreen)
- Lazy `YoutubeExplode` init (`_client` getter instead of eager field)
- `ErrorWidget.builder` override for visible build errors in release mode
- `main()` wrapped in try-catch with error-display fallback `MaterialApp`
- `AudioService.init` 8s timeout fallback
- **v1.7.7**: Dynamic Island album art, theme accent colors, debounced YouTube search
- **v1.7.7**: All `const` + `AppTheme.primaryColor` incompatibilities fixed (primaryColor is now a getter)
- **v1.7.7**: Old `AppTheme.lightTheme`/`darkTheme` static getters removed (replaced by ThemeProvider dynamic themes)

### In Progress
- Karaoke word-by-word lyrics: LRCLIB only provides line-level timestamps; different service needed

### Blocked
- Karaoke lyrics: no word-level timestamp source identified yet

## Key Decisions
- `UIApplicationSceneManifest` removed from `Info.plist` – Flutter 3.44.2 does NOT regenerate existing iOS files
- `primaryColor`/`accentColor`/`gradientStart`/`gradientEnd` changed from `static const` to `static get` backed by `_accentColorValue` – allows runtime accent color switching; all `const` widget usages must use non-const instead
- `ThemeProvider` now builds themes dynamically via `_buildLightTheme()`/`_buildDarkTheme()` using `_accentColor`
- Accent color persisted in DB via `DatabaseService.setSetting('accent_color', ...)`
- Search input debounced at 400ms to prevent excessive YouTube API calls on each keystroke
- Album art written to temp file (`getTemporaryDirectory()/nowplaying_art.jpg`) and referenced via `artUri` on `MediaItem`

## Next Steps
1. User tests v1.7.7 IPA – Dynamic Island art, accent colors, debounced search
2. Karaoke lyrics research (word-by-word from alternative service or local LRC parsing)

## Critical Context
- **Flutter 3.44.2 does NOT overwrite existing iOS files** – `SceneDelegate.swift` is never generated if `ios/` dir already exists. Any `Info.plist` referencing `SceneDelegate` class causes black screen.
- **`AppTheme.primaryColor` is no longer `const`** – it's a getter returning `_accentColorValue`. Any `const Widget(color: AppTheme.primaryColor, ...)` will fail at compile time.
- **LRCLIB only provides line-level timestamps**, not word-level. Karaoke word-by-word display requires a different lyrics source.

## Relevant Files
- `lib/services/audio_handler.dart`: `artUri` set from temp file in `_playCurrent` (Dynamic Island fix)
- `lib/providers/theme_provider.dart`: `_accentColor`, `loadSettings()`, `setAccentColor()`, `_buildLightTheme()`/`_buildDarkTheme()`
- `lib/core/constants.dart`: `primaryColor`/`accentColor`/`gradientStart`/`gradientEnd` as dynamic getters, old static themes removed
- `lib/screens/settings_screen.dart`: accent color picker with 20 presets, audio section removed
- `lib/screens/search_screen.dart`: `Timer _debounce` with 400ms delay on search
- `lib/main.dart`: `themeProvider.lightTheme`/`darkTheme`/`themeMode`, `..loadSettings()` init
- `lib/core/localization.dart`: `accent_color`, `tap_to_change` in en/tr/de
- `pubspec.yaml`: version `1.7.7`
