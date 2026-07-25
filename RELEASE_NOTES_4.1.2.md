# Melodi 4.1.2 — İndirilenler oynatma düzeltmesi

Bu sürüm, 4.1.1 saha raporunda görülen indirilen parçanın açılmaması ve oynatıcının hata sırasında kuyrukta sonsuz dolaşması sorunlarını giderir.

## İndirilen parçalar

- Oynatıcı, çevrim içi eşleştirmeden önce indirme tablosundaki gerçek yerel dosyayı kontrol eder.
- Eski indirmeler kaynak kimliğiyle yeniden bağlanır; farklı kaynak kimliklerinde başlık ve sanatçı eşleşmesi güvenli yedek yol olarak kullanılır.
- İndirme tamamlandığı halde kütüphane içe aktarımı aksarsa mevcut dosya yine çevrimdışı kayıt olarak saklanır.
- İndirilenler ekranındaki tamamlanmış parçaya dokunarak veya üç nokta menüsündeki Çal seçeneğiyle oynatma başlatılabilir.

## Oynatma güvenilirliği

- Açılamayan bir parça artık playCurrent ve onTrackComplete arasında özyinelemeli döngü oluşturmaz.
- Kuyruktaki her sonraki parça en fazla bir kez denenir; tümü başarısızsa oynatıcı güvenli biçimde durur.
- Tekrar-tümü açıkken kuyruk en fazla bir kez sarılır ve başarısız başlangıç parçası yeniden denenmez.

## iOS depolama

- İndirilenler Melodi uygulamasının özel çevrimdışı alanında kalır.
- Bu alanın Apple Dosyalar uygulamasında görünmediği İndirilenler, Ayarlar ve ilk kurulum ekranlarında açıkça belirtilir.
- Eski klasörden taşınan dosyaların indirme tablosundaki yolları da otomatik güncellenir.

## Doğrulama

- 25 otomatik Flutter testi başarılı.
- Yeni kuyruk hata planı için dört ayrı gerileme testi eklendi.
- Flutter analizinde hata veya uyarı yok; yalnızca projedeki mevcut bilgi düzeyi modernizasyon notları bulunuyor.
