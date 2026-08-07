# API shartnomasi — BarterApp

**Bu hujjat mijoz (Flutter) va server o'rtasidagi yagona shartnoma.** Mijozni
yozayotgan har kim faqat shu yerga qarab ishlashi kerak — baza tuzilishini
bilishi shart emas.

- Asos manzil (dev): `http://127.0.0.1:8010`
- Jonli hujjatlar: `http://127.0.0.1:8010/docs` (Swagger UI, sinab ko'rish mumkin)
- Mashina o'qishi uchun: `http://127.0.0.1:8010/openapi.json`

---

## 0. Umumiy qoidalar

### 0.1 Har bir so'rovda ikkita header

```http
Accept-Language: uz          # uz | ru | en — javob SHU tilda keladi
Authorization: Bearer <access_token>    # kirish talab qilinadigan joylarda
```

⚠️ **Server javobni bitta tilda qaytaradi.** Mijoz uch tilni bir vaqtda olmaydi
va tarjimani o'zi tanlamaydi. `Accept-Language` ni har so'rovga qo'yish —
mijozning asosiy majburiyati.

### 0.2 Pul har doim shu shaklda

```json
{ "minor": 630000000, "currency": "UZS" }
```

`minor` — **tiyin** (1/100 so'm). `630000000` = 6 300 000 so'm.

Formatlash mijozda: `NumberFormat.simpleCurrency(locale: 'uz', name: 'UZS')`.
Server hech qachon `"6 300 000 so'm"` kabi matn yubormaydi.

### 0.3 Sana

ISO 8601, UTC: `"2026-08-04T09:12:48.089119+00:00"`.
Mijoz `DateTime.parse()` qiladi va `DateFormat` bilan ko'rsatadi.
Server `"2 kun oldin"` kabi matn yubormaydi.

### 0.4 Ro'yxatlar — kursorli

```json
{ "items": [ ... ], "next_cursor": "MjAyNi0wOC0wNC4uLg==" }
```

Keyingi sahifa: `?cursor=<next_cursor>`. `next_cursor: null` — oxiri.
**Offset ishlatilmaydi**, chunki lenta doim o'zgarib turadi.

### 0.5 Xatolar

```json
{ "detail": "Faqat taklif kelgan tomon bu amalni bajara oladi." }
```

`detail` — **to'g'ridan-to'g'ri foydalanuvchiga ko'rsatiladigan matn**,
o'zbekchada va odam tilida. Mijoz uni o'zgartirmasdan ekranga chiqaradi.

| Kod | Ma'nosi | Mijoz nima qiladi |
|---|---|---|
| 400 | So'rov noto'g'ri | `detail` ni ko'rsatadi |
| 401 | Token yo'q yoki eskirgan | Kirish ekraniga yuboradi |
| 402 | Bepul e'lon kvotasi tugadi | Tarif ekranini taklif qiladi |
| 404 | Topilmadi | «Topilmadi» holati |
| 409 | Holat mos emas (masalan, qabul qilib bo'lmaydi) | `detail` ni ko'rsatadi |
| 422 | Validatsiya (masalan, tarjima yetishmaydi) | Maydon ostida xato |
| 429 | Juda ko'p urinish | Kutishni aytadi |

---

## 1. Autentifikatsiya

### `POST /auth/otp/request`

```json
→ { "phone": "+998901234122" }
← { "sent": true, "expires_in": 300, "debug_code": "482910" }
```

⚠️ `debug_code` **faqat ishlab chiqishda** keladi (SMS provayderi hali yo'q).
Ishlab chiqarishda `null` bo'ladi. Mijoz uni ko'rsatsa ham bo'ladi, lekin
`null` holatini albatta hisobga olsin.

`phone` formati: `^\+998\d{9}$`.

### `POST /auth/otp/verify`

```json
→ { "phone": "+998901234122", "code": "482910" }
← { "access_token": "eyJ...", "refresh_token": "eyJ...",
    "token_type": "Bearer", "is_new_user": false }
```

- Kod 5 daqiqa yashaydi, 5 marta xato → `429`.
- Birinchi kirishda foydalanuvchi avtomatik yaratiladi → `is_new_user: true`.
  Mijoz bu holatda ism so'raydigan ekranga yuborishi kerak (`PATCH /me`).

### `POST /auth/refresh`

```json
→ { "refresh_token": "eyJ..." }
← { "access_token": "...", "refresh_token": "...", "token_type": "Bearer" }
```

`access_token` 24 soat, `refresh_token` 60 kun yashaydi.

---

## 2. Profil

### `GET /me` 🔒

```json
{
  "id": "uuid", "name": "Jasur Toshmatov", "handle": "Oq Yer Agro",
  "phone": "+998901234122", "avatar_url": "https://...",
  "is_verified": true, "rating": 4.7, "review_count": 3, "deals": 3,
  "is_online": true, "last_seen_at": "2026-08-04T...",
  "cover_url": null, "bio": "...", "location": "Samarqand · Kattaqo‘rg‘on",
  "joined_at": "2026-06-01T...", "completion_rate": 100,
  "responds_within_minutes": 120,
  "first_name": "Jasur", "last_name": "Toshmatov",
  "region": "Samarqand", "district": "Kattaqo‘rg‘on", "address": "...",
  "locale": "uz", "trust_score": 92,
  "active_listings": 2, "completed_trades": 3
}
```

⚠️ **`name` va `handle` ni farqlang.** `name` — odamning ismi, `handle` — biznes
nomi. Ekranda `"$name · $handle"` ko'rinishida chiqaring, **hech qachon faqat
`handle`** — aks holda savdogar ismsiz qoladi.

### `PATCH /me` 🔒

```json
→ { "first_name": "Jasur", "last_name": "Toshmatov",
    "region": "Samarqand", "district": "...", "address": "...",
    "avatar_url": "https://...", "locale": "ru" }
← (GET /me bilan bir xil)
```

Faqat yuborilgan maydonlar o'zgaradi.

### `GET /me/listings` 🔒 → `ListingCard[]`

O'z e'lonlarim, **barcha statusda** (lentada faqat `active` ko'rinadi).

### `GET /users/{user_id}` → `TraderProfile`

Ommaviy savdogar profili. `GET /me` bilan bir xil, lekin telefon/manzilsiz.

### `GET /users/{user_id}/listings` → `ListingCard[]`

Faqat `active`.

### `GET /users/{user_id}/reviews` → `ReviewOut[]`

```json
[{ "id": "uuid", "rating": 5, "body": "Hammasi kelishilganidek bo‘ldi.",
   "created_at": "...", "author_id": "uuid",
   "author_name": "Dilnoza Yusupova", "author_avatar_url": "https://..." }]
```

⚠️ Faqat **shu savdogar haqidagi** sharhlar. O'ziga yozganlari yo'q — baza
darajasida taqiqlangan.

---

## 3. Lenta va e'lonlar

### `GET /listings`

| Parametr | Tur | Izoh |
|---|---|---|
| `tag` | enum | `agri`\|`livestock`\|`machinery`\|`transport`\|`electronics`\|`construction` |
| `q` | string | Sarlavha, tavsif, kategoriya bo'yicha qidiruv |
| `cursor` | string | Oldingi javobdagi `next_cursor` |
| `limit` | int | 1–50, standart 20 |

```json
{
  "items": [{
    "id": "uuid", "tag": "machinery",
    "title": "MTZ-892 traktor, 2019",
    "image_url": "https://...", "image_alt": "Dalada turgan ko‘k traktor",
    "wants_summary": "Don / Chorva",
    "value": { "minor": 1499400000, "currency": "UZS" },
    "distance_km": 34.2,
    "cash_ok": true, "is_premium": true,
    "posted_at": "2026-08-03T...",
    "owner": {
      "id": "uuid", "name": "Sardor Choriyev", "handle": null,
      "avatar_url": "https://...", "is_verified": true,
      "rating": 4.5, "deals": 2, "is_online": false,
      "last_seen_at": "2026-08-04T05:00:00+00:00"
    }
  }],
  "next_cursor": null
}
```

⚠️ Ikki muhim xatti-harakat:
- **Kirgan foydalanuvchining o'z e'lonlari lentada ko'rinmaydi.**
- `distance_km` faqat ikkala tomonda koordinata bo'lsa keladi, aks holda `null`.
  Mijoz `null` bo'lsa masofani umuman ko'rsatmasin.

### `GET /listings/{listing_id}` → `ListingDetail`

`ListingCard` + qo'shimcha:

```json
{
  "status": "active",
  "description": "4200 soat ishlagan, ikkinchi egasi...",
  "category": "Texnika", "condition": "Yaxshi holatda", "quantity": "1 dona",
  "gallery": ["https://...", "https://..."],
  "wants": ["Don (30+ tonna)", "Qoramol", "Yuk mashinasi"]
}
```

`status`: `draft` | `active` | `in_negotiation` | `completed` | `archived`.

### `POST /listings` 🔒 → `ListingDetail` (201)

```json
{
  "tag": "agri",
  "title":         { "uz": "...", "ru": "...", "en": "..." },
  "description":   { "uz": "...", "ru": "...", "en": "..." },
  "image_alt":     { "uz": "...", "ru": "...", "en": "..." },
  "category":      { "uz": "...", "ru": "...", "en": "..." },
  "condition":     { "uz": "...", "ru": "...", "en": "..." },
  "quantity":      { "uz": "...", "ru": "...", "en": "..." },
  "wants_summary": { "uz": "...", "ru": "...", "en": "..." },
  "wants": [ { "uz": "...", "ru": "...", "en": "..." } ],
  "photos": ["https://...", "https://..."],
  "value": { "minor": 630000000, "currency": "UZS" },
  "cash_ok": true,
  "latitude": null, "longitude": null
}
```

⚠️ **Uch til ham majburiy.** Bittasi bo'sh bo'lsa `422`. Bu ataylab: yarim
tarjima qilingan e'lon lentaga tushmasligi kerak.

- `latitude`/`longitude` bo'sh bo'lsa foydalanuvchi profilidan olinadi.
- `402` qaytishi mumkin: bepul e'lon kvotasi tugagan (`free_listings_left`).
  Biznes hisoblar kvotadan ozod.

---

## 4. Takliflar — mahsulotning markazi

### Holat mashinasi

```
                  ┌──────────── counter ◀────────┐
                  ▼                              │
draft ──▶ pending ──▶ talking ──▶ accepted ──▶ completed ──▶ (sharh ochiladi)
            │            │            │
            ├─ declined  ├─ declined  └─ disputed ──▶ refunded
            └─ expired (48 soat)
```

| Amal | Qaysi holatdan | Natija | Kim bosa oladi |
|---|---|---|---|
| `accept` | pending, talking | accepted | **faqat taklif kelgan tomon** |
| `decline` | pending, talking | declined | **faqat taklif kelgan tomon** |
| `counter` | pending, talking | talking | ikkalasi |
| `complete` | accepted | completed | ikkalasi |
| `dispute` | accepted | disputed | ikkalasi |

⚠️ `counter` **tomonlarni almashtiradi**: javob bergan odam endi yuboruvchi
bo'ladi. Shuning uchun mijoz `is_mine` ni har javobdan keyin qayta o'qishi kerak.

Noto'g'ri amal → `409` va tushunarli `detail`.

### `POST /offers` 🔒 → `OfferOut` (201)

```json
→ {
  "listing_id": "uuid",                    // nimani xohlayapman
  "offered_listing_ids": ["uuid"],         // nimani beryapman (1–5 ta)
  "cash_delta_minor": 126000000,           // ustiga qo'shadigan pul (tiyin)
  "currency": "UZS",
  "message": "MacBook + 1.26 mln ga almashamizmi?"   // ixtiyoriy
}
```

Taklif yaratilishi bilan **avtomatik chat ochiladi** (`conversation_id`).

### `GET /offers` 🔒 → `OfferOut[]`
### `GET /offers/{offer_id}` 🔒 → `OfferOut`

```json
{
  "id": "uuid", "status": "pending",
  "cash_delta_minor": 126000000, "currency": "UZS",
  "created_at": "...", "expires_at": "...",
  "is_mine": true,
  "counterparty": { TraderBrief },
  "wanted":  { ListingCard },
  "offered": [ { ListingCard } ],
  "conversation_id": "uuid"
}
```

### `PATCH /offers/{offer_id}` 🔒 → `OfferOut`

```json
→ { "action": "counter", "cash_delta_minor": 150000000, "message": "1.5 mln bo‘lsa roziman." }
```

`action`: `accept` | `decline` | `counter` | `complete` | `dispute`.

`complete` bo'lganda **ikkala e'lon ham `completed` bo'ladi** va lentadan
chiqadi.

---

## 5. Chat

### `GET /conversations` 🔒 → `ConversationSummary[]`

```json
[{
  "id": "uuid",
  "peer": { TraderBrief },
  "offer_id": "uuid", "offer_status": "pending",
  "deal_summary": "MacBook Pro 14\" + 1 260 000 UZS ↔ iPhone 13 · 256 GB",
  "last_message": "Shanba kuni ko‘rishsak bo‘ladimi?",
  "last_message_at": "2026-08-04T...",
  "unread": 2
}]
```

`deal_summary` — server tayyorlab beradigan bitta qator. Mijoz uni o'zi
yig'masin.

### `GET /conversations/{thread_id}` 🔒 → `ConversationDetail`

`ConversationSummary` + `offer` (to'liq `OfferOut`) + `messages`.

⚠️ **Bu endpoint chaqirilishi bilan xabarlar o'qilgan deb belgilanadi.**
Shuning uchun orqaga qaytganda inbox'dagi badge o'zi yo'qoladi — mijoz
alohida hech nima qilmasin, faqat `conversationsProvider` ni yangilasin.

```json
"messages": [{
  "id": "uuid", "body": "Salom!", "photo_url": null,
  "created_at": "...", "sender_id": "uuid", "is_mine": false
}]
```

### `GET /conversations/{thread_id}/peer` 🔒 → `TraderBrief`

Suhbatdoshning joriy holati — onlayn, oxirgi kirish, reyting. Chat sarlavhasini
xabarlarni qayta yuklamasdan yangilash uchun.

### `POST /conversations/{thread_id}/messages` 🔒 → `MessageOut` (201)

```json
→ { "body": "Kelishdik!", "photo_url": null }
```

### `WS /ws?token=<access_token>`

⚠️ Token **query parametrda** — brauzer WebSocket handshake'ida header
qo'ya olmaydi.

Serverdan keladigan hodisalar:

```json
{ "type": "message", "conversation_id": "uuid", "message": { MessageOut } }
{ "type": "typing",  "conversation_id": "uuid", "user_id": "uuid" }
```

Mijozdan yuboriladigan:

```json
{ "type": "typing", "conversation_id": "uuid" }
```

**Butun ilovada bitta soket bo'lsin.** Har chat o'ziniki ochsa, 10 chat = 10 ulanish.

---

## 6. Mosliklar

### `GET /matches` 🔒 → `MatchOut[]`

```json
[{
  "id": "uuid", "score": 76,
  "reason": "Qiymatlar yaqin — toza almashinuv chiqadi.",
  "mine":   { ListingCard },
  "theirs": { ListingCard },
  "owner":  { TraderBrief }
}]
```

- `score` 0–100. Ball: narx 40% · hudud 30% · reyting 20% · kategoriya 10%.
- `owner` — **doim `theirs` e'lonining egasi**. Mijoz uni alohida hisoblab
  o'tirmasin.
- Chaqirilganda mosliklar kerak bo'lsa qayta hisoblanadi (5 daqiqada bir marta).

### `POST /matches/{match_id}/dismiss` 🔒 → `204`

O'tkazib yuborilgan moslik **qaytib chiqmaydi**.

---

## 7. Bildirishnomalar

### `GET /notifications` 🔒 → `NotificationOut[]`

```json
[{
  "id": "uuid", "kind": "offer",
  "title": "Bekzod Karimov taklif yubordi",
  "body": "MacBook Pro 14\" ↔ iPhone 13",
  "avatar_url": "https://...",
  "created_at": "...", "is_unread": true,
  "target_type": "chat", "target_id": "uuid"
}]
```

⚠️ **Manzil `target_type` + `target_id` da.** `kind` dan taxmin qilmang —
prototipdagi eng katta xatolardan biri shu edi.

| `target_type` | Mijoz qayerga o'tadi |
|---|---|
| `chat` | `/chat/{target_id}` |
| `matches` | Mosliklar tab'i (`target_id` bo'sh) |
| `verification` | Tasdiqlash ekrani |
| `listing` | `/listing/{target_id}` |

`kind` (`offer`\|`match`\|`message`\|`system`) faqat **ikonka va rang** uchun.

### `POST /notifications/read` 🔒 → `204`

```json
→ { "ids": [] }        // bo'sh ro'yxat = hammasi
→ { "ids": ["uuid"] }  // faqat tanlanganlar
```

---

## 8. Tasdiqlash va to'lovlar

### `GET /me/verification` 🔒

```json
{
  "trust_score": 92,
  "steps": [
    { "step": "phone",    "state": "done",    "hint": "SMS orqali tasdiqlangan", "weight": 20 },
    { "step": "passport", "state": "done",    "hint": "Pasport yoki JSHSHIR",    "weight": 25 },
    { "step": "business", "state": "done",    "hint": "Korxona hujjatlari",      "weight": 25 },
    { "step": "bank",     "state": "pending", "hint": "Escrow to‘lovlari uchun", "weight": 20 },
    { "step": "video",    "state": "todo",    "hint": "30 soniyalik selfie",     "weight": 10 }
  ]
}
```

`state`: `todo` | `pending` | `done`.
`trust_score` = tasdiqlangan bosqichlar vaznlari yig'indisi.

### `POST /me/verification/{step}` 🔒 → `VerificationOut`

Bosqichni `pending` ga o'tkazadi. Allaqachon `done` bo'lsa → `409`.

### `GET /me/payment-methods` 🔒 → `PaymentMethodOut[]`

```json
[{ "id": "uuid", "brand": "Humo", "label": "Oq Yer Agro · korporativ",
   "last4": "4412", "expires": "09/28", "is_primary": true }]
```

⚠️ Server **faqat oxirgi 4 raqamni** biladi. To'liq karta raqami hech qachon
bu servisga kelmaydi.

### `POST /me/payment-methods/{card_id}/primary` 🔒 → `PaymentMethodOut[]`
### `DELETE /me/payment-methods/{card_id}` 🔒 → `PaymentMethodOut[]`

Asosiy kartani o'chirsangiz, qolganidan biri avtomatik asosiy bo'ladi.
Ikkalasi ham **yangilangan to'liq ro'yxatni** qaytaradi — mijoz qayta so'rov
qilmasin.

### `GET /me/settlements` 🔒 → `SettlementOut[]`

```json
[{ "offer_id": "uuid",
   "amount": { "minor": 126000000, "currency": "UZS" },
   "counterparty_name": "Bekzod Karimov",
   "settled_at": "...", "outgoing": true }]
```

`outgoing: true` — pul mendan chiqdi (`−`), `false` — menga tushdi (`+`).

---

## 9. Sinash

```bash
# Kirish va token olish
CODE=$(curl -s -X POST localhost:8010/auth/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+998901234122"}' | jq -r .debug_code)

TOK=$(curl -s -X POST localhost:8010/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d "{\"phone\":\"+998901234122\",\"code\":\"$CODE\"}" | jq -r .access_token)

# Lenta, ruscha
curl -s localhost:8010/listings -H "Accept-Language: ru" -H "Authorization: Bearer $TOK" | jq
```

Butun savdo aylanishini tekshiradigan tayyor test:

```bash
cd api && .venv/bin/python tests/test_trade_loop.py
```

Demo hisoblar (hammasida OTP javobda qaytadi):

| Telefon | Kim |
|---|---|
| `+998901234122` | Jasur Toshmatov · Oq Yer Agro (biznes, Samarqand) |
| `+998901110001` | Sardor Choriyev (Jomboy) |
| `+998901110002` | Bekzod Karimov · Yog'och Ustaxona (biznes, Toshkent) |
| `+998901110003` | Nodir Rasulov (Zomin) |
| `+998901110004` | Dilnoza Yusupova (Quva) |
