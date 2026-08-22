# Melodi 4.3.0

Bu sürüm lossless (Hi-Fi) dinleme altyapısını ekler: Spotify kataloğunda arama yapılır, seçilen parça sunucu tarafından FLAC olarak indirilir ve kayıpsız kalitede çalınır.

## Hi-Fi kaynağı

- Arama sonuçlarına yeni "Hi-Fi" kaynağı eklendi; sonuçlar yeşil renkle etiketlenir.
- Hi-Fi parça çalındığında sunucu önce parçayı FLAC olarak kütüphaneye ekler, ardından doğrudan sunucudan lossless stream oynatılır.
- Aynı parça tekrar çalınırsa yeniden indirilmez; kütüphanedeki mevcut kopya kullanılır.
- Sunucu adresi varsayılan olarak gömülü gelir; ileride ayarlardan değiştirilebilir.

## Teknik

- `MusicSourceType.hifi` eklendi; çoklu kaynak arama ve kaynak filtreleri güncellendi.
- Yeni `HiFiSource` servisi backend `/api/hifi/search`, `/api/hifi/download` ve `/api/library/*` uçlarını kullanır.
