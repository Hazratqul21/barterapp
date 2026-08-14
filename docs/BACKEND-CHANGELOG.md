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

### 🆕🎨 Saqlangan e'lonlar (favorites)

`POST/DELETE /listings/{id}/favorite`, `GET /favorites`.

**Nega:** barterda bu istaklar ro'yxati emas — odam bir necha o'tirishda
qarshi taklif qilishga arzigulik narsalar ro'yxatini yig'adi va shundan
keyin savdoga kiradi. Usiz topilgan e'lon keyingi kirishda yo'qoladi.

**UI da nima kerak:**
- 🎨 Kartada va e'lon sahifasida yurak tugmasi.
- 🎨 Pastki panelda yoki profilda "Saqlanganlar" ro'yxati.
- ⚠️ **`ListingCard` ga `is_favorite` maydoni qo'shildi** va u lentaning
  o'zida keladi — har karta uchun alohida so'rov yubormang. Mehmon uchun
  doim `false`.
- Ikkala tugma ham idempotent: ikki marta bosish xato emas, optimistik UI
  bemalol.
- Arxivlangan e'lonni saqlab bo'lmaydi (`404`), saqlangani ro'yxatdan
  o'zi tushadi. Bloklangan savdogarniki ham yashiriladi va blok yechilgach
  qaytadi — ya'ni "yo'qolib qoldi" degan shikoyat kelmasligi kerak.

---

### 🆕🎨 Bildirishnoma sozlamalari va sokin soatlar

`GET /notification-settings` va `PATCH /notification-settings`.

```json
{ "offers": true, "matches": true, "messages": true, "system": true,
  "quiet_from": 22, "quiet_to": 7 }
```

**Nega:** push qo'shildi, lekin uni boshqarish imkoni yo'q edi. Sokin
soatlarsiz ilova kechasi soat 3 da xabar yuborishi mumkin — bu odam
bildirishnomani butunlay o'chirib qo'yishining eng tez yo'li.

**UI da nima kerak:**
- 🎨 Sozlamalarda to'rtta tugma (Takliflar · Mosliklar · Xabarlar · Tizim)
  va sokin soatlar oralig'i tanlagichi.
- Sozlamaga tegilmagan hisob ham `200` oladi — 404 ni kutmang.
- `quiet_from`/`quiet_to` — **Toshkent vaqti bo'yicha soat** (0–23), sana
  emas. Oraliq yarim tundan o'tadi: `22 → 7` kechasi degani. Tanlagich
  buni qo'llab-quvvatlasin.
- ⚠️ Ikkalasini birga yuboring. Faqat bittasi → `400`.
- ⚠️ **Bu sozlamalar faqat pushni boshqaradi.** Bildirishnomaning o'zi
  baribir yoziladi va ilova ichidagi ro'yxatda ko'rinadi. Ekran matnini
  shunga mos yozing ("Telefonga bildirishnoma"), aks holda odam
  o'chirib qo'yib, keyin ro'yxatda ko'rib chalkashadi.

Sokin soatlarda xabar **yo'qolmaydi** — kutadi va jimlik tugagach ketadi.
Lekin 12 soatdan oshsa tashlanadi: eskirgan "yangi taklif" xabari xabar
emas, shovqin (taklifning o'zi 48 soatda eskiradi).

---

### 🆕🎨 Push-bildirishnoma — qurilma ro'yxati tayyor

Yangi endpointlar: `POST /devices`, `DELETE /devices/{token}`.

```json
POST /devices
{ "token": "<FCM/APNs token>", "platform": "ios|android|web", "locale": "uz" }
→ 204
```

**Nega:** bildirishnoma bazada bor edi, lekin ilova yopiq bo'lganda odam
hech narsa bilmasdi. Barter'da bu jiddiy: taklif 48 soatda eskiradi, odam
esa ilovani ochmagani uchun uni boy beradi.

**UI da nima kerak:**
- Ilova **har ishga tushganda** `POST /devices` chaqirsin. Bu xato emas —
  aynan shu token yangilanganini serverga bildiradigan yagona yo'l.
- Chiqishda (logout) `DELETE /devices/{token}` chaqirilsin, aks holda
  telefondan chiqqan odam bildirishnoma olishda davom etadi.
- 🎨 Sozlamalarda bildirishnomani o'chirish tugmasi — o'chirilganda ham
  `DELETE /devices/{token}`.
- Push ichida `target_type` va `target_id` keladi (`chat` / `listing` /
  `matches` / `verification`). Mijoz shunga qarab to'g'ri ekranni ochsin —
  hammasini lentaga olib borish bildirishnomaning ma'nosini yo'qotadi.
- Bir hisobda bir nechta qurilma bo'lishi mumkin, hammasiga yuboriladi.
- Token boshqa hisobga kirsa, avtomatik ko'chadi (telefon boshqa odamga
  o'tgan holat).

⚠️ **Hozircha xabar haqiqatan yuborilmaydi — logga yoziladi.** Butun navbat
mantiqi tayyor va sinovdan o'tgan, lekin FCM/APNs transporti loyihaning
Firebase hisobini talab qiladi, u esa hali yaratilmagan. Firebase kaliti
paydo bo'lganda faqat bitta sinf almashtiriladi — API va mijoz kodi
o'zgarmaydi. Ya'ni **mijoz tomonni hozirdan yozish mumkin**.

Server tomonda yuborish: `python -m app.push_send` (cron'ga qo'yiladi).

---

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

- **FCM/APNs transporti** — Firebase loyihasi va xizmat kaliti kerak. Bu
  hisob va kalit egasi tomonidan yaratiladi; tayyor bo'lgach transport
  ulanadi va push haqiqatan uchadi.
- **Splash ekranini o'zgaruvchan qilish** — aktivni almashtirish bilan
  yangilanadigan qilish rejalashtirilgan (kod o'zgarmasin).
