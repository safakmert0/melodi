# Melodi 4.1.5 — doğru süreli indirme, merkezlenen sözler ve tam Spotify kitaplığı

Bu sürüm Spotify kitaplığının eksik görünmesi, senkronize sözlerin kayması ve yanlış uzunluktaki indirmeler üzerine odaklanır.

## İndirme ve çevrimdışı oynatma

- Kaynak adayları artık Spotify/arama sonucundaki gerçek parça süresine göre sıralanır.
- Örneğin 4 dakikalık bir parça için 8–9 dakikalık video adayı indirilmeden elenir.
- İndirilen dosyanın kapsayıcı süresi içe aktarmadan önce yeniden doğrulanır.
- iOS'ta M4A dosyasının sonundaki fazla sessizlik beklenen parça süresine güvenli biçimde kesilir.
- Senkronize LRC sözleri indirme sırasında M4A dosyasının söz meta verisine gömülür ve ayrıca uygulama veritabanında saklanır.
- Önceki sürümde yanlış kaynakla indirilmiş uzun dosyalar için parçayı silip yeniden indirmek gerekir.

## Spotify

- Web API, Spotify kitaplık grafiği ve kayıtlı liste önbelleği birleştirilir; kısmi API yanıtı diğer listeleri gizlemez.
- Listeler artık adla değil uzak Spotify kimliğiyle eşlenir; aynı adlı listeler birbirinin üzerine yazılmaz.
- Bir listedeki geçici hata diğer listelerin senkronizasyonunu durdurmaz.
- Senkronizasyon tamamlandığında Kitaplık ve Çalma Listeleri ekranları otomatik yenilenir.
- Ayarlardaki içe aktarma, aldığı liste kümesini doğrudan senkronizasyona aktarır; ikinci ve tutarsız ağ sorgusu kaldırıldı.

## Şarkı sözleri ve oynatıcı

- Ana oynatıcıdaki “Kapak / Sözler / Sırada” seçici kaldırıldı.
- Kapak altındaki tek satır söz, çok uzun dizelerde sağ tarafı kesmeden kullanılabilir genişliğe küçülür.
- Tek satır söze dokunmak tam söz ekranını açar.
- Tam söz ekranında aktif satır değişken satır yüksekliğinden bağımsız olarak ekran merkezinde kalır.
- LRC offset etiketi uygulanır; LRCLIB kaynak süresi ile küçük hız kaymaları düzeltilir.
- Parça başına kalıcı −0,5 / +0,5 saniye senkron ince ayarı eklendi.
- Bir söz satırına dokunarak o zamana gidilebilir.

## Veri ve doğrulama

- Veritabanı sürümü 20; söz önbelleği artık kaynak süresini de saklar.
- Değişen Dart dosyalarında analiz hatası veya uyarısı yok.
- 33 otomatik Flutter testi başarılı.