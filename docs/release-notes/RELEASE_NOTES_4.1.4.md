# Melodi 4.1.4 — Spotify çalma listeleri ve ana oynatıcı

Bu sürüm indirilen şarkıların oynatıcıya aktarılmasını düzeltir ve Spotify çalma listelerini Ayarlar içinden kullanılabilir hale getirir.

## Ana oynatıcı

- İndirilen bir şarkıya dokunulduğunda mini oynatıcı eklenmez; parça doğrudan tam ekran ana oynatıcıda açılır.
- İndirilen dosyanın başlık, sanatçı, albüm ve kuyruk bilgileri ana oynatıcıya aktarılır.
- Oynatma başlatılırken ekran geçişinin şarkı bitimine kadar beklemesine yol açan asenkron akış kaldırıldı.

## Spotify çalma listeleri

- Ayarlar > Tüm Ayarlar > Spotify altındaki çalma listeleri artık açılabilir.
- Çalma listesi içindeki gerçek şarkı adları, sanatçılar, albümler, kapaklar ve güncel şarkı sayısı gösterilir.
- Spotify liste bilgileri ekran açıldığında yenilenir; geçici bağlantı hatasında kayıtlı listeler silinmez.
- Bir şarkıya dokunulduğunda tüm çalma listesi kuyruğa alınır ve seçilen şarkı ana oynatıcıda başlar.

## İndirmeler

- Çalma listesi başlığına “Tümünü indir” düğmesi eklendi.
- Her Spotify şarkısının üç nokta menüsüne ayrı “İndir” eylemi eklendi.
- Diğer çevrimiçi şarkı satırlarının ortak üç nokta menüsü de indirme eylemini destekler.
- Toplu indirmede daha önce kuyruğa eklenenler ve yinelenen Spotify parça kimlikleri atlanır.

## Doğrulama

- Flutter analizinde hata veya uyarı yok.
- 28 otomatik Flutter testi başarılı.