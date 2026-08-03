# Melodi 4.2.1 — oynatma ve kitaplık kararlılığı

Bu sürüm, iPhone testlerinde bildirilen aktif parça, Spotify liste çoğalması, oynatıcı yerleşimi, şarkı sözleri ve indirme kuyruğu sorunlarını düzeltir.

## Oynatıcı

- Ses başlatılırken ana oynatıcı artık çalan parçayı hemen yayımlar; arka planda bir parça çalarken ekranda listedeki başka parçaların hızla değişmesi düzeltildi.
- Şarkı tamamlanma zincirinde `play()` sonucunun parça sonuna kadar beklenmesi kaldırıldı; yinelenen tamamlama çağrıları ve büyüyen çağrı yığını engellendi.
- İndirilen yerel bir parça açıldığında Spotify/YouTube yer tutucuları yerel kuyruğa karışmaz.
- Ana oynatıcıdaki kapak üstü ve kapak altı gereksiz boşluklar azaltıldı; kapak alanı ekran ölçüsüne göre uyarlanır.

## Şarkı sözleri

- Tam ekran sözlerde uzun satırların tek satıra zorlanıp sol tarafta çok küçük görünmesi düzeltildi.
- Uzun sözler dört satıra kadar doğal biçimde sarılır ve uzunluğa göre okunabilir punto seçilir.
- Ana oynatıcıdan tam ekran sözlere geçerken kaynak süre bilgisi korunur; süre ölçekleme ve senkron daha tutarlı çalışır.

## Spotify ve kitaplık

- Aynı uzak Spotify çalma listesine bağlı yinelenen yerel aynalar bir sonraki eşzamanlamada birleştirilir.
- Kimliksiz eski Spotify liste kabukları güvenli biçimde temizlenir; farklı uzak kimliğe sahip aynı adlı listeler korunur.
- Ana sayfadaki Favori, Aygıtta, Liste ve Müzik kartları artık doğru kitaplık görünümünü açar.
- Liste kartlarında mümkün olduğunda listenin ilk gerçek şarkı kapağı gösterilir.
- “Tümünü çal” mevcut olmayan yerel dosyaları kuyruğa eklemez.
- Kitaplık satırlarında indirilen parçanın dosya boyutu gösterilir.
- Kitaplık Sağlığı onarımları işlemden sonra zorunlu yeniden taranır; eski önbellek sonucu ekrana geri gelmez.

## İndirmeler ve ana sayfa

- İndirmeler iOS kararlılığı için tekli ve sıralı kuyrukla işlenir.
- Aynı parça indirilmiş veya sıradaysa yeni görev oluşturulmaz ve ekranın altında bilgi mesajı gösterilir.
- Ana sayfa başlığı “Bugün ne dinleyeceksin?” olarak düzeltildi.
- Kaynak ve profil düğmeleri sol üste taşındı; sağ üstte yalnızca anlaşılır dişli Ayarlar simgesi bırakıldı.
- Miks bölümlerindeki çalışmayan ikincil “Yeniden oluştur” düğmeleri kaldırıldı.

## Doğrulama

- Tüm 37 Flutter testi başarılıdır.
- Değiştirilen dosyalarda statik analiz derleme hatası veya uyarı üretmez; yalnızca mevcut Flutter API kullanımlarına ait bilgi düzeyinde bildirimler kalır.
