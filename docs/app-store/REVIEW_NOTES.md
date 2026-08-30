# Melodi — App Store Review Notes (B-Hybrid)

Bu dosya App Store Connect > "App Review Information > Notes" alanına kopyalanmak için hazırlandı.

---

## 1. Uygulama nedir?

Melodi, iOS için **yerel ve kişisel müzik çalar**dır. Varsayılan App Store sürümü yalnızca şu kaynakları kullanır:

- **Bu aygıt** — Files uygulamasından içe aktarılan veya cihazda zaten var olan ses dosyaları (MP3, FLAC, M4A, WAV vb.)
- **Navidrome / Subsonic** — Kullanıcının kendi sunucusu (self-hosted). HTTPS üzerinden kayıpsız akış ve çevrimdışı indirme.
- **Deezer / Apple Music** — Sadece 30 sn önizleme ve metadatası (keşif amaçlı).

YouTube, JioSaavn gibi üçüncü taraf kaynaklar **App Store sürümünde varsayılan olarak kapalıdır**. Kullanıcı isterse **Eklenti Mağazası > Depo ekle** ile topluluk tarafından barındırılan bir `registry.json` ekleyip, o topluluk eklentisinin sağladığı `ytdlpBackend` Sunucusunu kurabilir. Bu eklentiler Melodi tarafından barındırılmaz, derlenmez veya varsayılan olarak sunulmaz.

## 2. Neden `youtube_explode_dart` bağımlılığı var?

`youtube_explode_dart` kütüphanesi binary'de mevcuttur ancak **App Store build'inde** (`--dart-define=APP_STORE=true --dart-define=DISABLE_YTDLP_DIRECT=true`) doğrudan çağrıları engellenmiştir:

- `lib/core/app_config.dart` → `kAppStoreMode` flag'i
- `lib/services/yt_dlp_service.dart: _isDirectAllowed()` → eklenti yoksa `null` döner
- `lib/services/youtube_downloader.dart: _allowDirect()` → Piped / yt-dlp fallback'leri engellenir
- `lib/services/piped_service.dart` / `robust_piped_service.dart` / `hls_downloader_service.dart` / `multi_source_search.dart` aynı gate'e sahiptir
- `lib/services/source_catalog.dart` → YouTube / JioSaavn `SourceCard`'ları App Store sürümünde yalnızca kurulu `backend` eklentisi varsa gösterilir
- `lib/services/extension_service.dart` → App Store sürümünde varsayılan `melodi-extensions` reposu **otomatik eklenmez** (kullanıcı manuel eklemeli)

Dolayısıyla review sırasında (temiz kurulum + eklenti yok) YouTube içeriğine erişim yeteneği **yoktur**.

## 3. Eklenti sistemi nasıl çalışır?

- Kullanıcı: Ayarlar > Eklenti Mağazası > "Depo ekle" → `https://.../registry.json`
- Manifest (`extension.json`) indirilir, `isUrlAllowed` ile doğrulanır, Sağlık kontrolü (`HEAD`/`GET`) yapılır.
- Yalnızca `baseUrl` üzerindeki API (`/api/search`, `/api/stream/{id}`, `/api/download`) çağrılır. Melodi kendi sunucusu barındırmaz.
- Tüm eklenti trafiği kullanıcının kendi sağladığı veya topluluğun sağladığı sunucuya gider.

Bu model SpotiFLAC / Evermusic tarzı merkeziyetsiz eklenti deposu ile aynıdır ve Guideline 4.7 (HTML5 Games, Bots etc) ve 5.2.2 dışına düşer çünkü yürütülür kod içermez, sadece ağ kaynağı ekler.

## 4. İzin açıklamaları

- `NSAppleMusicUsageDescription` → Apple Music kitaplığını tarar (isteğe bağlı import)
- `NSPhotoLibraryUsageDescription` → Çalma listesi kapak fotoğrafı seçmek için
- `NSLocalNetworkUsageDescription` → Kullanıcının yerel ağındaki Navidrome sunucusuna ve AirPlay cihazlarına erişmek için
- `UIBackgroundModes: audio` → Kilitle ekranında çalma
- `UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace` → Files'tan müzik içe aktarma
- `NSAppTransportSecurity.allowsArbitraryLoads = true` → Kullanıcı kendi `http://192.168.x.x` Navidrome adresini girebilir (self-signed / yerel IP). Üretimde https teşvik edilir.

## 5. Test hesabı

- Review için Navidrome gerekmez; yerel dosyalarla test edilebilir: Files > Melodi klasörüne bir `.mp3` bırakın → Kitaplık > Taramayı başlat.
- Demo Navidrome (isteğe bağlı): `https://demo.navidrome.org` (user: demo / pass: demo) — yalnızca test amaçlıdır, gerekirse "personal server" olarak eklenebilir.

## 6. Uygulama içi satın alma yok

Bağış/Tip için `in_app_purchase` entegrasyonu mevcuttur ancak bu sürümde aktif değildir (StoreKit yapılandırılmadı). Review sırasında satın alma akışı gösterilmez.

## 7. Şifreleme

`ITSAppUsesNonExemptEncryption = false` — uygulama yalnızca HTTPS ve sistem şifrelemesini kullanır.

---

*Build flag: `flutter build ipa --dart-define=APP_STORE=true --dart-define=DISABLE_YTDLP_DIRECT=true`*
*TestFlight grubu: Melodi Beta*
