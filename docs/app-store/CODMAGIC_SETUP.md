# Codemagic → App Store Connect

Bu proje Codemagic'i iki ayrı IPA için kullanır.

## Workflow'lar (`melodi/codemagic.yaml`)

### 1) `melodi-ios` — Sideload (unsigned)
- `flutter build ios --release --no-codesign`
- Çıktı: `build/Melodi-unsigned.ipa`
- GitHub Actions `ios-build-release.yml` aynı işi yapar (tag push ile Release)

### 2) `melodi-ios-app-store` — App Store (signed, clean)
- `flutter build ipa --dart-define=APP_STORE=true --dart-define=DISABLE_YTDLP_DIRECT=true --export-options-plist=ios/ExportOptions.plist`
- `app-store-connect fetch-signing-files --type IOS_APP_STORE --create`
- `app-store-connect publish --path build/ios/ipa/*.ipa` → TestFlight

## Hazırlık (bir kere)

### Apple tarafı
1. https://developer.apple.com > Certificates > App Store Connect API Key oluştur (Admin).
   - Key ID, Issuer ID, p8 dosyasını indir (1 kere indirilir).
2. App Store Connect > My Apps > New App
   - Platform: iOS, Bundle ID: `com.melodi.app`, SKU: `melodi-ios`, dil: Türkçe

### Codemagic tarafı
Codemagic > Teams > Your Team > Environment variables > Add group `appstore_credentials`:
- `APP_STORE_CONNECT_API_KEY` → p8 dosyasının tamamı (-----BEGIN PRIVATE KEY----- …)
- `APP_STORE_CONNECT_KEY_IDENTIFIER` → Key ID
- `APP_STORE_CONNECT_ISSUER_ID` → Issuer ID

Ayrıca genel değişkenler (`codemagic.yaml` içinde `vars`):
- `APP_ID = com.melodi.app`
- `APPLE_TEAM_ID` (gerekiyorsa `ios/ExportOptions.plist:8` içine elle yaz veya Codemagic'in otomatik oluşturduğu ExportOptions'u kullan)

### `ios/ExportOptions.plist`

Mevcut dosya minimaldir:
```xml
<key>method</key><string>app-store</string>
<key>teamID</key><string>YOUR_TEAM_ID</string>
```
Codemagic'in `fetch-signing-files` + `xcode-project use-profiles` adımları ExportOptions'u otomatik tamamlar. İstersen `YOUR_TEAM_ID` yerine gerçek Team ID'yi yaz ve commit'le.

### İlk TestFlight yüklemesi

Codemagic dashboard:
1. Apps > melodi > Workflows > **Melodi iOS (App Store - Signed)** → Start new build (branch: `main`)
2. Build log sonunda `Publishing to App Store Connect` → başarılı
3. App Store Connect > TestFlight > iOS Builds → ~10 dk sonra görünür → Internal Testing ekle

### Yerel doğrulama (Mac gerektirir)

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release \
  --dart-define=APP_STORE=true \
  --dart-define=DISABLE_YTDLP_DIRECT=true \
  --export-options-plist=ios/ExportOptions.plist
open build/ios/archive/Runner.xcarchive
# Xcode Organizer > Validate App
```

### Sık hatalar

- `No signing certificate "iOS Distribution"` → Certificates > Distribution oluştur ve Codemagic'in fetch adımını tekrar çalıştır.
- `App Groups` hatası → developer.apple.com > Identifiers > com.melodi.app > App Groups > `group.com.melodi.app` işaretle ve profili regenerate et.
- `Missing compliance` → Info.plist `ITSAppUsesNonExemptEncryption=false` zaten var; Codemagic export'ta compliance sorusunu otomatik "NO" geçer.

