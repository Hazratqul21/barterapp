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

## 2026-08-22

### 🔧 Xavfsizlik: chastota chegaralari va so'rov hajmi

Auditda ikkita haqiqiy nuqson topildi va tuzatildi.

**Cheklanmagan yuklash.** `/uploads` da chegara yo'q edi — bitta hisob
soniyada o'nlab surat yuklab, diskni to'ldira olardi. Endi soatiga 60 ta.
Shu bilan birga chegara qo'yilganlar: e'lon joylash (30/soat), taklif
(30/soat), xabar (120/daqiqa), shikoyat (20/soat).

**So'rov tanasi o'qilib, keyin rad etilardi.** 40 MB yuborilsa server uni
to'liq qabul qilib, keyin 12 MB chegarasi bo'yicha 413 qaytarardi — ya'ni
rad etilgan so'rov ham to'liq xotira va diskni band qilardi. Endi
`Content-Length` bo'yicha **o'qishdan oldin** rad etiladi (16 MB).

**UI da nima kerak:** `429` javobini hisobga oling — `Retry-After`
sarlavhasi bor. Foydalanuvchiga "birozdan so'ng urinib ko'ring" deb
ko'rsating, so'rovni jimgina tashlab yubormang.

Chegaralar saxiy: oddiy foydalanish ularga yaqinlashmaydi. Maqsad —
avtomatlashtirilgan suiiste'mol.

---

## 2026-08-18

### 🆕⚠️ Firebase admin paneldan sozlanadi

Panelda yangi bo'lim: **Sozlash**. Ikkita qadam:

1. **Server kaliti** — Firebase service account JSON. Fayl tanlanadi yoki
   mazmuni qo'yiladi. Saqlashdan oldin tekshiriladi va `Kalitni sinash`
   tugmasi Google'dan token so'rab, haqiqatan ishlashini tasdiqlaydi.
2. **Ilova parametrlari** — `api_key`, `app_id`, `messaging_sender_id`,
   `project_id`, `ios_bundle_id`.

Kalit qo'yilgach transport **o'zi almashadi** — serverni qayta ishga
tushirish shart emas.

⚠️ **Kalit qaytarilmaydi.** API faqat "sozlangan/sozlanmagan" va izini
(12 belgi) beradi. Panelga kirgan hisob yoki o'g'irlangan sessiya kalitni
ko'chirib olib keta olmasin — almashtirish uchun yozish yetarli.

**UI da nima kerak — yangi ommaviy endpoint:**

```
GET /config/firebase → { "configured": true, "api_key": "...", ... }
```

- 🎨 Ilova ishga tushganda shuni oladi va `Firebase.initializeApp(options: ...)`
  ga beradi. Ilova ichiga `GoogleService-Info.plist` joylashtirish
  **shart emas** — kalit almashtirilsa yangi reliz kerak bo'lmaydi.
- `configured: false` bo'lsa push o'chirilgan holatda qoladi, ilova
  oddiy ishlashda davom etadi.
- Kirish talab qilinmaydi: bu qiymatlar maxfiy emas, ular baribir har bir
  o'rnatilgan ilova ichida bo'ladi.

⚠️ **Panel qila olmaydigan ikkita narsa** (panelda ham yozilgan):
- **APNs `.p8` kaliti** — Apple Developer hisobidan olinib, Firebase
  konsoliga yuklanadi. Bu Google va Apple o'rtasidagi bog'lanish, server
  undan o'tmaydi.
- **Push entitlement** (`aps-environment`) — ilova ichiga kompilyatsiya
  qilinadi, ya'ni yangi reliz talab qiladi.

Ikkalasi bir marta qilinadi; shundan keyin kalit almashtirish faqat
paneldan bo'ladi.

### 🆕 Panel orqali bildirishnoma yuborish

Panelda yangi bo'lim: **Bildirishnoma**. `POST /admin/push` va
`GET /admin/push/status`.

Segmentlar: hammaga · e'loni borlarga · e'loni yo'qlarga · viloyat
bo'yicha. **Sinov tugmasi** — yubormasdan nechta odamga tegishini
ko'rsatadi.

Matn **har bir odamning o'z tilida** yoziladi (`users.locale` ga qarab),
shuning uchun uch tilda ham matn majburiy.

⚠️ Bu **alohida yo'l emas** — mavjud bildirishnoma navbatiga tushadi.
Ya'ni foydalanuvchining sozlamalari hurmat qilinadi, sokin soatlarda
kutadi, ilova ichidagi ro'yxatda ham ko'rinadi.

⚠️ **Transport hali ulanmagan** — panelda bu ochiq yozilgan. Xabar
navbatga tushadi va logga yoziladi, telefonlarga esa bormaydi. FCM/APNs
uchun Firebase kaliti kerak.

### 🐛 Flutter: Firebase yiqilishi va `/devices` shartnomasi tuzatildi

[FRONTEND-BUGS-RUNTIME.md](FRONTEND-BUGS-RUNTIME.md) R0-1, R1-1, R1-2,
R1-3 yopildi:

- `Firebase.apps.isNotEmpty` bilan himoya — konfiguratsiya yo'q bo'lsa
  push jimgina o'chadi, ilova esa yiqilmaydi.
- `fcm_token` → **`token`**: shartnomaga mos, ya'ni endi 422 emas.
- Platforma haqiqiy qurilmadan aniqlanadi (`ios` qattiq yozilgan edi).
- `onTokenRefresh` tinglanadi — OS token almashtirsa server bilib turadi.
- `forget()` qo'shildi: chiqishda `DELETE /devices/{token}`.
- Xatolar endi logga yoziladi, jimgina yutilmaydi.

⚠️ **Firebase kaliti hali ham kerak.** Kod tayyor va yiqilmaydi, lekin
`GoogleService-Info.plist` / `google-services.json` qo'shilmaguncha push
o'chirilgan holatda qoladi.

---

### 🆕🎨 Admin panel va boshqariladigan lenta

**Panel:** `http://<server>/admin` — bitta sahifa, backend beradi.
Moderator telefon raqami bilan kiradi (huquq `python -m app.grant_moderator`
orqali beriladi). Panelda: lenta bo'laklari, shikoyatlar navbati, tahlil.

**Yangi ommaviy endpoint:** `GET /feed-blocks?slot=...`
**Admin CRUD:** `GET/POST/PATCH/DELETE /admin/feed-blocks`

**Nega:** banner va tanlangan e'lonlar mijoz kodiga qattiq yozilgan edi.
Bayram banneri almashtirish yoki mavsumiy e'lonni tepaga chiqarish uchun
**uch platformaga yangi reliz** kerak bo'lardi — App Store ko'rigi bilan
bir hafta. Mavsum esa bir haftada o'tib ketadi.

**Bo'lak turlari:**

| `kind` | Nima |
|---|---|
| `banner` | Rasm + sarlavha + tugma |
| `promo_listings` | Tahririyat tanlagan e'lonlar qatori |
| `notice` | Matnli chiziq (ogohlantirish, tabrik) |

**Joylar (`slot`):** `feed_top`, `feed_after_categories`, `feed_middle`.

**UI da nima kerak:**
- 🎨 Lenta yuklanganda `GET /feed-blocks` chaqirilsin va bo'laklar
  `slot` bo'yicha joylashtirilsin, `position` bo'yicha tartiblansin.
- `promo_listings` uchun e'lonlar **javobning ichida** to'ldirilgan
  holda keladi — alohida so'rov yubormang.
- `action` + `action_value` bosilganda qayerga borishni aytadi:
  `open_listing` (id), `open_search` (matn), `open_category` (tag kodi),
  `open_url` (havola), `none` (bosilmaydi).
- `background` — `#RRGGBB`. Rasm yuklanmaguncha shu ko'rinadi.
- ⚠️ Server **faqat ko'rinishi kerak bo'lganlarini** qaytaradi.
  O'chirilgani, vaqti kelmagani va muddati o'tgani umuman kelmaydi —
  mijoz qo'shimcha filtr qilmasin.
- ⚠️ Ichi bo'shab qolgan `promo_listings` (e'lonlari arxivlangan) umuman
  qaytmaydi, shuning uchun bo'sh qator chizilmaydi.

**Rejalashtirish:** `starts_at` / `ends_at` ko'rsatilsa, bo'lak o'z
vaqtida o'zi paydo bo'ladi va o'zi yo'qoladi. Filtr **serverda**, chunki
mijozdagi soat xato bo'lishi mumkin va bayram banneri bir kun erta
chiqib ketishi mumkin emas.

---

## 2026-08-15

### 🆕⚠️🎨 Hisobni o'chirish — `DELETE /me`

```json
DELETE /me   { "confirm": true }   → 204
```

**Nega:** [FRONTEND-AUDIT.md](FRONTEND-AUDIT.md) P0-1. Apple 5.1.1(v) va
Google Play talab qiladi: hisob yaratadigan ilova **ilova ichida** hisobni
o'chirish imkonini ham berishi shart. Bu eng tez rad etiladigan bandlardan
biri.

**UI da nima kerak:**
- 🎨 Sozlamalarda "Hisobni o'chirish" — qizil, ro'yxatning oxirida.
- 🎨 **Tasdiqlash oynasi majburiy**: bu qaytarib bo'lmaydigan amal.
  Oynada nima yo'qolishi va nima qolishi aniq yozilsin (pastga qarang) —
  odam nimadan voz kechayotganini bilishi kerak.
- `confirm: true` yuborilmasa server `400` beradi.
- O'chirilgandan keyin **darhol** kirish ekraniga chiqarish va tokenlarni
  tozalash. Eski token 401 qaytaradi.
- ⚠️ Moderator hisobi → `409`.

**Foydalanuvchiga aytiladigan matn uchun:**

| Yo'qoladi | Qoladi |
|---|---|
| Ism, telefon, surat, manzil | Yakunlangan savdolar |
| Barcha e'lonlar (arxivlanadi) | Sharhlar (ikkala tomonda) |
| Ochiq takliflar (bekor bo'ladi) | Suhbatlardagi xabarlar |
| Saqlanganlar, qurilmalar, sozlamalar | |

Telefon raqami bo'shatiladi — o'sha raqam bilan yangi hisob ochish mumkin,
lekin eskisi **tiklanmaydi**.

### ⚠️ `TraderBrief` ga `is_deleted` qo'shildi

O'chirilgan hisob boshqa odamning ekranida (yakunlangan savdo, sharh,
suhbat) hali ham ko'rinadi. Shunda `is_deleted: true` va `name` — `"—"`.

🎨 Mijoz "O'chirilgan foydalanuvchi" matnini **o'z tilida** yozsin va
avatar o'rniga neytral belgi ko'rsatsin. Server buni qila olmaydi, chunki
javob bitta tilda qaytadi.

### 🔧 `POST /events` ga chastota chegarasi

Daqiqasiga 600 hodisa (kirgan odam hisobi bo'yicha, mehmon manzili
bo'yicha). Oshsa `429` + `Retry-After`.

Chegara saxiy — jadal aylantirilgan lenta daqiqasiga 200–300 ko'rsatish
berishi mumkin — lekin mijoz `429` ni ham hisobga olsin: paketni tashlab
yubormasin, keyingi yuborishga qo'shsin.

---

### 🆕🎨 Hodisalar — tahlil va matching uchun poydevor

`POST /events` (kirish talab qilinmaydi) va moderator uchun
`GET /admin/analytics/*`.

**Nega:** hozir bizda faqat **natijalar** bor — taklif yuborildi, savdo
yakunlandi. Yo'q narsalar esa aynan modelga kerak bo'ladiganlar: nima
ko'rsatilib bosilmadi, nima qidirilib topilmadi, qaysi moslik rad etildi.

⚠️ **Buni orqaga qaytib yig'ib bo'lmaydi.** Kod keyin ham yoziladi, model
keyin ham o'rgatiladi, lekin bugun yozilmagan hodisa butunlay yo'qoladi.
Shuning uchun u modeldan **oldin** qurildi va mijoz tomonda ham
imkon qadar tez ulanishi kerak.

**UI da nima kerak:**
- 🎨 Karta ekranda **haqiqatan ko'ringanda** `listing_impression` yuboring
  (ro'yxatga qo'shilganda emas — aks holda ko'rilmagan kartalar ham
  sanaladi va CTR yolg'on chiqadi).
- Hodisalarni **to'plab**, paket bilan yuboring (100 tagacha). Har biri
  uchun alohida so'rov ilovani ham, serverni ham keraksiz yuklaydi.
- ⚠️ **`dedupe_key` ni albatta bering** — mijoz yaratadigan noyob kalit.
  Tarmoq uzilganda paket qayta yuboriladi; kalitsiz ko'rsatishlar ikki
  marta sanaladi va CTR jimgina ikki barobar pasayadi.
- `session_id` — kirmagan odam uchun ham. Ilova ochiq turganda saqlang.
- Javobdagi `duplicates` **xato emas**, muvaffaqiyatli qayta yuborish.
- ⚠️ `payload` ga shaxsiy ma'lumot yozmang (telefon, manzil, xabar matni).

**Mijozdan kutilayotgan turlar:** `listing_impression`, `listing_dwell`,
`filter_applied`, `match_shown`, `match_opened`, `match_dismissed`,
`chat_opened`. Qolganini server o'zi yozadi.

🎨 **UI/UX uchun alohida:** `match_shown` / `match_opened` /
`match_dismissed` — matching algoritmi haqiqatan ishlayaptimi degan savolga
javob beradigan yagona manba. Ularsiz "mosliklar yaxshimi" degan savolga
bugungacha javob yo'q edi.

---

## 2026-08-14

### 🔧⚠️ SMS — Eskiz ulandi

`POST /auth/otp/request` endi haqiqiy SMS yuboradi (kalitlar sozlanganda).

**Nega:** OTP kodi HTTP javobida `debug_code` bo'lib qaytardi. Ishlab
chiqishda bu qulay, ishlab chiqarishda esa **har kim istalgan raqamga kod
so'rab, o'sha hisobga kira olardi**.

**UI da nima kerak:**
- ⚠️ Ishlab chiqarishda `debug_code` **`null`** bo'ladi. Mijoz uni
  ko'rsatishga urinmasin va `null` holatini albatta hisobga olsin — bu
  allaqachon shartnomada bor edi, lekin endi haqiqatan shunday bo'ladi.
- 🆕 Yangi javob kodi: **`503`** — SMS yuborib bo'lmadi. "Qayta urinish"
  tugmasi bilan ko'rsating. (`SMS_REQUIRED=true` bo'lganda.)
- `sent: false` — kod yaratildi, lekin SMS ketmadi. `SMS_REQUIRED=false`
  holatida shunday bo'ladi.

Server tomonda: kalitlar `.env` da (`ESKIZ_EMAIL`, `ESKIZ_PASSWORD`,
`ESKIZ_SENDER`, `ESKIZ_OTP_TEMPLATE`). Bo'sh bo'lsa quruq rejim.

⚠️ **Eskiz har bir matnni oldindan tasdiqlaydi.** Tasdiqlanmagan matn xato
bermaydi — jimgina yetkazilmaydi. Shuning uchun matn `.env` da turadi va
kabinetdagi tasdiqlangan shakl bilan harf-baharf bir xil bo'lishi kerak.

---

### 🆕 Moderator navbati (xodimlar uchun, oddiy ilovada emas)

`GET /admin/reports`, `PATCH /admin/reports/{id}`,
`POST /admin/listings/{id}/archive`.

**Nega:** shikoyat yozilardi-yu, uni hech kim ko'ra olmasdi. Ya'ni tugma
bor edi, orqasida hech narsa yo'q.

**UI da nima kerak:** ilovaning o'zida **hech narsa**. Bu alohida ichki
panel uchun. Agar keyinchalik ilova ichiga qo'shilsa:
- Moderator bayrog'i yo'q hisobga bu endpointlar **404** qaytaradi, 403
  emas. Mijoz "huquq yo'q" ekranini emas, "topilmadi" ni ko'rsatsin.
- Bayroq faqat serverdan beriladi (`python -m app.grant_moderator`). Uni
  beradigan endpoint yo'q va bo'lmaydi.

Navbat eskisidan boshlanadi. `target_label` va `report_count` javobda
keladi, ya'ni ro'yxat qo'shimcha so'rovlarsiz o'qiladi.

---

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
