# Melodi 4.1.0 — Premium Yeniden Tasarım

Melodi 4.1, uygulamanın kurulumdan oynatıcıya kadar ortak bir tasarım diliyle yeniden ele alındığı büyük deneyim güncellemesidir.

## Yeni Melodi deneyimi

- Sıcak pembe vurgu, güçlü tipografi, editoryal kartlar ve yeni yüzey sistemiyle açık/koyu tema baştan oluşturuldu.
- Ana Sayfa; büyük “Listen Now” alanı, dinamik karşılama ve iki sütunlu hızlı eylemlerle yeniden tasarlandı.
- Arama; büyük Keşfet başlığı, birleşik yerel/çevrim içi sonuçlar ve daha anlaşılır kaynak etiketleri kazandı.
- Yeni renk geçişli alt dock ve mini oynatıcı, gezinme sırasında oynatma durumunu koruyor.
- Ayarlar artık aranabilir, sade kategori merkezi olarak açılıyor; tüm gelişmiş seçenekler “Tüm ayarlar” altında korunuyor.

## Kurulum ve erişilebilirlik

- Beş adımlı kurulum akışı tamamen yenilendi: dil, tema, kaynaklar ve indirme konumu tek akışta ayarlanabiliyor.
- Dil seçimi kurulum ekranına anında uygulanıyor.
- Açık tema kontrastı yalnız yeni ekranlarda değil; albüm, sanatçı, liste, kuyruk, sözler, tanılama ve eski gelişmiş ayarlarda da dinamik uyumluluk paletiyle düzeltildi.
- Açık vurgu renklerinde buton metni otomatik olarak siyah/beyaz karşıt renge geçiyor.

## Oynatma, indirme ve sözler

- Deezer’ın 30 saniyelik önizleme URL’leri artık tam şarkı olarak oynatılmıyor veya indirilmiyor.
- Katalog sonuçları tam parça için YouTube/JioSaavn kaynaklarına başlık, sanatçı ve süre eşleşmesiyle çözümleniyor.
- Doğrudan indirme URL’si başarısız olursa görev otomatik olarak YouTube indirme yedeğine geçiyor.
- Senkronize tek söz satırı kapağın hemen altındaki kalıcı canlı söz bandında gösteriliyor; banda dokununca tam söz ekranı açılıyor.
- Dosyada düz söz bulunsa bile senkron söz araması devam ediyor.
- Spotify liste içe aktarma sonrasında görülen `Null check operator used on a null value` iOS hatası düzeltildi.

## Kalite

- Tema kontrastı, senkron LRC sıralaması ve önizleme-kaynak ayrımı için yeni regresyon testleri eklendi.
- 15 otomatik test başarılı; Flutter analizinde hata ve uyarı bulunmuyor.

## Kurulum

Bu sürümdeki IPA imzasızdır. SideStore, AltStore veya Sideloadly ile kendi Apple kimliğiniz üzerinden imzalayarak kurabilirsiniz.
