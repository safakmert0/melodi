# Melodi 4.2.0 — kişisel müzik sunucusu ve Kapak Akışı

Bu sürüm, ListenNow+’ın güncel Apple Music benzeri kaynak birleştirme yaklaşımını Melodi’ye açık ve denetlenebilir bir mimariyle taşır. Spotify kitaplığı metadata ve çalma listesi kaynağı olarak korunurken, kullanıcının sahip olduğu tam parçalar için Navidrome/Subsonic kişisel sunucu desteği eklenmiştir.

## Navidrome / Subsonic

- Ayarlar → Müzik kaynakları bölümünden Navidrome veya Subsonic uyumlu sunucu bağlanabilir.
- Sunucu adresi, kullanıcı adı ve parola bağlantı kurulmadan önce gerçek `ping` isteğiyle doğrulanır.
- Parola cihazın güvenli Anahtar Zinciri’nde saklanır; ağ isteklerinde ham parola yerine her istekte yenilenen tuzlu Subsonic token’ı kullanılır.
- Güvensiz uzak bağlantıları önlemek için sunucu adresinde HTTPS zorunludur.
- Sunucudaki çalma listeleri parça sayısı ve süreleriyle görünür.
- Tek parça oynatma/indirme ile “Tümünü çal” ve “Tümünü indir” eylemleri eklendi.
- Navidrome parçaları birleşik aramada ayrı kaynak etiketiyle görünür ve tam parça olarak oynatılır.
- İndirilen dosyalar Dosyalar uygulamasına açılmaz; Melodi’nin özel uygulama deposunda kalır.
- MP3, FLAC, M4A, AAC, OGG, OPUS ve WAV yanıtları gerçek biçimleri korunarak kaydedilir.

## Spotify ile kişisel kitaplık eşleştirme

- Spotify’dan içe aktarılan parça önce cihazdaki indirilmiş dosyada aranır.
- Navidrome bağlıysa başlık, sanatçı ve gerçek süre birlikte puanlanır; güvenli eşik üzerindeki kişisel sunucu parçası öncelikli oynatılır.
- Spotify listesinden indirme yapılırken aynı parça kişisel sunucuda bulunursa yeniden ve farklı bir çevrim içi yüklemeyle eşleştirilmeden doğrudan kullanıcının dosyası indirilir.
- Kişisel sunucuda eşleşme yoksa Melodi’nin mevcut tam-parça çözümleme sırası çalışmaya devam eder.

## Oynatıcı ve arayüz

- Ana oynatıcıdaki kapak resmine dokununca yeni 3B “Kapak Akışı” ekranı açılır.
- Kapak Akışı gerçek oynatma sırasını kullanır; sağa/sola kaydırarak parçalar gezilebilir.
- Bir kapağa dokunmak seçilen parçayı kuyruktan oynatır ve ana oynatıcıya döner.
- Kaynak Merkezi artık Navidrome bağlantı durumunu ve desteklediği arama, oynatma, liste, çevrimdışı ve kayıpsız yetenekleri gösterir.
- Minimal Ayarlar ve Tüm Ayarlar içindeki kaynak açıklamaları kişisel sunucu desteğiyle güncellendi.

## Güvenlik ve doğrulama

- Spotify ses akışı, kimlik doğrulaması veya DRM koruması atlatılmaz. Spotify entegrasyonu kitaplık metadata’sı sağlar; tam ses yalnızca desteklenen kaynaklardan veya kullanıcının kendi sunucusundan gelir.
- Tüm 37 Flutter testi başarılıdır.
- Değiştirilen dosyalarda derleme hatası veya uyarı yoktur.
