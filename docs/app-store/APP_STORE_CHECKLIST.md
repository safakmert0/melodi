# Melodi — App Store Checklist

## 1) Apple Developer & Bundle
- [ ] Apple Developer Program üyeliği aktif (99$/yıl)
- [ ] Bundle ID `com.melodi.app` App Store Connect'te oluşturuldu
- [ ] App Groups `group.com.melodi.app` capability'i App ID + provisioning profile'de açık
- [ ] Icon: `ios/Runner/Assets.xcassets/AppIcon.appiconset` 1024x1024, alpha yok, sRGB

## 2) Kod (Sunucusuz)
- [x] `Info.plist` → geçersiz `NS*FolderUsageDescription` ve `NSMicrophone` kaldırıldı, `NSLocalNetworkUsageDescription` AirPlay için sadeleştirildi
- [x] `PrivacyInfo.xcprivacy` → `NSPrivacyAccessedAPITypes` ve `NSPrivacyTracking=false` mevcut
- [x] Navidrome/Subsonic tamamen kaldırıldı (5.5.0), YouTube native Dart InnerTube (`lib/services/ytmusic_service.dart:1`) tek çevrimiçi kaynak, Files/Offline yerel korunuyor
- [ ] `flutter analyze` → temiz (71 info/warn, 0 error) ✅
- [ ] `flutter test` → geçiyor (23 pass)

## 3) Build & Signing (Codemagic)
Codemagic'te iki workflow var (`melodi/codemagic.yaml:1`):

| Workflow | Amaç | Build komutu |
|---|---|---|
| `melodi-ios` | Sideload / AltStore (unsigned) | `flutter build ios --no-codesign` |
| `melodi-ios-app-store` | App Store (signed) | `flutter build ipa --export-options-plist=ios/ExportOptions.plist` |

Codemagic > Workflows > ilgili workflow > Start

## 4) App Store Connect Metadata
- [ ] App Name: **Melodi** (kontrol: başka uygulama ile çakışmıyor mu?)
- [ ] Subtitle: "Local Music Player for iOS"
- [ ] Category: Music
- [ ] Privacy Policy URL (zorunlu)
- [ ] Description (4000 char):
> Melodi, yerel müzik + YouTube için premium, temiz ve hızlı bir çalardır. Files'tan içe aktarın, YouTube'tan arayıp indirin, kayıpsız dinleyin, çevrimdışı çalın. Sunucu/hesap gerekmez.
- [ ] Keywords: music player, flac, youtube, offline, local music
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

## 7) Sideload / App Store aynı binary
- Tek yapı: YouTube native + yerel. Sideload ve App Store aynı IPA.

