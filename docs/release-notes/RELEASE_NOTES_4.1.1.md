# Melodi 4.1.1 — Oynatma ve çevrimdışı güvenilirlik güncellemesi

Bu sürüm, 4.1.0 saha testinde bulunan oynatma, Spotify, indirme ve ayar sorunlarını giderir.

## Oynatma

- iOS çevrim içi oynatma kaynağı gerçek HTTP byte-range desteğiyle yenilendi.
- Arama sonuçlarında çözümlenmiş medya URL’si AVPlayer’a doğrudan veriliyor.
- Şarkı bitince sıradaki kuyruk öğesine güvenilir biçimde geçiliyor.
- Kuyruk sonunda oynat düğmesine yeniden basıldığında parça baştan başlıyor.
- Tekrar bir/tümü davranışları Melodi kuyruğuyla uyumlu hale getirildi.
- Yerel arama sonucu tek parçalık kuyruk yerine kitaplık kuyruğunda çalıyor.
- Spotify kuyruğundaki her parça, çalınacağı anda uygun YouTube Music kaynağına eşleştiriliyor.
- Uygulama yeniden açıldığında geri yüklenen Spotify parçası yerel indirme veya çevrim içi akışa yeniden çözülüyor.

## Spotify

- Tüm çalma listeleri, klasörler ve beğenilen şarkılar son sayfaya kadar getiriliyor.
- Güncel Spotify `/items` yanıtı ile eski `track` yanıtı birlikte destekleniyor.
- Özel listelerde kullanıcı oturumu, açık listelerde güvenli yedek yol kullanılıyor.
- Çalma listesindeki tüm parçalar yerel kitaplıkta görünür kalıyor.
- Eksik Spotify kapakları kontrollü eşzamanlılıkla indirilip önbelleğe alınıyor.
- 4.1.0’ın oluşturduğu boş/çift Spotify liste kabukları güvenli biçimde temizleniyor.
- Geçici boş ağ yanıtı mevcut dolu yerel listeyi artık silmiyor.

## İndirmeler

- Bilinen YouTube video kimliği yeniden aranmadan doğrudan indirme görevine aktarılıyor.
- İndirilen Spotify parçası aynı kitaplık kaydına bağlanıyor; “indirildi” görünüp çalmama sorunu giderildi.
- Eski indirmeler açılışta bulunup Spotify kayıtlarına yeniden bağlanıyor.
- iOS indirmeleri artık Dosyalar uygulamasında klasör oluşturmaz; Melodi’nin özel çevrimdışı alanında tutulur.
- Özel çevrimdışı klasör iCloud yedeğinin dışında bırakılır.

## Arayüz ve ayarlar

- Uzun senkronize söz satırları kesilmeden tek satıra sığdırılıyor.
- Oynatıcı ve şarkı listelerindeki Paylaş düğmeleri yerel ve çevrim içi parçalarda gerçek sistem paylaşım ekranını açıyor.
- “Tüm ayarlar” ana Ayarlar ekranıyla aynı minimal kart tasarımında ve aranabilir olarak yenilendi.
- Açık kaynak teşekkürler listesindeki projeler artık dokunulabilir ve resmi sayfalarını açıyor.
- iOS Depolama ekranı çevrimdışı dosyaları “Melodi · Özel çevrimdışı alan” olarak gösteriyor.

## Doğrulama

- Flutter analizinde hata ve uyarı yok.
- 21 otomatik test başarılı.
- Gerçek ağ smoke testinde YouTube oynatma aralığı `206 / 4096 bayt`, tam indirme `200 / 309288 bayt` olarak doğrulandı.
