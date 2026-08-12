# BarterApp — Mukammallik rejasi (Masterplan)

> Bu hujjat loyihani hozirgi holatdan **productionga tayyor**, sayqallangan,
> uyg'un va silliq holatga olib chiqishning to'liq, bosqichma-bosqich rejasi.
> Har bir bosqichda: nima qilinadi, qaysi fayllar, qabul mezoni (nima bo'lsa
> "tayyor" deyiladi). Ish shu tartibda bajariladi va har bosqich oxirida
> `flutter analyze` toza, testlar o'tgan, brauzer/simulyatorda ko'z bilan
> tekshirilgan bo'lishi shart.

Sana: 2026-08-12 · Holat: tahlil tugadi, tozalash bajarildi, ijro boshlanadi.

---

## 0. Hozirgi holat (ikki mashina birlashgandan keyin)

Loyiha ikki agent qo'lidan o'tdi:

- **Bu mashina** (dizayn identifikatsiyasi): issiq palitra, Rubik/Manrope
  shriftlar, girih naqshi, `AuroraBackground` wallpaper, `GlassSurface`
  (liquid glass), `ClayTile` (claymorphism), `SheetSkin` (o'zgaruvchan modal
  foni), qo'lda chizilgan toifa belgilari, Hero-splash uzluksizligi,
  `AsyncFade`, silliqlik tuzatuvlari.
- **Kali mashinasi** (funksional + platforma): WebSocket jonli kanal
  (`live_channel_test`), backend xavfsizlik auditi (`BACKEND_ANALYSIS.md` —
  8 haqiqiy topilma), Android imzo sozlamasi (`proguard-rules.pro`,
  `key.properties.example`), iOS `Info.plist`, ikonkalar, intro overflow
  tuzatuvi (`FittedBox`), `timeAgo`/`formatDate` markazlashuvi, safe-area /
  scroll-physics ishlari.

**Birlashtirilgandan keyin:** musor tozalandi (`.idea/`, `.pyc`), 13 lint
ogohlantirishi 0 ga tushdi, 17 test o'tadi, `flutter analyze` toza.

**Dizayn yo'nalishidagi ziddiyat va qaror.** Kali agentining
`DESIGN_ROADMAP.md` si ilovani umumiy "Google Material 3" tomon burgan
(CircleBorder FAB, tonal palitra). Sizning yo'nalishingiz aksincha: o'ziga
xos, issiq, C segment. **Qaror:** M3 — struktura (tipografiya iyerarxiyasi,
komponent holatlari, adaptiv layout); o'ziga xoslik esa uning ustidagi teri
(wallpaper, glass, clay, girih, issiq palitra). Ikkalasi bir-biriga zid emas
— biri skelet, biri teri. Kod darajasida `BarterPalette` va shriftlar
saqlangani buni tasdiqlaydi.

---

## 1. Yo'l-yo'lakay o'tadigan tamoyillar (har bosqichda amal qilinadi)

Bular alohida bosqich emas — **har bir o'zgarishda** rioya qilinadi:

1. **iOS = Android.** Har qanday imkoniyat ikkala platformada bir xil ishlashi
   shart. Platformaga xos farq faqat fizika (iOS scroll bounce) va tizim
   integratsiyasida (haptics, back-gesture) bo'ladi, funksiyada emas.
2. **Motion hamma joyda.** Splash → intro Hero uzluksizligi qanchalik silliq
   bo'lsa, har bir o'tish, holat almashinuvi, ro'yxat kirishi ham shunday
   bo'lishi kerak. Motion — alohida qo'shimcha emas, standart.
3. **Musor yo'q.** Har kommitdan oldin `git status` — IDE fayli, baytkod,
   ishlatilmagan import, o'lik kod, deprecated API qolmaydi. `flutter analyze`
   har doim 0.
4. **Til to'liq.** Har qanday matn uch tilda (uz/ru/en). Qattiq kodlangan
   inglizcha yo'q.
5. **Test bilan qulflash.** Ko'z bilan ko'rib bo'lmaydigan narsa (silliqlik,
   panel shakli, layout chegarasi) test bilan isbotlanadi.

---

## 2. DIZAYN bosqichlari

### D1 — Bo'limga qarab o'zgaruvchan gradient  ✅ TUGALLANDI

**Muammo:** hozir `swapGradient` (yashil→ko'k) butun ilovada bir xil,
o'zgarmas. Bo'limdan bo'limga o'tganda fon bir xil qoladi — bu ilovani "tekis"
ko'rsatadi.

**Yechim:** har bir asosiy bo'lim o'z gradient identifikatsiyasini oladi va
bo'lim almashganda fon **silliq animatsiya bilan** yangi gradientga o'tadi.

- Asosiy (Home) — yashil→ko'k (barter)
- Mosliklar — oltin→yashil (qiymat topildi)
- Chat — ko'k→binafsha (muloqot)
- Profil — issiq kul→yashil (shaxsiy)

**Fayllar:** `core/theme/tokens.dart` (bo'lim gradientlari),
`core/widgets/backgrounds.dart` (`AuroraBackground` gradientni parametr
oladi), `core/router/app_shell.dart` + `web_shell.dart` (joriy bo'limni
`AnimatedGradient` ga uzatish), yangi `core/widgets/section_gradient.dart`.

**Qabul mezoni:** bo'lim almashganda fon 400–600ms da yangi gradientga
`AnimatedContainer`/`TweenAnimationBuilder` bilan o'tadi; sakramaydi; wallpaper
blomlari ham mos rangga suriladi; test gradient bo'lim bilan o'zgarishini
tekshiradi.

### D2 — Claymorphism kengaytmasi  🔄 medalyonlar clay; profil statistikasi qoldi

Hozir clay faqat web panelida (`ClayTile`). Uni mahsulot bo'ylab tarqatish:

- Toifa medalyonlari — clay (ko'tarilgan), tanlanganda botiq
- Statistika plitkalari (profil), tugmalar guruhi, segment tanlagichlar
- Miqdor/qiymat "steppers", filtr chiplari

**Fayllar:** `core/widgets/glass.dart` (`ClayTile` allaqachon bor),
`core/widgets/common.dart`, tegishli ekranlar. **Muhim chegara:** matn
ko'taradigan katta kartalar clay bo'lMAYDI — o'qilishi atmosferadan muhim.

**Qabul mezoni:** clay faqat interaktiv/kichik yuzalarga; kartalar opaque
qoladi; dark mavzuda ham to'g'ri ko'rinadi (test).

### D3 — Onboarding sayqali + qo'lda sozlanadigan fon

Sizning talabingiz: intro ekranlari mukammal bo'lsin, "keyingi/keyingi"
tugmalari silliq, va **fonni (gradient/rasm) qo'lda o'zgartirsa bo'ladigan**
qilib qo'yish — shaffof rasmlar, grafikalar qo'yish imkoni; shriftlar gap
mazmuni va joylashuviga qarab katta-kichik, mavzuga qarab rangli.

- Har slayd o'z gradient/fon "temasi"ni oladi (D1 tizimidan)
- `SheetSkin` ga o'xshash `IntroSkin` — gradient, wallpaper yoki **custom rasm**
  (shaffof PNG/grafika) qo'yish imkoni; loyiha egasi kelajakda oson
  almashtira oladigan bitta joyda ro'yxat
- Tipografiya konteksti: sarlavha uzunligiga qarab `headlineLarge/Medium`
  avtomatik tanlanadi (`FittedBox`/`AutoSize` mantiqidan); rang mavzuga bog'liq
- "Keyingi" o'tishi — sahifa + illyustratsiya + matn uchun bosqichma-bosqich
  (staggered) motion

**Fayllar:** `features/onboarding/presentation/intro_page.dart`, yangi
`features/onboarding/intro_content.dart` (kontent + fon ta'rifi bir joyda,
oson tahrirlanadi), `core/widgets/backgrounds.dart`.

**Qabul mezoni:** loyiha egasi bitta faylda slayd matnini, gradientini yoki
rasmini almashtira oladi; kichik ekranda overflow yo'q (mavjud
`intro_layout_test` saqlanadi va kengaytiriladi); uch tilda to'g'ri.

### D4 — Motion tizimi (hamma joyda silliqlik)  🔄 asosiy ziddiyat yechildi

Splash sifatidagi silliqlikni standartga aylantirish:

- **Container Transform** (M3): e'lon kartasi → tafsilot (hozir Hero + fade
  bor; uni to'liq container-transform ga yaqinlashtirish)
- Har ekran o'tishi motion tokenlari bilan (`transitions.dart` allaqachon bor
  — `forwardPage`/`risingPage`/`fadePage`/`heroPage`; ularni izchil qo'llash)
- Ro'yxat kirishi (staggered) — `AnimatedListItem` allaqachon; hamma
  ro'yxatga qo'llanganini tekshirish
- Holat almashinuvi (skeleton→kontent) — `AsyncFade` allaqachon; qamrovni
  to'ldirish
- Tugma bosilishi (`Pressable`), tab almashinuvi, panel ochilishi — barchasi
  bir xil egri chiziqlar (`M3Motion`)
- **Predictive back** (Android 14+) — tizim orqaga imo-ishorasiga moslashish

**Qabul mezoni:** hech bir o'tish keskin (bir kadrda) sodir bo'lmaydi; barcha
motion `M3Motion` tokenlaridan; 60fps (silliqlik testi bilan tasdiqlanadi).

### D5 — Tema (light/dark) va tipografiya to'liqligi

- Dark mavzu har ekranda tekshiriladi (glass, clay, gradient, girih)
- Tipografiya iyerarxiyasi izchil: sarlavha/tan/izoh rollari, tabular raqamlar
  narx/sana uchun
- Rang kontrasti WCAG AA (accessibility auditi)

---

## 3. BACKEND bosqichlari (productionga tayyorlik)

Manba: `docs/BACKEND_ANALYSIS.md` — 8 haqiqiy topilma. Tartib xavf darajasi
bo'yicha:

### B1 — OTP xavfsizligi (yuqori)
- OTP so'roviga rate-limit (IP + telefon bo'yicha), `429` + retry vaqti
- OTP kodini bazada hash (HMAC) qilib saqlash, ochiq matn emas
- **Fayllar:** `api/app/api/auth.py`, `api/app/models/user.py`,
  `api/app/core/config.py`

### B2 — Token boshqaruvi (yuqori)
- Refresh token uchun DB jadvali (jti, device, revoked-at, hash)
- Token rotation; `POST /auth/logout` va `/auth/logout-all`
- Access token muddatini qisqartirish (15–60 daqiqa)
- **Fayllar:** `api/app/api/auth.py`, `api/app/core/security.py`, migratsiya

### B3 — Savdo yaxlitligi (o'rta/yuqori)
- `offered_listing_ids` uchun `active` status tekshiruvi
- Parallel deal race: `SELECT ... FOR UPDATE` + atomik status yangilash
- Bog'langan pending offerlarni deal yakunlanganda atomik cancel
- **Fayllar:** `api/app/api/offers.py`, `api/app/services/offers.py`, test

### B4 — Tarmoq/CORS/WS (o'rta)
- `cors_origins` ni middleware'ga ulash; production domenlari env orqali
- WebSocket uchun qisqa umrli socket-token
- **Fayllar:** `api/app/main.py`, `api/app/core/config.py`, `api/app/api/chat.py`

### B5 — Fayl saqlash (past/o'rta)
- Upload cleanup: orphan fayllarni o'chirish; listing o'chirilganda media
- Production uchun S3-mos object storage + lifecycle
- **Fayllar:** `api/app/api/uploads.py`, scheduled job

### B6 — Har topilma uchun test
- Har bir tuzatishga integration/security test (`api/tests/`)

---

## 4. Kod tozaligi (uzluksiz)

- Har kommitdan oldin: `git status`, ishlatilmagan import / o'lik kod / musor
  yo'qligini tekshirish
- `create_listing_page.dart` bir qatorli siqilgan uslubga o'tkazilgan —
  o'qilishi uchun qayta formatlash (sayqal bosqichida)
- Keraksiz fayllar `.gitignore` da; test/analyze har doim yashil

---

## 5. Productionga chiqarish (chegara bilan)

**Men bajara olmaydigan qismlar** (sizning hisoblaringiz, to'lovingiz va imzo
kalitlaringizni talab qiladi — ular sizda qolishi shart):

- Domen sotib olish, hosting, DNS
- Apple Developer / Google Play hisoblari, ilova imzolash, do'konga yuklash

**Men tayyorlab beradigan qismlar:**

- Reliz konfiguratsiyasi (`--dart-define=API_BASE_URL=...`), reliz guard
- Android imzo (`key.properties.example` bor), `proguard-rules.pro`
- iOS ruxsat matnlari (`Info.plist` bor), ikonkalar (bor)
- Do'kon matnlari uch tilda, skrinshotlar, `fastlane` konfiguratsiyasi
- Web build va statik hosting yo'riqnomasi

---

## 6. Ijro tartibi (bosqichma-bosqich)

Har bosqich mustaqil kommit, oxirida analyze+test+ko'z tekshiruvi:

1. **D1** — bo'limga qarab gradient ✅
2. **D4** — motion tizimini izchillashtirish ✅ (karta→tafsilot ziddiyati yechildi; predictive-back qoldi)
3. **D2** — claymorphism kengaytmasi
4. **D3** — onboarding + sozlanadigan fon
5. **D5** — dark tema + tipografiya + accessibility
6. **B1–B2** — OTP + token xavfsizligi
7. **B3** — savdo yaxlitligi
8. **B4–B5** — CORS/WS + fayl saqlash
9. **B6** — xavfsizlik testlari
10. **Production** — reliz tayyorgarligi (men qila oladigan qism)

Har bosqich tugagach shu hujjatda belgilanadi.
