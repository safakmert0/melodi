# Changelog

All notable changes to Melodi will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.5.0] - 2025-08-24

### 🎉 Major Features - Native HLS Downloader (JollyTune/Musix Style)

#### iOS Native HLS Downloader
- **AVAssetDownloadTask** implementation for native HLS segment downloading
- **AVAssetDownloadURLSession** for background downloading support
- **FairPlay DRM** support for protected content
- **Progress tracking** with %95 style progress updates (JollyTune/Musix style)
- **Background download** support - continues when app is backgrounded

#### HLS Manifest Extraction
- **Piped instances** HLS manifest URL extraction
- **Invidious instances** HLS fallback support
- **Backend API** (yt-dlp) integration for HLS manifests
- **Direct YouTube HLS** fallback manifest URL

#### iOS Files App Integration
- **UIFileSharingEnabled** = true for Files app visibility
- **LSSupportsOpeningDocumentsInPlace** = true
- Downloads saved to **Documents/Melodi/Offline/** folder
- Visible in **iOS Files app** under "Melodi" folder
- Files accessible via Share Sheet and other apps

#### Background Download Support
- **AVAssetDownloadURLSession** for true background downloading
- Downloads continue when app is backgrounded/closed
- **Background session** restoration on app launch
- **BGTaskScheduler** integration for background processing

#### FairPlay DRM Support
- **AVAssetDownloadDelegate** implementation
- **FairPlay streaming** support for protected HLS content
- **Asset persistence** for offline playback

### 🔧 Technical Improvements

#### Storage Manager Updates
- iOS Documents directory for Files app visibility
- **UIFileSharingEnabled = true** in Info.plist
- **LSSupportsOpeningDocumentsInPlace = true**
- Downloads stored in `Documents/Melodi/Offline/`

#### Platform Channel Integration
- **MethodChannel**: `com.melodi/hls_downloader`
- Methods: `startHLSDownload`, `cancelHLSDownload`
- Progress callbacks via platform channel

#### Swift Native Implementation
- **AVAssetDownloadURLSession** with **AVAssetDownloadDelegate**
- **AVAssetDownloadTask** for HLS segment downloading
- **FairPlay** content key delegation
- **Background session** handling

### 🎵 Playback Enhancements
- **HLS streaming** from native downloader
- **Offline playback** from downloaded HLS files
- **Seamless transition** between streaming and offline
- **Progress tracking** with %95 style updates

### 📦 Build System
- GitHub Actions workflow for iOS/Android builds
- Automatic IPA/AAB generation on tag push
- GitHub Release creation with artifacts
- Version management via pubspec.yaml

---

## [4.4.0] - Previous Version

### Features
- Multi-source music search (YouTube, Deezer, JioSaavn, Navidrome, etc.)
- Spotify integration with playlist sync
- Local music library with metadata editing
- Audio effects (equalizer, crossfade, gapless)
- Lyrics support with LRC synchronization
- Smart download manager with multiple sources
- Radio/Artist mix generation
- CarPlay support
- Widget support

---

## Upgrade Notes for 4.5.0

### iOS Users
1. **Update to iOS 15.0+** required for AVAssetDownloadTask
2. **Files app** will show "Melodi" folder after first download
3. **Background downloads** work when app is closed
4. **FairPlay content** requires iOS 15.0+

### Breaking Changes
- Minimum iOS version: **15.0** (was 12.0)
- Download location changed to **Documents/Melodi/Offline/**
- HLS downloader requires **iOS 15.0+** for AVAssetDownloadTask

### Migration
- Legacy downloads auto-migrated on first launch
- Database schema updated for HLS download tracking