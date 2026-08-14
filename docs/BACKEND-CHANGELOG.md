# Backend o'zgarishlar jurnali

> **Bu fayl kim uchun:** frontend (Flutter) va UI/UX uchun. Backendda nima
> paydo bo'lgani, nima o'zgargani va **mijoz tomonda nima qilish kerakligi**
> shu yerda yoziladi.
>
> To'liq shartnoma — [API.md](API.md). Bu fayl esa "nima yangi va menga nima
> qilish kerak" savoliga javob beradi.
>
> **Tartib:** eng yangisi tepada. Har bandda uchta narsa bor — nima
> o'zgardi, nega, va **UI da nima kerak**.

---

## Belgilar

| Belgi | Ma'nosi |
|---|---|
| 🆕 | Yangi imkoniyat — ekran/oqim kerak |
| ⚠️ | **Buzuvchi o'zgarish** — eski kod ishlamay qoladi |
| 🎨 | UI/UX qarori kerak |
| 🔧 | Ichki tuzatish — mijozga ta'sir qilmaydi |

---

## 2026-08-14

### ⚠️🎨 Xato javoblari — 500 endi `request_id` tashiydi

500 javobi shu shaklga keldi:

```json
{ "detail": "Serverda kutilmagan xatolik...", "request_id": "a9ee31a85588" }
```

**Nega:** ilgari qayta ishlanmagan xato CORS sarlavhasisiz qaytardi, shuning
uchun brauzerda **har qanday** server xatosi "CORS error" bo'lib ko'rinardi.
Haqiqiy sabab faqat server logida qolardi va topib bo'lmasdi.

**UI da nima kerak:**
- Xato ekranida `request_id` ni kichik kulrang matn bilan ko'rsatish (yoki
  "nusxa olish"). Foydalanuvchi skrinshot yuborsa, sabab shu id orqali
  topiladi.
- 🎨 Bu UI/UX uchun kichik, lekin qadrli detal: qo'llab-quvvatlash oqimini
  butunlay o'zgartiradi.
- Agar bundan keyin ham CORS xatosi ko'rsangiz — bu **haqiqiy** CORS
  muammosi, 500 ning niqobi emas.

### 🔧 `/health` endi bazani tekshiradi

Baza yiqilsa `503 {"status":"degraded"}`. Ilgari har doim `ok` qaytarardi.
Mijozga ta'sir qilmaydi — deploy va monitoring uchun.

---

### 🆕🎨 Bloklash va shikoyat

Yangi endpointlar: `POST/DELETE /blocks/{user_id}`, `GET /blocks`,
`POST /reports`. Batafsil — [API.md § 7.7](API.md).

**Nega:** ilovada odamni bloklash ham, shikoyat qilish ham umuman yo'q edi.
Bu App Store va Google Play uchun **majburiy** talab: foydalanuvchi kontenti
bor ilovada shikoyat va bloklash mexanizmi bo'lmasa, ilova rad etiladi.

**UI da nima kerak:**
- Savdogar profilida va e'lon sahifasida "⋯" menyusi → **Bloklash** va
  **Shikoyat qilish**.
- Shikoyat sababini tanlash oynasi: `spam` / `scam` / `offensive` / `fake` /
  `illegal` / `other` + ixtiyoriy izoh (1000 belgigacha).
- Sozlamalarda **"Bloklangan foydalanuvchilar"** ro'yxati (`GET /blocks`),
  har birida "blokni yechish".
- 🎨 **Muhim UX nuqtasi:** bloklangan odam bilan eski suhbat **o'qiladi**,
  lekin yozib bo'lmaydi (`403`). Yozish maydonini o'chirib qo'ying va
  sababini yozing — aks holda odam xabar yozadi, `403` oladi va nima
  bo'layotganini tushunmaydi.
- 🎨 Takroriy shikoyat `201` qaytaradi (birinchisi o'zgarishsiz). Buni xato
  deb ko'rsatmang — "shikoyatingiz qabul qilindi" deyavering.
- ⚠️ Sizni bloklagan odamni siz "unblock" qila olmaysiz. Faqat
  `GET /blocks` dagilarni yechiladigan qilib ko'rsating, aks holda
  "blokni yechdim, nega hali ham ko'rinmaydi?" holati chiqadi.

---

### 🆕🎨 Lenta: filtr, saralash va barcha tillarda qidiruv

`GET /listings` ga yangi parametrlar: `min_value`, `max_value`, `region`,
`cash_ok`, `sort=new|cheap|expensive`.

**Nega:** filtr ham, saralash ham umuman yo'q edi. Qidiruv esa tilga
qulflangan edi — `Accept-Language: ru` bo'lsa faqat ruscha tarjimada
qidirardi, natijada rus tilida yurgan odam o'zbekcha so'z yozsa (mahsulot
nomini yarim mamlakat shunday yozadi) e'lon shundoq turgan holda **bo'sh
lenta** olardi.

**UI da nima kerak:**
- 🎨 Filtr paneli/sheet: narx oralig'i slideri, viloyat tanlagichi
  (`GET /regions`), "pul qo'shsa bo'ladi" tugmasi.
- 🎨 Saralash tanlagichi: Yangi · Arzon · Qimmat.
- ⚠️ **Filtr yoki saralash o'zgarganda `cursor` ni tashlang va ro'yxatni
  noldan yuklang.** Kursor o'zi saralanayotgan kalitni tashiydi, shuning
  uchun `sort=new` dan olingan kursorni `sort=cheap` bilan yuborish
  mantiqsiz sahifa beradi.
- `min_value`/`max_value` — **minor birlikda** (`value.minor` bilan bir xil).
- `min_value > max_value` → `400`.
- Qidiruvda foydalanuvchini "tilni to'g'rilang" deb cheklamang — endi
  kerak emas.

---

### 🆕 E'lonni tahrirlash va arxivlash

`PATCH /listings/{id}` va `DELETE /listings/{id}`.

**Nega:** e'lon bir marta yozilib, boshqa hech qachon o'zgartirilmasdi.
Xato narx yozgan odam uchun yagona chora — yangi e'lon joylash edi.

**UI da nima kerak:**
- E'lon sahifasida (egasi uchun) "Tahrirlash" va "O'chirish".
- ⚠️ `photos`, `wants`, `desires` — **butunlay almashtiriladi**, qo'shilmaydi.
  Bitta surat qo'shish uchun to'liq ro'yxatni yuboring.
- 🎨 `409` holati: jonli taklif bo'lsa tahrirlab bo'lmaydi. "Avval
  takliflarni yakunlang" deb tushuntiring — bu ataylab qilingan, chunki
  taklif kelgandan keyin e'lon matnini o'zgartirish qarshi tomonni aldash
  bo'ladi.
- O'chirish — yumshoq (`archived`), ma'lumot yo'qolmaydi.

---

### 🆕 `GET /categories`

Kategoriya ro'yxati uch tilda, rasm URL'lari bilan.

**Nega:** kategoriya nomlari mijozda hardcode qilingan edi, shuning uchun
RU/EN tillarida o'zbekcha nomlar ko'rinardi. Rasm URL'larining bir qismi
esa allaqachon o'lik (404) edi.

**UI da nima kerak:** mijozdagi hardcode ro'yxatni o'chirib, shu endpointdan
olish. `id` to'g'ridan-to'g'ri `GET /listings?tag=` ga beriladi.

---

### ⚠️ WebSocket endi chipta talab qiladi

`WS /ws?token=` ga **access token yuborilmaydi** — rad etiladi. Avval
`GET /ws-ticket` chaqiriladi, qaytgan qisqa muddatli chipta soketga
beriladi.

**Nega:** brauzer WebSocket handshake'ida header qo'ya olmaydi, shuning
uchun token URL'ga tushardi — URL esa server loglarida, proksi yozuvlarida
va brauzer tarixida qoladi.

**UI da nima kerak:**
- Ketma-ketlik: `GET /ws-ticket` → darhol `WS /ws?token=<ticket>`.
- Ulanish uzilsa chiptani **qaytadan** oling. Chipta bir necha soniya
  yashaydi, uni saqlab qo'yish ishlamaydi.

---

## Ochiq savollar / kutilayotgani

- **Push-bildirishnoma** — backendda ishlanmoqda. Mijozdan qurilma tokenini
  ro'yxatdan o'tkazish kerak bo'ladi; endpoint tayyor bo'lgach shu yerga
  yoziladi.
- **Splash ekranini o'zgaruvchan qilish** — aktivni almashtirish bilan
  yangilanadigan qilish rejalashtirilgan (kod o'zgarmasin).
