# Melody Projesi Yapılandırma ve Talimatlar

## Dil Tercihi
Bu projede iletişim için Türkçe kullanılır. Lütfen tüm yanıtlarınızı Türkçe verin.

## Proje Hakkında
Melodi, kaynak farkında olan bir müzik kütüphanesi, akış alma eki, indirici ve iOS için yerel oynatıcıdır.

## Özellikler
- Spotify entegrasyonu
- YouTube üzerinden indirme ve akış
- Navidrome/Subsonic sunucu desteği
- Çoklu kaynak arama sistemi
- Yerel dosya yönetimi ve oynatma
- iOS ve Android platform desteği

## Yapılandırma Notları
- iOS izinleri Info.plist dosyasında yapılandırılır
- Android izinleri AndroidManifest.xml dosyasında yapılandırılır
- Bağımlılıklar pubspec.yaml dosyasında belirtilir
- Yapı bayrakları lib/core/app_config.dart dosyasında yönetilir

## Yapı Komutları
```bash
flutter pub get          # Bağımlılıkları yükle
flutter build ios        # iOS için derle
flutter build apk        # Android için derle
flutter run              # Geliştirme modunda çalıştır
```

## Sorun Giderme
Eğer çevrimiçi oynatma veya indirme çalışmıyorsa:
1. İzinlerin doğru yapılandırıldığını kontrol edin (Info.plist ve AndroidManifest.xml)
2. Bağımlılıkların güncel olduğundan emin olun (flutter pub upgrade)
3. Ağ bağlantınızı kontrol edin
4. Gerekirse extension servislerini kurun veya yapılandırın
