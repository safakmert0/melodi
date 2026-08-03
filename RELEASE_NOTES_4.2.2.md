# Melodi 4.2.2

Bu sürüm iPhone oynatma güvenilirliği ve iki belirgin ekran yerleşimi sorununa odaklanır.

## Düzeltmeler

- Oynatıcı ekranının altındaki büyük boş alan kaldırıldı; uzun iPhone ekranlarında kontroller dengeli yerleşir.
- Ana sayfadaki kaynak/profil düğmelerinin selamlama ve “Bugün ne dinleyeceksin?” başlığıyla üst üste gelmesi giderildi.
- Çevrimiçi oynatma, çalışmayan veya süresi dolmuş bir medya URL’sinde durmak yerine aynı parça için en fazla üç uygun kaynağı sırayla dener.
- YouTube arama sonuçları iOS’ta doğrudan süresi dolabilen URL yerine menzil isteklerini yöneten kalıcı Melodi akış kaynağıyla oynatılır.
- `(-1008) kaynak yok` hatasından sonra alternatif kaynağa otomatik geçiş eklendi.

## Doğrulama

- Flutter statik analizi: hata/uyarı yok.
- Otomatik testler: 37/37 geçti.

IPA imzasızdır; SideStore/AltStore benzeri bir araçla kendi hesabınızla imzalanmalıdır.
