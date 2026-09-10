# Changelog

All notable changes to Melodi will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),

## [5.10.7] - 2026-09-10

### Sadece Kendi Oynatici + CarPlay Komple Yok
- Gomulu/YouTube secenekleri kaldirildi: Oynat'a basinca ya uygulamanin oynaticisinda calar ya kisa hata verir. `embed_player_screen`/`embed_playback_service` silindi, webview bagimliligi dustu, mini player tek bar.
- CarPlay tamamen cikarildi (Dart stub + native handler + AppDelegate kaydi); build'de entitlement/scene zaten yoktu. Kilit ekrani `audio_service` ile calismaya devam eder.

## [5.10.6] - 2026-09-10

### Tek Oynatici: Otomatik Ikinci Ekran Yok
- Oynat'a basinca direkt calinamazsa artik otomatik YouTube ekrani acilmiyor; soruyor: Vazgec / YouTube'da ac / Gomulu dene (`search_result_tiles`). Secilmeden ikinci ekran ve ikinci bar cikmaz.

## [5.10.5] - 2026-09-10

### Arka Planda Indirme + AAC Secimi + Gercek Surum
- Arka plan destegi: `background_downloader: ^9.5.9` eklendi; `lib/services/download_manager.dart:597` `_backgroundFetch` iOS URLSession ile indirir — uygulama arkaplanda/kilitte de surer, bitince ayni kapak/soz islem hattina girer. Olmazsa on plan yedek devreye girer.
- Dogrudan calis iyilestirmesi: akista **AAC codec** oncelikli secim (AVPlayer opus/webm'de `-1 bilinmeyen hata` veriyordu; tanilamadaki hata buydu). **Indirmede uzanti farki kalkti**: ne varsa en buyuk dosya iner (m4a/opus/webm/3gp), canli liste haric tutulur.
- Cift calis karisikligi bitti: yerel calis baslayinca gomulu durur (`play`), gomulu acilinca yerel duraklar; iki mini player ust uste gelmez.
- Tanilama raporu artik gercek surumu yazar (`PackageInfo`, sabit `5.0.1` kalkti).

## [5.10.4] - 2026-09-10

### Yuzdelik Ilerleme + Hizli Indirme Sonrasi Islem
- Indirme kartinda canli **% gosterge** (`download_components`): barin yaninda `%42` gibi yazar.
- Indirme sonrasi kapak + soz aramasi artik **paralel** kosuyor (once sirayla ~20sn+ suruyordu); gomuleme ayni kaldi. Toplam indirme suresi kisaldi.

## [5.10.3] - 2026-09-10

### Gomulu Calis Surekliligi + Indirme Seffafligi
- Geri donunce muzik susmuyor: `lib/services/embed_playback_service.dart:1` controller artik singleton yasiyor; `lib/widgets/mini_player.dart:24` gomulu parcayi baslik/sanatci + Durdur ile gosteriyor, dokununca ekrana donuyor. Yerel calis baslayinca gomulu otomatik durur (`player_provider`), gomulu acilinca yerel duraklar.
- Indirme neden takildigi gorunuyor: `explode_stream_service` gercek hatayi (`lastError`) donduruyor, `download_manager` onu mesaja yaziyor, `download_provider stateText` canli durumu gosteriyor. Bot duvari surerse mesajda sebebi yazar.
- Not: Hata 153 = klibin sahibi embed'i kapatmis, o parcada cozum dogrudan akis; dogrudan akis telefon aginda `androidSdkless` ile denenir.

## [5.10.2] - 2026-09-10

### Akis Duzeltmesi: androidSdkless + 25 Sonuc
- 5.9.0'da manifest icin `safari`+`androidVr`'yi acikca geciyorduk; ikisi de PO Token/bot duvarina takiliyor ve kutuphanenin otomatik `tv` yedegini devre disi birakiyordu. `lib/services/explode_stream_service.dart:1` artik istemci secimini kutuphaneye birakiyor (varsayilan `androidSdkless`: PO Token istemez, bos donerse `tv` dener).
- Arama sonucu 10 degil 25: `lib/services/multi_source_search.dart:82` `limitPerSource` 10→25 (API zaten ~20 donuyordu, biz kesiyorduk).

## [5.10.1] - 2026-09-10

### Build Hotfix — withSecurityScope iOS'ta Yok
- 5.10.0 CI'da patladi (`Build iOS Device`, Swift: `'withSecurityScope' is unavailable in iOS` x3). Bayrak macOS'e ozelmis; iOS'ta belge seciciden gelen bookmark zaten otomatik guvenlik kapsamli. `ios/Runner/WatchedFolderHandler.swift:106/130/139` bos secenige (`[]`/`.withoutUI`) cevildi, bookmark cozumu + `startAccessingSecurityScopedResource` aynen calisir.

## [5.10.0] - 2026-09-09

### Kopyasiz Izleme: Security-Scoped Bookmark
- Yeni `ios/Runner/WatchedFolderHandler.swift:19` (`com.melodi/watched_folders`): klasor secimi, bookmark saklama/cozme, silme/temizleme. `lib/services/watched_folder_bookmarks.dart:11` Dart koprusu + testleri. Dis klasorler kopyalanmadan yerinde izlenir.

## [5.9.0] - 2026-09-09

### JollyTone Motoru Komple Entegre: youtube_explode_dart
- `youtube_explode_dart: ^3.1.0` eklendi; yeni `lib/services/explode_stream_service.dart:1` JollyTone `yt_audio_stream`+`stream_client` karsiligi: cok istemcili manifest (`safari`+`androidVr` harman), kutuphane ici imza cozme, HLS destegi, iOS icin mp4/m4a tercihli en yuksek bitrate.
- Calma artik dosya indirmeyi beklemiyor: `lib/services/audio_handler.dart` `youtube://` dogrudan akis URL'i (`AudioSource.uri`) ile just_audio streaming — JollyTone hizi buradan gelir. `lib/services/sources/youtube_source.dart:86` ayni hatta gecti.
- Indirme gercek bayt pipe: `lib/services/download_manager.dart:482` `_downloadViaBundle` explode ile ilerlemeli (%20-75) + iptal destekli indiriyor; Arama (`YtMusicService`) aynen calisiyor.
- Olmazsa embed yedegi korunuyor (`search_result_tiles` -> `EmbedPlayerScreen`).

## [5.8.1] - 2026-09-09

### Tarama Sekmesi Kalkti + Izlenen Klasor Duzeltmesi + Kopyasiz Izleme
- Alt bar 4 sekmeye indi: Basla/Kesif/Kaydedilenler/Ayarlar (`lib/widgets/main_shell.dart:12`, Tarama kaldirildi; klasor izleme Ayarlar > Izlenen Klasorler'de).
- Silinemeyen klasor bug'i cozuldu: `lib/services/watched_folder_service.dart:53` `getWatchedFolders()` artik SADECE kullanici klasorlerini donuyor; sistem `Documents/Melodi` taramaya dahil ama listede yok. Ayarlar'da sistem satiri ayri ("her zaman izlenir · kopyasiz", silme yok), kullanici satirlarinda silme calisiyor.
- Temizle gercekten temizliyor: `clear/removeWatchedFolder` DB'deki kullanici klasorlerini siliyor + sistem disi yollardaki kayitlari kutuphaneden dusuruyor (dosyalar durur) + kutuphane yenileniyor; sistem izlemesi kapanmiyor.
- Kopyasiz izleme: `pickAndSaveWatchedFolder` + `music_scanner _copyIntoLibrary` artik Documents altindaki dosyalari kopyalamadan yerinde izliyor; sadece disaridaki (iCloud/temp) dosyalar `Melodi/Offline/Imported Files` gelen kutusuna kopyalaniyor. Cift kayit bitti.
- Embed oynatici duzeltmesi (5.8.0'dan sarkan): iOS satir-ici medya izni (`allowsInlineMediaPlayback`), nocookie embed, hata ekrani + Tekrar dene/YouTube'da ac butonlari.

## [5.8.0] - 2026-09-09

### JollyTone Birebir Kopya: Embed Yedek + Sekme Iskeleti
- `webview_flutter: ^4.7.0` eklendi (JollyTone IPA'daki `webview_flutter_wkwebview` ile ayni). `lib/services/embed_playback_service.dart:1` + `lib/screens/embed_player_screen.dart:1`: direkt InnerTube `LOGIN_REQUIRED` dondugunde `youtube.com/embed/VIDEO_ID` ile dinleme. `lib/widgets/search/search_result_tiles.dart:148` `_play` artik once direkt dener, olmazsa embed ekrana duser.
- Sekmeler JollyTone adlariyla: `lib/widgets/main_shell.dart:12` Basla/Kesif/Kaydedilenler/Tarama/Ayarlar (basla_ekran/main_screen, kesif_ekran/search_screen, kaydedilenler_ekran/saved_screen, tarama_ekran/browse_screen, ayarlar_ekran/settings_screen karsiligi).
- Canli prob: `music.youtube.com` arama 200 OK; `youtubei/v1/player` 6 varyantta da LOGIN_REQUIRED (bu agdan). Cobalt/yt1d/Piped/Invidious public olu. Embed her agda acar.

## [5.7.3] - 2026-09-09

### Arama Gosterim + Indirme Kuyrugu + Offline Kopyalama
- `lib/screens/search_screen.dart:20` `_controller` listener eklendi: yazarken parent rebuild olmadigi icin `if (_hasQuery)` hep false kaliyor, sonuclar hic gosterilmiyordu. Artik arama sonuclari ekrana geliyor.
- `lib/services/download_manager.dart:225` erken-return kaldirildi: `directUrl==null` iken `sourceVideoId` varken bile `Eslesen sarki bulunamadi` verip cikiyordu. Artik videoId varsa bundle indiriyor; InnerTube LOGIN_REQUIRED ise acik hata yaziyor.
- `lib/services/music_scanner_service.dart:191` LA parity: `importFromPaths` artik dosyalari `Documents/Melodi/Offline/Imported Files` altina kopyaliyor (temp/Inbox silinmesi sorunu bitti).
- Not: canli testte `music.youtube.com` arama 200 + sonuc var, ama `www.youtube.com/youtubei/v1/player` tum istemcilerde LOGIN_REQUIRED (bot korumasi). Cobalt/yt1d/Piped/Invidious public hepsi olu (403/502/api=False). O yuzden YouTube cal/indirme su an acik hata verir; arama + offline tam calisir.

## [5.7.2] - 2026-09-08

### Sideload Crash Hotfix — SideStore Ana Ekrana Atma
- **Crash sebebi**: `ios/Runner/Info.plist:108` `CPTemplateApplicationScene` + `Runner.entitlements:13` `com.apple.developer.carplay-audio` + `CarPlaySceneDelegate.swift` eklentisi ücretsiz Apple ID ile SideStore imzasında **entitlement hatası** verip anında kill ediyordu (LA_Player gibi CarPlay sadece ücretli + CarPlay onaylı hesabda çalışır). **Kaldırıldı**: scene manifest, entitlement ve `project.pbxproj` kaydı silindi, `lib/services/carplay_service.dart:4` stub `MPNowPlaying` korundu — sideload artık açılır.
- Arama hotfix korunuyor.

## [5.7.1] - 2026-09-08

### Arama Hotfix — Hiç Sonuç Gelmeme Düzeltmesi
- **Özür**: 5.3.0–5.7.0’da `lib/services/ytmusic_service.dart:171` `_performSearch` sadece `EgWKAQIIAQ==` filtreyle atıyor ve boş dönünce fallback yoktu, ayrıca `videoId` 11-char kontrolü + dar `fixedColumns` süresi parse’i bazı `musicResponsiveListItemRenderer`’ları eliyordu — bu yüzden `Search Tracks` boş kalıyordu. **Düzeltme**: filtre boşsa `null` params ile retry (`searchAllSync` fallback), `videoId` için recursive `_findVideoIdRecursive` (ilk `watchEndpoint.videoId` 11-char), süre için tüm `flexColumns` taraması, extensive `debugPrint('YtMusic search "q" -> n results')`. Canlı Python test `adele hello` 20 renderer hala geçer.
- Önceki LA_Player batch/CarPlay korunuyor.

## [5.7.0] - 2026-09-08

### LA_Player Batch + CarPlay Birebir
- **Batch Artwork (`lib/screens/batch_artwork_screen.dart:1`)**: `Batch search and apply artwork` %d/%d ilerleme, `Auto-Download Artwork` switch, `Searching artwork %d/%d` + `Tap an artwork to apply`, seçili kapakları `ArtworkEmbeddingService.embedCoverArt` + `DatabaseService.updateTrackAlbumArt` ile gömer, `lib/screens/library_screen.dart:336` seçim çubuğuna `Kapak ara` butonu eklendi.
- **Toplu Metadata (`lib/screens/batch_metadata_editor_screen.dart:1`)**: Title/Artist/Album checkbox’lı toplu editör, LA hatası `Cannot apply same Title and Artist to multiple selected files.` korunuyor, `lib/services/database_service.dart:updateTrackMetadata` ile uygular, seçim çubuğuna `Metadata düzenle` eklendi.
- **CarPlay (`ios/Runner/CarPlaySceneDelegate.swift:1` + `Info.plist:111` + `Runner.entitlements:11` + `project.pbxproj:14`)**: LA_Player `CPTemplateApplicationScene`/`CarPlaySceneDelegate` birebir, `com.apple.developer.carplay-audio` entitlement, `MPNowPlayingInfoCenter`/`MPRemoteCommandCenter` ile Oynat/Duraklat/Sonraki, sideload’da `carplay.no-playlists` mesajı yok.

## [5.6.0] - 2026-09-08

### LA_Player FilesTab Birebir Aktarım
- **Files tab eklendi (`lib/screens/files_screen.dart:1` + `lib/widgets/main_shell.dart:12`)**: LA_Player `FilesTab` gibi `Documents/Imported Files` klasörü garanti oluşturma, `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` ile Files entegrasyonu, **pull-to-refresh** → `LibraryProvider.scanMusic()` + `WatchedFolderService` yenile, **Import Files** (`file_picker` `importFromFiles`) / **Import Folder** (`getDirectoryPath` `importFromDirectory`) butonları AppBar’da, liste `Directory.listSync` ile klasör→dosya sıralı, `LA_Player.Files.txt` hinti (“Please do not delete the Imported Files folder…”) alt bantta, dosya tap → `PlayerProvider.playSong` (geçici `SongModel` `fileSize` ile), long-press → çal/listeye ekle/sil sheet, `lib/widgets/main_shell.dart:21` 4→5 tab (`home/files/library/search/settings`).
- Önceki temeller korunuyor: `watched_folder_service` 5 sn poll, `sleep_timer`, `lyrics`/`artwork`, `sort`, `queue/shuffle/repeat`, `playbackSpeed` hepsi zaten vardı (doğrulandı `flutter test 22 pass`).

## [5.5.0] - 2026-09-08

### Navidrome Tam Temizlik + Arama Düzeltmesi
- **Navidrome/Subsonic repodan tamamen silindi**: `lib/services/navidrome_service.dart`, `lib/screens/navidrome_settings_screen.dart`, `lib/services/sources/navidrome_source.dart`, `lib/services/remote_playlist_service.dart` silindi; `lib/services/music_source.dart:3` `MusicSourceType` sadece `youtube`, `lib/models/source_descriptor.dart:1` `SourceKind` sadece `local`/`youtube`; `README.md:27`/`ios/Runner/Info.plist:93`/`docs/app-store/*` güncellendi; `lib/widgets/home/home_header.dart:6` hub butonu, `lib/widgets/home/home_states.dart:101` “Hesap bağla”, `lib/screens/library_screen.dart:92` sunucu bağla kaldırıldı, boş metinler YouTube+yereLe göre düzeltildi.
- **5.3.0 arama boş dönme düzeltmesi**: JS bundle `customSearch` quickjs köprüsü iOS’ta sessizce boş dönüyordu; `lib/services/ytmusic_service.dart:1` native Dart InnerTube ile `music.youtube.com/youtubei/v1/search` (WEB_REMIX `1.20240801.01.00` + `EgWKAQIIAQ==` tracks param) canlı test edildi (`adele hello` → 20 renderer, ilk `Ei8UnOPJX7w` Hello/Adele/4:56 doğru parse), `lib/services/multi_source_search.dart:7` ve `lib/providers/search_provider.dart` tek kaynak YouTube ile uyumlu.
- Önceki B portu korunuyor: `flutter_js`/`archive`/`sflx` yok, `flutter analyze 0 error`/`flutter test 23 pass`.

## [5.4.0] - 2026-09-08

### Native YouTube (B): JollyTone Eşdeğeri Dart Portu
- **JS bundle/quickjs kaldırıldı**: `lib/services/ytmusic_bundle.dart` + `assets/extensions/ytmusic-spotiflac.sflx` + `flutter_js ^0.8.2` + `archive ^3.6.1` silindi, yerine `lib/services/ytmusic_service.dart:1` native Dart InnerTube servisi eklendi — JollyTone `App.framework/App`’taki `YTMusicServices`/`yt_audio_stream` hattıyla aynı endpoint’ler: `music.youtube.com/youtubei/v1/search` (WEB_REMIX `1.20240801.01.00`) ve `www.youtube.com/youtubei/v1/player` (4 istemci: `ANDROID_VR`/`MWEB`/`ANDROID`/`IOS`, key’ler `AIzaSyA8ei...`/`AIzaSyB-63v...`).
- Arama `performSearchSync` → `parseSearchResponseExtended` → `parseItemExtended` zinciri Dart’a portlandı (`collectItemsFromNode` derinlik 20/cap 5000, `musicResponsiveListItemRenderer`/`musicTwoRowItemRenderer` ayrıştırma, `flexColumns`/`lengthText`/`thumbnailOverlays`/`fixedColumns` süre & kapak çıkarımı, `stripUrlLikeFields`/`sanitizeTrack` eşdeğeri).
- İndirme `requestInnerTubeAudioDownload` → `_tryInnerTubeClient` (4 istemci sırayla, `visitorData`/`playerUrl` `watch?v` sayfasından, `X-YouTube-Client-Name/Version`/`X-Goog-Visitor-Id` header’ları, `signatureCipher` decode, `chooseYouTubeFormat` itag tercihi `140/141/139/251/250/249/171`) → `_downloadAudioUrl` doğrudan `googlevideo`’ya Range/stream yazma; `yt1d`/`cobalt` fallback’i gerekmediği için çıkarıldı.
- Arayüz sabit: `lib/services/sources/youtube_source.dart:1` + `lib/services/download_manager.dart:483` + `lib/services/audio_handler.dart:523` artık `YtMusicService` kullanır, `MultiSourceSearch` tek kaynak YouTube olarak korunur, yerel `Documents/Melodi/Offline` + Files + `WatchedFolderService` aynen durur.
- `flutter analyze 0 error` (71 info/warn), `flutter test 23 pass` (önceki `quickjs_c_bridge.dll 126` hatası kalktı), IPA ~1.5 MB küçüldü.

## [5.3.0] - 2026-09-08

### Sunucusuz Tek Yapı: YouTube (Gömülü) + Yerel
- İstek üzerine **Navidrome/Subsonic sunucu girişi tamamen kaldırıldı** — Ayarlar’daki “Sunucu” bölümü, arama çubuğundaki sunucu ikonu ve indirme için sunucu kontrolü gitti.
- Çevrimiçi **tek yapı artık sadece gömülü YouTube** (`assets/extensions/ytmusic-spotiflac.sflx` quickjs, `lib/services/ytmusic_bundle.dart`, `lib/services/sources/youtube_source.dart`). Arama `YouTube` + yerel; `lib/services/multi_source_search.dart` sadece `YouTubeSource`.
- Çalma: `youtube://` ve `online://` artık yine YouTube paketi üzerinden dosya indirilerek çalar (`lib/services/audio_handler.dart`), eski `youtube://` kayıtları destekleniyor.
- İndirme: `lib/services/download_manager.dart` `isNavidrome` dalı kaldırıldı, `YtMusicBundle.downloadToFile` hattıyla doğrudan `Documents/Melodi/Offline`’a gider.
- Yerel çalma LocalAudioPlayer detaylarında: `Documents` izleme, artwork/lyrics embedding, Files entegrasyonu korunur.

## [5.2.0] - 2026-09-08

### Gömülü YouTube + Navidrome
- Arama artık iki kaynak üzerinden harmanlanır: gömülü `assets/extensions/ytmusic-spotiflac.sflx` (SpotiFLAC paketi, sunucu/hesap gerekmez) + bağlı Navidrome sunucusu.
- `lib/services/sources/youtube_source.dart` yeni: paketin `customSearch` sözleşmesiyle YouTube’ta arama, süre eşleştirme ve görsel ile `MusicSourceType.youtube` olarak sunar.
- `lib/services/ytmusic_bundle.dart` YouTube paketini asset’ten quickjs’de çalıştırır: `registerExtension` shim, `file.download` gerçekten dosya indirir, eşzamanlı `fetch` köprüsü, `customSearch` saniye↔milisaniye dönüşümü düzeltildi.
- `lib/services/multi_source_search.dart` + `lib/providers/search_provider.dart` YouTube çözümlemesi artık dosyayı indirerek çözer (3 dk timeout), ara sonuçlardaki yanlış süreler düzeltilir.
- `lib/services/download_manager.dart` YouTube indirmeleri `YtMusicBundle.downloadToFile` hattıyla doğrudan indirme dizinine gider, yerel dosya geldiyse ağ indirmesi atlanır.
- Arayüz: Arama filtreleri `Tümü / YouTube / Sunucum` olarak sadeleşti.
- CarPlay/entitlement/metadata önizleme küçük iyileştirmeleri.

## [5.1.0] - 2026-09-08

### Tek Yapı: Navidrome + Yerel Kütüphane
- App Store uyumu için tek çevrimiçi yapıya inildi: kişisel Navidrome/Subsonic sunucusu + yerel dosyalar. YouTube, Piped, yt-dlp, JioSaavn, Deezer, SoundCloud, Apple Music, Hi-Fi köprüsü ve eklenti sistemi (JS sandbox dahil) kaldırıldı.
- Arama, çalma, indirme ve çalma listesi içe aktarma (M3U/CUE + metin) artık yalnızca Navidrome üzerinden çalışır; indirme adresleri her denemede taze Subsonic imzasıyla üretilir.
- Eski `youtube://` kayıtları açılmaya çalışıldığında anlaşılır hata verir, veri silinmez.
- Kullanılmayan 14 bağımlılık ve ~12.300 satır kod temizlendi (`flutter analyze` 0 error, 23 test yeşil).

## [5.0.8] - 2026-09-08

### Tanılama Günlüğünden Gelen Düzeltmeler
- `lib/services/audio_handler.dart:130` — süre akışı ilk medya öğesinden önce geldiğinde `!` çökmesi giderildi (günlükte 3 kez tekrarlıyordu).
- `lib/providers/search_provider.dart:95` — eklenti parçalarında 4.8 sn zaman aşımı 3 dk'ya çıkarıldı; SpotiFLAC hattı dosyayı indirerek çözdüğü için kısa zaman aşımı sonucu hep boş dönüyordu.
- Not: `na.mesk.skill.music.a2z.com` hataları kurulu üçüncü parti bir eklentinin ölü adresine ait, uygulama kodunda karşılığı yok.

## [5.0.7] - 2026-09-07

### -1003 Düzeltmesi (ölü sunucu adları)
- Sorun: oynatma "erişilebilen kaynaklar denendi -1003" ile düşüyordu; DNS'te olmayan ölü tünel adresine istek atılıyordu (doğrulandı: NXDOMAIN).
- `lib/services/js_extension_service.dart` — paketin `fetch` çağrıları eşzamanlı köprüye alındı (Cobalt/yt1d senkron akışı çalışır; `.then` zinciri pakette yok, tek `await` uyumlu).
- `lib/services/backend_api_service.dart` — yedek uç nokta artık DNS'i çözülmeyen adresi eleyor.
- `lib/services/sources/hifi_source.dart` — ölü baza 30 sn/5 dk gömülmeden hızlı eleniyor (2 dk önbellekli erişilebilirlik).

## [5.0.6] - 2026-09-07

### iOS Build Düzeltmesi (Swift)
- `ios/Runner/MelodiHLS/HLSDownloader.swift:136` — tanımsız `loadedTimeRangesLoaded` → `loadedTimeRanges` (derleyici hatası).
- `ios/Runner/MelodiHLS/HLSDownloader.swift:196` — `AVAssetDownloadURLSession`'da olmayan `.session` kaldırıldı, doğrudan `getTasksWithCompletionHandler` çağrısı.
- `ios/Runner.xcodeproj/project.pbxproj` — `HLSDownloader.swift` Runner hedefine eklendi (`AppDelegate.swift:63` "in scope" hatası giderildi).

## [5.0.5] - 2026-09-07

### SpotiFLAC Eklentileri Kalıcı Çözüm
- `lib/services/js_extension_service.dart` — `registerExtension` shim eklendi (paketler artık yükleniyor + `initialize` çağrılıyor); `file.download/exists/delete` gerçekten dosya indirir (başlık + Range resume destekli, izin listesine uygun); yeni `downloadExtensionFile()` eklentinin kendi indirme hattını (InnerTube/Cobalt/yt1d) çalıştırır.
- `lib/services/multi_source_search.dart` — eklenti parçası önce kendi eklentisine sorulur, `youtube://` kısayolu eklentiyi baypas etmez; önbellek taraması eklenti parçalarını atlar.
- `lib/services/download_manager.dart` — eklentinin indirdiği yerel dosya doğrudan kütüphaneye alınır.
- `test/extension_js_contract_test.dart` — paket sözleşmesi testleri (4 test).

## [5.0.4] - 2026-09-07

### Çevrimiçi Çalma + İndirme Düzeltmeleri
- `lib/services/robust_piped_service.dart:81` — health kontrolü `/health` 404'ünü ölü saymıyordu düzeltildi: 5xx altı her yanıt "ulaşılabilir" sayılır; `robust_piped_service.dart:238` liste boş kalırsa tüm instance'lar denenir (kalıcı körlük giderildi).
- `lib/services/sources/extension_source.dart:198` — ölü backend baz adresi (`trycloudflare` tüneli gibi) artık önceden elenir, global fallback'e düşülür; 404 veren sağlam backend'ler korunur.
- `lib/services/download_manager.dart:25,458,691` — bayat direkt URL (süresi dolmuş googlevideo) başarısızlıkta temizlenir, retry taze arama yapar; HTTP durum kodu loglanır.
- Not: `youtube_explode_dart` 3.1.0 manifest çıkaramıyor (upstream, pub.dev'de yeni sürüm yok); YouTube akışı Piped/backend eklentisine bağlı. JioSaavn yolu canlı doğrulandı.

## [5.0.1] - 2026-09-05

### Uygulama İçi Cloudflare Doğrulaması
- Hi-Fi API isteği Cloudflare challenge döndürdüğünde kullanıcıya uygulama içi doğrulama penceresi açılır.
- Doğrulama tamamlanınca WebView çerezleri API oturumuna aktarılır, pencere otomatik kapanır ve bekleyen istek yeniden denenir.
- Eşzamanlı doğrulama pencereleri tekilleştirildi; WebView ve API istemcisi aynı User-Agent ile çalışır.

## [4.12.2] - 2026-08-31

### Fix Build — Büyük Ayarlar Birleştirmesi Geri Alındı
- `lib/screens/settings_screen.dart:1` 6108 satırlık hatalı birleştirme (`SyncProvider`/`SpotifyProvider`/`YTMusicProvider` eksik) geri alındı — 681 satırlık stabil sürüme dönüldü, `flutter analyze` 0 error, `iOS Build` tekrar yeşil
- `lib/services/audio_handler.dart`/`now_playing`/`diagnostics` vb. aynı birleştirmedeki hatalı değişiklikler geri alındı
- Sürüm `4.12.1+27` → `4.12.2+28`
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.12.1] - 2026-08-31

### Her Eklenti Ayrı Kaynak + İndirme Per-Eklenti
- `lib/services/music_source.dart:17` `OnlineTrack` artık `extensionId`/`extensionName` taşır, `sourceLabel` eklenti adını gösterir
- `lib/services/sources/extension_source.dart:1` yeni `ExtensionMusicSource` — SpotiFLAC `.sflx` için `JsExtensionService` (A), 8spine `jiosaavn`/`soundcloud` için native Dart (B), diğerleri bridge; `id`/`bundleUrl` korunur (`homepage` → orijinal `.sflx` URL)
- `lib/services/multi_source_search.dart:30` `_extensionSources` + `_allSourcesForSearch` — arama artık kurulu her eklentiyi ayrı kaynak olarak sorgular, `getStreamUrl` extensionId’ye göre doğru kaynağa yönlenir, fallback’e eklentiler dahil
- `lib/widgets/search/search_result_tiles.dart:198` indirme sheet artık `_DownloadSelection` (`choice` + `extensionId`/`extensionName`) ile her `hifi` eklentisini ayrı satır (`Hi-Fi · <eklenti>`) gösterir, ` _getStreamForSpecificSource` extension-specific search yapar
- `lib/screens/search_screen.dart:1` arama filtreleri ileride eklenti bazlı chip’lere genişletilebilir (şu an `Tümü / YouTube / Hi-Fi / Deezer` altında toplanır, indirme’de ayrı)

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
