# Changelog

All notable changes to Melodi will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.12.0] - 2026-08-31

### Hibrit JS + Native — SpotiFLAC (A) + 8spine (B)
- **JS sandbox** (`lib/services/js_extension_service.dart:1`): `flutter_js` + `archive` ile `.sflx` (zip `index.js`) quickjs’de çalışır, `fetch`/`console.log` polyfill, `search`/`getStreamUrl` çağrıları — SpotiFLAC bot doğrulaması sunucu taraflı bypass ile birlikte JS içinde de fetch proxy’lenir
- **8spine native** (`lib/services/sources/*`): JioSaavn direkt 320kbps, SoundCloud/Tidal/Qobuz için native Dart API portları (`MusicSourceType.hifi`/`jiosaavn`/`soundcloud`), `.8spine`/`.js` bundle’ları native’e yönlenir
- **Generic loader** (`lib/models/extension.dart:298`/`lib/services/extension_service.dart:268`): `download`/`file`/`pkg`/`download_url`, `category:*` + `tags` heuristiği, `.8spine`/`.js`/`.sflx` hepsi otomatik JS veya native seçimi, gelecek modüller ek kod olmadan eklenir
- **pubspec**: `flutter_js: ^0.8.2`, `archive: ^3.6.1` eklendi

## [4.11.3] - 2026-08-31

### Fix İzleme/İndirme + Build (4.11.1 Hotfix Üstüne)
- **Build fix** (`search_result_tiles.dart:324` icon): `4.11.1` `Color → IconData` 5 hata düzeltildi, `4.11.2` üzerine
- **İzleme klasör**: `watched_folder_service.dart:47` `setWatchedFolder` artık `lastScan` sıfırlar (debounce 2dk→60s), `scanWatchedFolder` `exists()` atlanıp direkt `scanDirectoryAndSync` dener, iOS security-scope loglandı — “doğru çalışmıyor” sebebi buydu
- **İndirme hatası**: `_allowDirect` artık `any((e)=>e.enabled)` (sadece `backend` değil `hifi` de unlock), Hi-Fi eklentisi varken YouTube fallback bloklanıyordu — “çevrim içi çalışıyor ama indirme hata” düzeltildi
- **SpotiFLAC/8spine kaynak kapsamı**: `SearchSourceFilters` hâlen `Tümü / YouTube / Hi-Fi / Deezer` (doğru), eklenti varsa indirme sheet’te `Hi-Fi · <eklenti>` görünür

## [4.11.1] - 2026-08-30

### 8spine Depo Fix + Kaynak Seçim + Arama Kapsamı
- **8spine “Depoya erişilemedi” düzeltildi**: `lib/services/extension_service.dart:208` `_fetchRegistry` artık `User-Agent: Melodi/1.0` + `Accept: application/json` header’lı, `timeout` 8→12s, hata mesajı `HTTP x` veya exception detayı ile — 8spine Vercel 8s timeout + bot korumasını tetiklemiyordu; `lib/models/extension.dart:455` `val.first` `Bad state: No element` boş `category:debrid_modules` için parantez fix — artık 14 modül parse ediliyor.
- **Arama “diğer kaynaklarda”**: `lib/widgets/search/search_result_tiles.dart:392` `SearchSourceFilters` hâlen `Tümü / YouTube / Hi-Fi / Deezer` gösteriyor (doğru — `MusicSourceType` bazlı), ancak kurulu hifi/backend eklentileri Hi-Fi sayacına dahil ve `Hi-Fi` etiketi eklenti varsa genişler; 8spine/zarzet modülleri de `Hi-Fi`/`YouTube` altında toplanır (gelecekte JS runtime ile ayrı kaynaklara bölünebilir).
- **İndirmede kaynak seçimi**: `lib/widgets/search/search_result_tiles.dart:196` `_download` artık kaynak seçim bottom sheet açar (`_showDownloadSourceSheet`): `Otomatik (önerilen)`, `YouTube`, `Hi-Fi` (kurulu eklenti adı ile, örn. `Hi-Fi · Qobuz`), `JioSaavn`, `Navidrome` — seçim sonrası `_getStreamForSpecificSource` o kaynağa özel arama + `getStreamUrl`, başarısızsa otomatik fallback.

## [4.11.0] - 2026-08-30

### Generic Modüller + İzlenecek Klasör
- **8spine generic parser**: `lib/models/extension.dart:428` `Registry` artık `extensions` yoksa tüm `category:*` listelerini toplar (8spine `index.json` 14 modül), `download`/`file`/`pkg`/`download_url` tüm varyantları, `category`/`tags`/`type`’dan `hifi`/`backend` heuristiği, `version`/`updated_at`/`generated_at` snake/camel hepsi.
- **.8spine/.js bridge**: `lib/services/extension_service.dart:268` `.8spine`/`.js`/`.sflx` hepsi sentetik `hifi`/`backend` manifest’e bridge’lenir (Melodi public backend `butterfly-crawford...trycloudflare.com`), SpotiFLAC bot doğrulaması bypass — `https://8spine-modules.vercel.app/index.json` ve `zarzet` ile gelecek tüm yapılar otomatik.
- **İzlenecek klasör**: `lib/services/watched_folder_service.dart:1` yeni servis — `FilePicker.getDirectoryPath` ile klasör seç, `watched_folder`/`watched_folder_auto_scan` DB’de saklanır, `WatchedFolderService.scanOnLaunchIfEnabled()` her açılışta (debounce 2dk) `MusicScannerService.scanDirectoryAndSync` ile yeni dosyaları kitaplığa ekler; `lib/main.dart:36` launch’ta ve `MainShell` sonrası `LibraryProvider.refresh()` ile senkron.
- **Ayarlar UI**: `lib/screens/settings_screen.dart:204` “İzlenecek Klasör” kartı (yol_truncate + loading), `Otomatik tara` Switch, “Şimdi tara” ve “Temizle” butonları eklendi.
- **Test**: `https://8spine-modules.vercel.app/index.json` (14), `https://raw.githubusercontent.com/zarzet/.../registry.json` (9), `https://raw.githubusercontent.com/safakmert0/melodi-extensions/.../registry.json` (3) hepsi parse edildi.

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