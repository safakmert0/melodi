# Melodi v3.3.0 Release Notes

## Yeni Özellikler

### 🎵 Arama Ekranı Yenilendi
- **Kapak Resimleri**: Arama sonuçlarında şarkıların kapak resimleri artık görünüyor
- **İnternet Araması**: Yerel kitaplıkta bulunmayan şarkılar YouTube'da otomatik aranıyor
- **İki Ayrı Sonuç Bölümü**: "Yerel Sonuçlar" ve "İnternet Sonuçları" olarak ayrı gösterim
- **İnternetten Çalma**: YouTube sonuçları doğrudan streaming olarak çalınabiliyor
- **İndirme Desteği**: Internetten bulunan şarkılar indirilebiliyor

### 🎧 Oynatıcı Ekranı İyileştirmeleri
- **Hızlı Geçiş**: Küçük ekrandan tam ekrana geçiş artık daha akıcı
- **Kapak Resmi Pozisyonu**: Kapak resmi ekranın en yukarı taşındı
- **Boşluk Düzeltmesi**: "Şimdi Çalıyor" başlığı ile kapak resmi arasındaki büyük boşluk kaldırıldı
- **Sabit Renk**: Şarkılara göre değişen renk ayarı kaldırıldı, sabit mavi renk kullanılıyor

### 🎨 Renk Değişiklikleri
- **Varsayılan Renk**: Yeşil yerine mavi renk kullanılıyor
- **Tüm Tema Renkleri Güncellendi**: Butonlar, vurgular, geçişler mavi tona güncellendi

### 🔊 Ekolayzır Artık Çalışıyor
- **Gerçek Ses Etkisi**: Ekolayzır ayarları artık müziği gerçekten değiştiriyor
- **Android Equalizer**: just_audio kütüphanesinin Android equalizer özelliği aktif edildi
- **Otomatik Uygulama**: Her şarkı çalınmaya başlandığında ekolayzır otomatik uygulanıyor
- **Kalıcılık**: Ekolayzır ayarları uygulama kapatıldığında bile saklanıyor

### 🌍 Tam Dil Desteği
- **Ses Efektleri Sayfası**: "Audio Effects" → "Ses Efektleri" olarak Türkçeleştirildi
- **Siri Kısayolları**: Tüm menü öğeleri Türkçeleştirildi
- **Karıştırma Listeleri**: "Mix" → "Karışım", "Daily Mix" → "Günlük Karışım"
- **Arama Sonuçları**: Tüm mesajlar üç dile çevrildi (Türkçe, İngilizce, Almanca)

### 💾 Oynatma Durumu Hafızası
- **Son Şarkı Hafızası**: Uygulama arka plandan temizlendiğinde bile son çalınan şarkı saklanıyor
- **Süresiz Hafıza**: 24 saat sınırı kaldırıldı, süreliksiz saklanıyor
- **Sıra Hafızası**: Çalma sırası da aynen korunuyor
- **Pozisyon Hafızası**: Şarkı kaldığı yerden devam ediyor
- **Otomatik Kaydetme**: Her 5 saniyede bir ve önemli işlemlerde otomatik kayıt

### 📱 Spotify & YouTube Music Entegrasyonu
- **Çalma Listesi Aktarımı**: İçe aktarılan çalma listeleri artık kitaplık ekranında da görünüyor
- **Otomatik Ekleme**: Import edilen listeler otomatik olarak yerel kitaplığa ekleniyor

### ⚙️ Ayarlar Sayfası
- **Crossfade Temizlendi**: Ses bölümündeki tekrar eden Crossfade ayarı kaldırıldı
- **İndirme Konumu Kalıcılığı**: Seçilen dosya konumu artık uygulama yeniden açıldığında da korunuyor
- **Türkçeleştirme**: Tüm menü öğeleri doğru dile çevrildi

## Hata Düzeltmeleri

- Arama sonuçlarında kapak resimlerinin görünmemesi sorunu düzeltildi
- Ekolayzır modları arasında geçiş yapılmasına rağmen sesin değişmemesi düzeltildi
- Ses Efektleri menüsündeki seçeneklerin açılamaması düzeltildi
- Uygulama arka plandan temizlendiğinde son çalınan şarkının kaybolması düzeltildi
- İndirme konumu ayarının kalıcı olmaması düzeltildi
- Karıştırma listelerindeki yeşil yazı rengi düzeltildi (beyaz yapıldı)
- Oynatıcı ekranında koyu kapak resimlerinde tuşların görünmemesi düzeltildi

## Teknik İyileştirmeler

- `_savePlayerState()` metodu herkese açık yapıldı (public)
- `replaceQueue()` metodu eklendi - queue değiştirme desteği
- Gereksiz import'lar temizlendi
- Duplicate import'lar kaldırıldı
- Locale çevirilerinde eksik anahtarlar eklendi

## Dosyalar Değişen

- `lib/core/constants.dart` - Renk paleti güncellendi
- `lib/core/localization.dart` - Yeni çeviri anahtarları eklendi
- `lib/models/song_model.dart` - JSON serializasyon metodları eklendi
- `lib/providers/player_provider.dart` - Oynatma durumu kaydetme/geri yükleme
- `lib/providers/search_provider.dart` - İnternet arama desteği
- `lib/providers/theme_provider.dart` - Varsayılan renk güncellendi
- `lib/screens/home_screen.dart` - Çeviri desteği, renk düzeltmeleri
- `lib/screens/now_playing_screen.dart` - Yerleşim ve performans iyileştirmeleri
- `lib/screens/onboarding_screen.dart` - Renk güncellendi
- `lib/screens/profile_screen.dart` - Renk güncellendi
- `lib/screens/search_screen.dart` - İnternet arama özelliği
- `lib/screens/settings_screen.dart` - Dil düzeltmeleri, crossfade temizliği
- `lib/services/audio_handler.dart` - Ekolayzır ve oynatma durumu desteği
- `lib/services/database_service.dart` - Kapak resmi yükleme düzeltmesi
- `lib/widgets/equalizer_sheet.dart` - Gerçek ekolayzır entegrasyonu
- `lib/widgets/seek_bar.dart` - Varsayılan renk güncellendi
- `lib/widgets/splash_screen.dart` - Renk güncellendi

## Kurulum

```bash
flutter pub get
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## Minimum Gereksinimler

- Flutter: 3.16.0+
- Dart: 3.2.0+
- Android: API 21+ (Android 5.0+)
- iOS: 12.0+
