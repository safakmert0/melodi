# Melodi — App Store Checklist

## 1) Apple Developer & Bundle
- [ ] Apple Developer Program üyeliği aktif (99$/yıl)
- [ ] Bundle ID `com.melodi.app` App Store Connect'te oluşturuldu
- [ ] App Groups `group.com.melodi.app` capability'i App ID + provisioning profile'de açık
- [ ] Icon: `ios/Runner/Assets.xcassets/AppIcon.appiconset` 1024x1024, alpha yok, sRGB

## 2) Kod (B-Hybrid)
- [x] `lib/core/app_config.dart` → `APP_STORE` dart-define gate'i
- [x] `Info.plist` → geçersiz `NS*FolderUsageDescription` ve `NSMicrophone` kaldırıldı, açıklamalar düzeltildi (`melodi/ios/Runner/Info.plist:88`)
- [x] `PrivacyInfo.xcprivacy` → `NSPrivacyAccessedAPITypes` (FileTimestamp, UserDefaults, DiskSpace) ve `NSPrivacyTracking=false` mevcut
- [x] YouTube / yt-dlp doğrudan çağrıları eklentisiz bloklandı (`yt_dlp_service`, `youtube_downloader`, `piped_service`, `robust_piped_service`, `hls_downloader_service`, `multi_source_search`)
- [x] `SourceCatalog` ve `ExtensionService` App Store modunda YouTube'u varsayılan gizliyor, resmi repo otomatik eklenmiyor
- [ ] `flutter analyze` → temiz (153 warning/info, 0 error) ✅
- [ ] `flutter test` → geçiyor

## 3) Build & Signing (Codemagic)
Codemagic'te iki workflow var (`melodi/codemagic.yaml:1`):

| Workflow | Amaç | Build komutu |
|---|---|---|
| `melodi-ios` | Sideload / AltStore (unsigned) | `flutter build ios --no-codesign` |
| `melodi-ios-app-store` | App Store (signed, clean) | `flutter build ipa --dart-define=APP_STORE=true --dart-define=DISABLE_YTDLP_DIRECT=true --export-options-plist=ios/ExportOptions.plist` |

### Codemagic env grubu: `appstore_credentials`
- `APP_STORE_CONNECT_API_KEY` (p8 içeriği)
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APPLE_TEAM_ID` (ExportOptions için)

### Manuel tetikleme
Codemagic > Workflows > `Melodi iOS (App Store - Signed)` > Start

Alternatif yerel:
```bash
flutter build ipa --release \
  --dart-define=APP_STORE=true \
  --dart-define=DISABLE_YTDLP_DIRECT=true \
  --export-options-plist=ios/ExportOptions.plist
# ardından Xcode Organizer > Validate App
```

## 4) App Store Connect Metadata
- [ ] App Name: **Melodi** (kontrol: başka uygulama ile çakışmıyor mu?)
- [ ] Subtitle: "Local Music Player for iOS"
- [ ] Category: Music
- [ ] Privacy Policy URL (zorunlu)
- [ ] Description (4000 char):
> Melodi, yerel müzik koleksiyonunuz ve kendi Navidrome/Subsonic sunucunuz için premium, temiz ve hızlı bir çalardır. Files'tan içe aktarın, kitaplığınızı tarayın, kayıpsız dinleyin, çevrimdışı indirin. App Store sürümü YouTube indirme içermez; topluluk eklentileriyle genişletilebilir.
- [ ] Keywords: music player, flac, navidrome, subsonic, offline, local music
- [ ] Support URL, Marketing URL
- [ ] Age Rating: 4+ (müzik)
- [ ] Screenshots:
  - 6.7" (1290x2796) – zorunlu
  - 6.5" (1284x2778) – zorunlu
  - 12.9" iPad (2048x2732) – opsiyonel ama önerilir
- [ ] App Preview video (opsiyonel)
- [ ] Review notes: `docs/app-store/REVIEW_NOTES.md` içeriğini yapıştır
- [ ] Encryption: `ITSAppUsesNonExemptEncryption = NO`

## 5) TestFlight
- [ ] Workflow `submit_to_testflight: true` → TestFlight Beta grubuna otomatik yüklenir
- [ ] Internal test: en az 1 build "Ready to Submit"
- [ ] External beta (opsiyonel)

## 6) Submission Sonrası
- [ ] Phased Release açık
- [ ] App Privacy > Data Types beyanı PrivacyInfo ile uyumlu
- [ ] 1.1.0'dan sonra sideload kullanıcılarını App Store'a yönlendirmek için migration notu

## 7) Sideload'da Full Premium'u Korumak
- Sideload IPA (`melodi-ios` workflow) hiçbir gate içermez → `APP_STORE=false` varsayılan → tüm YouTube/Piped/yt-dlp yolları açık kalır.
- App Store kullanıcıları `Eklenti Mağazası > Depo ekle` ile premiumu geri kazanır (manuel repo eklenmeli).

