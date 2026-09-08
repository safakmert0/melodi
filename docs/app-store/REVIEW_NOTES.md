# Melodi — App Store Review Notes (Sunucusuz)

Bu dosya App Store Connect > "App Review Information > Notes" alanına kopyalanmak için hazırlandı.

---

## 1. Uygulama nedir?

Melodi, iOS için **yerel + YouTube müzik çalar**dır (sunucusuz, hesapsız):

- **Bu aygıt** — Files uygulamasından içe aktarılan veya cihazda zaten var olan ses dosyaları (MP3, FLAC, M4A, WAV vb.) + `Documents/Melodi/Offline` izlenen klasör
- **YouTube** — Native Dart InnerTube (`music.youtube.com/youtubei/v1/search` + `www.youtube.com/youtubei/v1/player`, 4 istemci `ANDROID_VR/MWEB/ANDROID/IOS`) ile arama ve `googlevideo.com` direkt akış/indirme; sunucu/hesap gerekmez.

Navidrome/Subsonic desteği **tamamen kaldırıldı** (5.5.0).

## 2. YouTube bağımlılığı neden var?

`youtube` kategorisi native Dart `YtMusicService` ile InnerTube üzerinden çalışır. Uygulama YouTube web sitesini embed etmez; yalnızca halka açık InnerTube arama/player endpoint’lerini kullanır.

## 3. İzin açıklamaları

- `NSAppleMusicUsageDescription` → Apple Music kitaplığını tarar (isteğe bağlı import)
- `NSPhotoLibraryUsageDescription` → Çalma listesi kapak fotoğrafı seçmek için
- `NSLocalNetworkUsageDescription` → AirPlay cihazlarını keşfetmek için
- `UIBackgroundModes: audio` → Kilitle ekranında çalma
- `UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace` → Files'tan müzik içe aktarma
- `NSAppTransportSecurity.allowsArbitraryLoads = true` → `googlevideo.com`/`i.ytimg.com`/`music.youtube.com` için

## 4. Test hesabı

- Review için hesap gerekmez; yerel dosyalarla test edilebilir: Files > Melodi klasörüne bir `.mp3` bırakın → Kitaplık > Taramayı başlat.
- Çevrimiçi: Ara > herhangi bir YouTube sonucu → Oynat/İndir.

## 5. Uygulama içi satın alma yok

Bağış/Tip için `in_app_purchase` entegrasyonu mevcuttur ancak bu sürümde aktif değildir (StoreKit yapılandırılmadı).

## 6. Şifreleme

`ITSAppUsesNonExemptEncryption = false` — uygulama yalnızca HTTPS ve sistem şifrelemesini kullanır.
