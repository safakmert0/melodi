# Melodi 4.2.3

Bu sürüm ana ekran başlık yerleşimini ve yerel müzik kapaklarını düzeltir.

## Ana ekran

- Kaynak, profil ve ayarlar düğmeleri artık selamlama ve “Bugün ne dinleyeceksin?” başlığıyla aynı katmanda çizilmez.
- Araç satırı ile metin satırı ayrı bir akış düzenine taşındı; farklı iPhone ekranlarında üst üste binme engellendi.

## Yerel şarkı kapakları

- Gömülü kapağı bulunan dosyalarda mevcut kapak korunur.
- Kapaksız içe aktarılan şarkılar için başlık, sanatçı, albüm ve süre birlikte doğrulanarak internetten kapak aranır.
- İlk arama sonucunun rastgele atanması kaldırıldı; düşük güvenli veya ilgisiz sonuçlar reddedilir.
- Doğrulanan kapak MP3 (ID3), FLAC ve iOS M4A metadata’sına gömülür.
- Metadata yazımı desteklenmeyen dosyalarda doğrulanan kapak Melodi önbelleğinde tutulur.
- Güvenilir kapak bulunamazsa şarkı kartı, ana öneri kartı ve oynatıcı Melodi uygulama logosunu gösterir.
- FLAC dosyasına kapak eklenirken mevcut başlık, sanatçı, albüm ve diğer Vorbis etiketleri korunur.

## Doğrulama

- Yeni başlık yerleşimi, kapak eşleştirme, MP3/FLAC metadata koruma testleri eklendi.
- Otomatik testler: 45/45 geçti.
- Değiştirilen dosyalarda statik analiz hatası yok.

IPA imzasızdır; SideStore/AltStore benzeri bir araçla kendi hesabınızla imzalanmalıdır.
