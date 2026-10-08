# 004 — Dizayn tizimi v2: «AI qilgan» ko'rinishdan senior darajasiga

- **Status**: TODO
- **Asos**: `artifacts/marketplace-audit/ios-final.png`, `web-desktop.jpg`; `app/lib/core/theme/*`, `core/widgets/*`
- **Oldingi ishlar**: 001–003 (motion, dark mode, feedback). Ularni buzmaslik kerak: reduce-motion, tonal surface, 20px karta radiusi.

## 0. Nega hozir «oddiy» ko'rinadi (aniq dalillar)

| # | Muammo | Dalil |
|---|---|---|
| 1 | **Barterning asosiy g'oyasi ko'rinmaydi.** «Nimaga almashadi» — kichik teal matn `⇄ Telefon / Elektronika` | Feed kartasi. Narx eng katta element — bu OLX, barter emas |
| 2 | **Zichlik past:** telefonda bir ekranda 1 ta e'lon | 190px+ rasm, bitta ustun. Vinted/Avito/OLX — 2 ustun |
| 3 | **Kategoriyalar bo'sh qutilar:** bej ustida bej, kulrang ikonka; `CategoryStyle.tint` ranglari ishlatilmagan | «Nima izlayapsiz?» bloki |
| 4 | **Logo va palitra bir-biriga bog'lanmagan:** logo — yorqin teal→ko'k gradient, ilova — xira bej | Header |
| 5 | **Header joyni yeydi:** logo + joylashuv + qo'ng'iroq alohida qator, keyin qidiruv yana qator | Ekranning 20%i |
| 6 | **Tipografiya ierarxiyasi tekis:** Rubik + Manrope ikkalasi geometrik sans, nav yozuvlarida keng harf oralig'i | «Asosiy», «Mosliklar» |
| 7 | **Kontent ishonchsiz:** stok rasmlar e'longa mos emas | Audit P1 — kontent |
| 8 | **Asosiy amal (E'lon) oddiy ikonka** | Pastki nav |

Generic «AI dizayn» belgilari: hamma joyda bir xil yumaloq kartalar, maqsadsiz gradient, g'oyasiz layout. Yechim — bitta **vizual g'oya** va qat'iy tizim.

## 1. Vizual g'oya: «Beraman ⇄ Olaman»

Har bir e'lon ikki tomonli: **beradi** (yashil/teal, `give`) va **oladi** (ko'k, `take`). Bu juftlik — brendning yagona imzosi:
- Gradient faqat **almashuv lahzalarida** (moslik topildi, taklif qabul qilindi, kelishuv yakunlandi). Boshqa joyda gradient yo'q.
- `SwapChip` komponenti: `[rasm/ikonka beradi] ⇄ [oladi]` — kartada, detalda, chatda, mosliklarda bir xil.
- Logo ranglari shu ikki rolga bog'lanadi; bej fon iliq «bozor» his qoldiradi, lekin kontrast oshiriladi.

## 2. Asoslar (tokenlar)

**Rang** (`tokens.dart`, `app_theme.dart`)
- Semantik rollar: `give`, `take`, `money`, `trust`, `warning`, `danger` + surface pog'onalari (`surface`, `container`, `containerHigh`). Hard-code `Color(0x…)` faqat token faylida (hozir `app_theme.dart`da 51 ta).
- Har bir matn/fon juftligi WCAG AA ≥ 4.5:1, test bilan tekshiriladi.
- Kategoriya ranglari chip/ikonka fonida haqiqatan ko'rinadi (light + dark).

**Tipografiya**
- Bitta oila (tavsiya: Manrope qoladi, Rubik olib tashlanadi — ikkita geometrik sans bir-birini to'ldirmaydi). Kirill va oʻ/gʻ (U+02BB) tekshiriladi.
- 6 pog'ona: display 28/34, title 20/26, headline 17/22, body 15/21, label 13/17, caption 12/16.
- Narx: `FontFeature.tabularFigures()`, weight 700, «so'm» kichikroq va xiraroq.
- Nav/label harf oralig'i 0 yoki manfiy; keng tracking faqat KICHIK BOSH HARFLARda.

**Shakl**
- Flutter'ning o'z `RoundedSuperellipseBorder`i (iOS squircle) — kartalar, tugmalar, sheet'lar. Qo'shimcha paket shart emas.
- Radius shkalasi `Radii` saqlanadi.

**Harakat (motion)**
- Spring asosidagi o'tishlar (M3 Expressive uslubi): standart, tez, sekin — 3 ta token. Bounce faqat moslik/kelishuv lahzasida.
- Karta → detal: `animations` paketidagi `OpenContainer` (container transform) + rasm `Hero`.
- Tab almashuvi: shared-axis/fade-through. Ro'yxat stagger 30–80ms (003-reja).
- `reduceMotion` qoidasi saqlanadi.

**Haptika** — `Haptics` util: `selection` (filtr, tab), `light` (like), `success` (taklif yuborildi, kelishuv), `warning` (xato). Hozir 29 joyda tartibsiz.

**Ikonkalar** — `material_symbols_icons`: bitta weight/grade; tanlangan holatda `fill: 1`.

## 3. Komponentlar (yangi yoki qayta)

| Komponent | Talab |
|---|---|
| `ListingCard` v2 | 2 ustun grid, rasm 4:5, title 2 qator, narx, **SwapChip**, joy + vaqt; skeleton varianti; ♡ tez saqlash |
| `SwapChip` | beradi ⇄ oladi; kichik/katta o'lcham; «Har qanday taklif» holati |
| `PriceTag` | tabular, valyuta, «+ pul qo'shimchasi» holati |
| `TrustBadge` / `Avatar` | tasdiqlangan halqa, reyting, bitimlar soni |
| `CategoryChip` | rangli tint doira + belgi, gorizontal scroll, tanlangan holat |
| `SearchHeader` | scroll'da yig'iladigan (sliver): joy va qo'ng'iroq qidiruv qatoriga kiradi |
| `FilterSheet` | jonli «N ta natija» tugmasi, tanlangan filtr chip'lari feed tepasida |
| `OfferCard` (chat) | ikki tomon buyumlari, holat, amal tugmalari |
| `DealTimeline` | F02 holatlari: kelishildi → band → topshirildi → ikki tasdiq |
| `EmptyState` / `ErrorState` / `OfflineBanner` | har ekranda; bir uslubdagi illyustratsiyalar |
| `Skeleton` | shimmer, reduce-motion'da statik |
| Tugmalar | 3 daraja: primary (bitta ekranda bitta), tonal, text |

## 4. Ekranlar bo'yicha bosqichlar

Har bir bosqich — alohida PR (cloud vazifasi). **D1 hozir boshlanishi mumkin; D2+ esa 1-to'lqin PR'lari merge qilingandan keyin** (ular xuddi shu ekranlarga tegadi: create_listing, feed filtrlari, favorites, chat).

| Bosqich | Ish | Bog'liqlik |
|---|---|---|
| **D1 Asoslar** | Tokenlar v2, tipografiya, superellipse, motion/haptika util; **Widgetbook** katalogi; **golden testlar** (alchemist) light/dark/text-scale 2.0 | yo'q |
| **D2 Feed** | SearchHeader, CategoryChip, 2 ustun ListingCard v2, skeleton, bo'sh/xato holatlar, web 1/2/3/4 ustun | 1-to'lqin (region, favorites) |
| **D3 E'lon sahifasi** | Galereya (Hero + zoom), container transform, «Nimaga almashadi» bloki, ishonch bloki, sticky «Taklif berish» | D2 |
| **D4 E'lon yaratish** | Rasm birinchi, qadamlar (stepper), jonli karta preview | listing-draft PR |
| **D5 Mosliklar / taklif / chat** | Moslik sabablari (F01 `reason_codes`), OfferCard, DealTimeline, moslik lahzasi animatsiyasi | F01, F02 |
| **D6 Profil, onboarding, holatlar** | Ishonch pasporti, onboarding 3 ekran (o'tkazib yuboriladigan) | D1 |
| **D7 Web** | hover, focus ring, klaviatura, kursor, max-width, breakpoints 600/1000/1440 | D2–D3 |
| **D8 Sifat** | dark mode, matn 200%, VoiceOver/TalkBack semantics, 120fps profil (Impeller), rasm `cacheWidth` | hammasi |

## 5. Vositalar va manbalar

- **Widgetbook** — komponentlarni alohida ko'rish va dizaynerga ko'rsatish.
- **alchemist** — golden (screenshot) testlar: dizayn tasodifan buzilmaydi.
- **animations** (bor) — container transform, shared axis. **flutter_animate** (bor) — mikro-animatsiyalar.
- **material_3_expressive** — faqat spring/shape g'oyalari uchun manba; butun ilovani unga ko'chirmaslik (brend Material'ga o'xshab qoladi).
- **lottie** (bor) — faqat moslik/kelishuv lahzasi; har joyda emas.
- Rasmlar: seed kontentini haqiqiy, e'longa mos fotolar bilan almashtirish; AI rasm mahsulot fotosi sifatida emas.

## 6. Qabul mezoni

- Har bir ekran light/dark, matn 1.0/2.0, reduce-motion'da golden test bilan o'tadi.
- Telefonda feed bir ekranda kamida 4 ta e'lon ko'rsatadi.
- Har bir kartada «nimaga almashadi» 1 soniyada o'qiladi.
- `app_theme.dart`dan tashqarida hard-code rang yo'q (lint/test bilan).
- Kadr vaqti: profil rejimida feed scroll'da jank yo'q (o'rta Android qurilma).
- Kontrast AA, touch target ≥ 48.

## 7. Egasi qaror qilishi kerak

1. Logo ranglari qoladimi yoki brend yangilanadimi?
2. Bitta shrift (Manrope) — roziman/yo'q?
3. Feed 2 ustunli bo'lishi — roziman/yo'q?
4. Illyustratsiyalar: dizayner chizadimi yoki tayyor to'plam (bitta uslubda)?
