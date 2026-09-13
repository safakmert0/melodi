# Design System Inspired by Spotify

Melodi arayüzü bu dosyadaki dile uyar. Yapay zeka ajanları ve geliştiriciler
bu belgeyi tek doğruluk kaynağı saysın.

## 1. Visual Theme & Atmosphere

Near-black (`#121212`, `#181818`, `#1f1f1f`) içine gömülü, sürükleyici karanlık
müzik çalar. Felsefe "content-first darkness": arayüz gölgeye çekilir, renk
yalnızca Spotify Green (`#1ed760`) ve albüm kapaklarından gelir.

- Near-black sürükleyici koyu tema (`#121212`–`#1f1f1f`)
- Spotify Green (`#1ed760`) tek marka vurgusu — işlevsel, asla dekoratif değil
- Kalın/ince ikiliğiyle tipografi (700 vurgu, 400 gövde)
- Hap (pill) butonlar (500px–9999px), dairesel (%50) çalma kontrolleri
- Buton etiketleri büyük harf + geniş harf aralığı (1.4px–2px)
- Koyu zeminde ağır gölgeler (`rgba(0,0,0,0.5) 0px 8px 24px`)
- Renk kapaktan gelir — arayüz kendisi renksizdir

## 2. Color Palette & Roles

### Primary Brand
- **Spotify Green** (`#1ed760`): play butonları, aktif durumlar, CTA
- **Near Black** (`#121212`): en derin zemin
- **Dark Surface** (`#181818`): kartlar, kutular, yükseltilmiş yüzeyler
- **Mid Dark** (`#1f1f1f`): buton zeminleri, etkileşimli yüzeyler

### Text
- **White** (`#ffffff`): birincil metin
- **Silver** (`#b3b3b3`): ikincil metin, pasif etiketler, pasif nav
- **Near White** (`#cbcbcb`): biraz daha parlak ikincil metin

### Semantic
- **Negative Red** (`#f3727f`): hata
- **Warning Orange** (`#ffa42b`): uyarı
- **Announcement Blue** (`#539df5`): bilgi

### Surface & Border
- **Dark Card** (`#252525`): yükseltilmiş kart
- **Border Gray** (`#4d4d4d`): koyuda buton kenarlığı
- **Light Border** (`#7c7c7c`): çerçeveli buton kenarlığı
- **Green Border** (`#1db954`): yeşil vurgu kenarlığı

### Shadows
- **Heavy** (`rgba(0,0,0,0.5) 0px 8px 24px`): diyaloglar, menüler
- **Medium** (`rgba(0,0,0,0.3) 0px 8px 8px`): kartlar

## 3. Typography Rules

- **Başlık**: 24px, 700 — bölüm başlıkları
- **Alt başlık**: 18px, 600 — sıkı satır aralığı
- **Gövde**: 16px, 400 (vurgu: 700) — standart metin
- **Buton**: 14px, 700, BÜYÜK HARF, harf aralığı 1.4px–2px
- **Meta**: 14px, 400 — sanatçı, albüm, süre
- **Küçük**: 12px, 400 (etiket: 700) — sayılar, rozetler
- İlke: 700/400 ikiliğiyle hiyerarşi; boyut çeşitliliğinden çok ağırlık kontrastı.

## 4. Component Stylings

### Buttons
- **Dark Pill**: `#1f1f1f` zemin, beyaz metin, 9999px — ikincil eylemler
- **Green Play (daire)**: `#1ed760` zemin, siyah ikon, %50 — çal/duraklat
- **Outlined Pill**: transparan, beyaz metin, `1px solid #7c7c7c`, 9999px
- **Circular icon**: %50 — karıştır, tekrarla, sıra

### Cards & Containers
- Zemin `#181818` veya `#1f1f1f`, radius 8px, kenarlık yok
- Yükseltilmişte `rgba(0,0,0,0.3) 0px 8px 8px` gölge

### Inputs
- Arama: `#1f1f1f` zemin, beyaz metin, 500px hap

### Navigation
- Alt bar `#121212`; aktif: beyaz 700 + yeşil gösterge; pasif: `#b3b3b3` 400
- Mini oynatıcı: `#181818` kart, yeşil dairesel play

### Progress
- Çizgi ve süre yeşil (`#1ed760`); geçen/kalan `#b3b3b3` 12px

## 5. Layout Principles

- 8px taban birimi: 4, 8, 12, 16, 20
- Radius: rozet 2px, kapak 8px, kart 8px, sayfa 16px, hap 9999px, daire %50
- Yoğun içerik, dar boşluk — her piksel dinleme içindir
- Tam genişlikte alt mini oynatıcı her ekranda korunur

## 6. Depth & Elevation

| Seviye | Uygulama | Kullanım |
|-------|----------|----------|
| Base | `#121212` | Sayfa zemini |
| Surface | `#181818` / `#1f1f1f` | Kart, liste, çubuk |
| Elevated | `0px 8px 8px rgba(0,0,0,0.3)` | Menü, kart vurgusu |
| Dialog | `0px 8px 24px rgba(0,0,0,0.5)` | Modal, alt sayfa |

## 7. Do's and Don'ts

### Do
- `#121212`–`#1f1f1f` zeminler; yeşili yalnızca çal/aktif/CTA'da kullan
- Tüm butonları hap, çalma kontrollerini daire yap
- Buton metinlerini büyük harf + geniş aralık yaz
- Tipografiyi kompakt tut (10px–24px)
- Rengi kapaktan al, arayüzü renksiz bırak

### Don't
- Yeşili dekoratif kullanma, zemine yeşil koyma
- Köşeli buton yapma
- İnce silik gölge kullanma
- Marka renkleri ekleme (yeşil + gri yeter)
- Ham gri kenarlık gösterme

## 8. Agent Prompt Guide

- Zemin: Near Black (`#121212`) — Yüzey: Dark Card (`#181818`)
- Metin: White (`#ffffff`) — İkincil: Silver (`#b3b3b3`)
- Vurgu: Spotify Green (`#1ed760`) — Kenarlık: `#4d4d4d`
- Hata: Negative Red (`#f3727f`)
- Koyu kart: `#181818` zemin, 8px radius. Başlık 16px 700 beyaz; alt 14px 400 `#b3b3b3`.
- Hap buton: `#1f1f1f` zemin, beyaz metin, 9999px radius, 8px 16px dolgu, 14px 700 büyük harf.
- Yeşil dairesel play: `#1ed760` zemin, siyah ikon, %50 radius.
- Arama: `#1f1f1f` zemin, beyaz metin, 500px radius.
- Alt bar: `#121212` zemin; aktif beyaz 700 + yeşil nokta; pasif `#b3b3b3` 400.
