# Changelog

All notable changes to Melodi will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.10.2] - 2026-08-30

### Hotfix — 4.10.1 build hatası
- `lib/screens/onboarding_screen.dart:335` `const SourceHubScreen()` “Not a constant expression” build hatası düzeltildi: ölü `_buildSources` metodu tamamen kaldırıldı (import da kaldırılmıştı).

## [4.10.1] - 2026-08-30

### Fix & Performance — 8 talep birleştirildi
- **Onboarding**: "Kaynaklarını birleştir" adımı kaldırıldı (`onboarding_screen.dart:21` `_pageCount` 4→3).
- **Çevrimiçi çalma hız**: `audio_handler` 800/1200ms gecikmeleri kaldırıldı, `robust_piped`/`piped`/`yt_dlp`/`extension_service`/`backend_api` timeout'ları 30/15→12/6 saniyeye indirildi, piped seed sadece eklenti varsa.
- **İndirme hız**: `download_manager` `_maxParallel` 1→2 (max 3), HEAD 10→6s, GET 120→60s, retry slot serbest bırakma.
- **iPhone Dosyalar**: İndirme zaten `Documents/Melodi/Offline` (`storage_manager.dart:41`, `UIFileSharingEnabled=true`) — doğrulandı, özel klasör görünür.
- **Süre mismatch (3:25 vs 6:54)**: `audio_handler.dart:88` duration mismatch guard (`_isDurationCompatible` 15% / 20-60s), `position`/`duration` getter’ları ve `crossfade` efektif süre kullanır, `durationStream` medya öğesini expected ile doğrular, 500ms poll 2 sn’ye çıkarıldı; ses bitince ilerleme durur ve `completed` tetiklenir.
- **Tema**: Vurgu rengi 11→5’e indi (`settings_screen.dart:537` yeşil/mavi/mor/turuncu/kırmızı); beyaz/sarı/teal kaldırıldı (kontrast).
- **Pop-up okunurluk**: `extension_store_screen.dart:123` `_toast` artık `primary` değil `inverseSurface` kullanır (`errorRed` hata için beyaz metin), tema SnackBar `inverseSurface` ile uyumlu.
- **Ayarlar**: `Teşekkürler` (acknowledgments) kartı kaldırıldı; `Destek Ol` sideload’da `Mağaza kullanılamıyor` bilgisi + `Tekrar dene` + `GitHub’da destekle` fallback eklendi (`support_screen.dart:185`).
- **Zarzet SpotiFLAC-Extension**: `extension.dart:298` `RegistryEntry` artık `download_url`/`display_name`/`category` ve `updated_at` snake’i destekler; `ExtensionRegistry` 9 zarzet girdisini parse eder; `extension_service.dart:266` `.sflx`/`.spotiflac-ext` için sentetik `hifi`/`backend` manifest üretir (Melodi public backend’e bridge), `https://raw.githubusercontent.com/zarzet/SpotiFLAC-Extension/main/registry.json` eklenince 9 eklenti kurulabilir hale geldi.

## [4.10.0] - 2026-08-30

### App Store Hibrit (B) — Temiz Base + Eklenti Premium
- **B-Hybrid mimarisi**: App Store IPA'sı varsayılan olarak YouTube/JioSaavn içermez; **eklenti mağazasından** `ytdlpBackend` eklentisi kurulunca premium açılır (Guideline 5.2.3 uyumu).
- **`AppConfig` (lib/core/app_config.dart)**: `--dart-define=APP_STORE=true` ve `DISABLE_YTDLP_DIRECT=true` ile tüm doğrudan YouTube yolları gate'lendi.
- **Gate'lenen servisler**: `yt_dlp_service`, `youtube_downloader`, `piped_service`, `robust_piped_service`, `hls_downloader_service`, `multi_source_search` — eklenti `ExtensionKind.backend` yoksa `null`/boş liste döner; `source_catalog` YouTube/JioSaavn kartlarını gizler; `extension_service` resmi repo'yu App Store'da otomatik eklemez.
- **UI**: `extension_store_screen` ve `source_hub_screen` App Store banner'ları eklendi.
- **Info.plist temizliği**: Geçersiz `NSDownloadsFolderUsageDescription` / `NSDocumentsFolderUsageDescription` / `NSDesktopFolderUsageDescription` ve `NSMicrophoneUsageDescription` kaldırıldı; `NSAppleMusicUsageDescription` / `NSPhotoLibraryUsageDescription` / `NSLocalNetworkUsageDescription` netleştirildi.
- **Codemagic**: `melodi-ios` (sideload unsigned, full) korundu; yeni `melodi-ios-app-store` (signed, `flutter build ipa --dart-define=APP_STORE=true`, `fetch-signing-files`, `publish` → TestFlight) eklendi.
- **Dokümantasyon**: `docs/app-store/REVIEW_NOTES.md`, `APP_STORE_CHECKLIST.md`, `CODMAGIC_SETUP.md` eklendi.

## [4.6.0] - 2025-08-25

### App Store Uyumluluk ve Yeniden Yapılanma

#### Kaldırılan Özellikler (App Store uyumu / sadeleştirme)
- Spotify ve YouTube Music **hesap bağlama (OAuth)** akışı kaldırıldı; çalma listesi **link ile ekleme** korundu.
- Last.fm / scrobble özelliği kaldırıldı.
- Senkronizasyon özellikleri kaldırıldı: otomatik senkron, varsayılan eş zamanlama, beğeni aynalama, geçmiş ve scrobble.
- Engellenen parçalar, dosya düzeni, başarısız indirmeler menü girişi (özellik İndirmeler'in içinde kaldı), sesli kitaplar, Siri/sesli kontrol ve AirPlay kaldırıldı.

#### İyileştirmeler
- **Spotify parçası çalınamıyor hatası giderildi**: YouTube eşleşmesi sağlamlaştırıldı (Topic/VEVO normalizasyonu, daha geniş arama, düşük güvenli eşleşmede en iyi çabayla kabul).
- Ses kalitesi varsayılanı ilk yüklemede **tamamen kayıpsız** oldu (akış/indirme/wifi/cellular).
- Kütüphane sağlığı artık sorunları **gerçekten düzeltiyor** ve madde madde başarılı/başarısız raporu veriyor.
- Kitaplık "İndirilenler" bölümü indirilen parçaları gösteriyor; Depolama ekranı şarkı adlarını listeliyor.
- Ekolayzır Ayarlar'dan kaldırılıp **oynatıcı ekranına** taşındı.
- Paylaşılan Bağlantılar: Spotify/YouTube çalma listesi linkleri artık kaydediliyor ve tekrar açılabiliyor.
- Podcast: feed/episode linki eklenince podcast + bölümleri gösteriliyor; bölüm çevrim içi dinenebiliyor veya indirilebiliyor.
- Kapak & söz tamamlama (backfill) geliştirildi; söz çekme artık çalışıyor, toplu işlem daha dayanıklı.
- Ayarlar ekranı düzleştirildi: tüm menüler "Tüm ayarlar"a tıklamadan doğrudan görünüyor.

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