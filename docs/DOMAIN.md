# Biznes mantiq — BarterApp

Mahsulot **nima uchun** shunday ishlaydi. Kod emas, qarorlar va sabablar.
Yangi funksiya qo'shayotganda avval shu yerga qarang — ehtimol javob bor.

---

## 1. Mahsulotning o'zagi

> **«Menda ortiqcha X bor, menga Y kerak.»**

OLX «sotaman» deydi, BarterApp «almashtiraman» deydi. Bu bitta jumla butun
mahsulotni belgilaydi:

- Har bir e'lonning **ikki tomoni** bor: `give` va `take`.
- Qidiruv emas, **moslashtirish** asosiy.
- Pul — tovarning o'rnini bosuvchi emas, **farqni yopuvchi**.

Har qanday yangi ekran shu savolga javob berishi kerak: *bu foydalanuvchiga
kimning nimasi kerakligini tushunishga yordam beradimi?*

---

## 2. Foydalanuvchi segmentlari

| Segment | Misol | Nima muhim |
|---|---|---|
| **Yirik B2B** | Sement zavodi sement berib, ishchilariga go'sht oladi | Katta hajm, STIR, korporativ karta |
| **O'rta/kichik B2B** | Fermerda 40 t guruch, unga traktor kerak | Mavsumiylik, hudud, transport narxi |
| **C2C** | Uyda yotgan noutbukni remontga almashtirish | Tez, oddiy, ishonch muhim |

Modelda: `users.user_type` = `individual` | `business`.
Biznes hisobda `tax_id` (STIR) **majburiy** — baza cheklovi bilan.

---

## 3. Savdoning hayoti

### 3.1 Holat mashinasi

```
draft ──▶ pending ──counter──▶ talking ──counter──▶ pending
            │                     │
            ├─ accept ────────────┴──▶ accepted
            │                              │
            ├─ decline ──▶ declined        ├─ complete ──▶ completed ──▶ sharh
            └─ 48 soat ──▶ expired         └─ dispute ───▶ disputed ──▶ refunded
```

**Kim nima qila oladi** — `api/app/services/offers.py` → `TRANSITIONS`:

| Amal | Kim |
|---|---|
| `accept`, `decline` | Faqat taklif **kelgan** tomon |
| `counter`, `complete`, `dispute` | Ikkalasi |

### 3.2 `counter` tomonlarni almashtiradi

Qarshi taklif — bu **yangi taklif**, faqat teskari yo'nalishda. Shuning uchun
`from_user_id` va `to_user_id` o'rin almashadi.

**Nega muhim:** shundan keyin `accept` tugmasi narigi tomonda paydo bo'ladi.
Busiz ikkalasi ham «qabul qilaman» deb bosaverib, hech kim javobgar bo'lmaydi.

### 3.3 Nima uchun taklif markazda

Chat, escrow, bildirishnoma, sharh — **hammasi taklif statusidan kelib chiqadi**,
har biri o'zining holatini yuritmaydi:

- Chat taklif bilan **birga** yaratiladi (bittasiz ikkinchisi bo'lmaydi).
- `completed` bo'lgandagina sharh yozish ochiladi.
- Sharh `offer_id` ga bog'lanadi → bir savdoga bir sharh.
- `completed` ikkala e'lonni yopadi → lentadan chiqadi.

---

## 4. Matching — mahsulotning yuragi

### 4.1 Ikki bosqich

```
1. FILTR    — bu narsa umuman kerakmi?      wanted()
2. SARALASH — keraklilar orasida qaysi biri? score_pair()
```

**Nega filtr alohida?** Biznes rejada kategoriya 10% vazn oladi. Bu saralash
uchun to'g'ri, lekin **qabul qilish** uchun emas. Sinovda: noutbuk (1.49 mln)
va 6 tonna makkajo'xori (1.66 mln) — narx yaqin, ikkalasi Samarqand atrofida,
sotuvchi reytingi yaxshi. Natija: **85% moslik**. Noutbukni makkajo'xoriga.

Hech kim so'ramagan savdo — bu «zaif moslik» emas, bu **moslik emas**.

### 4.2 Vaznlar (biznes rejadan)

```python
W_VALUE    = 40   # narx ekvivalenti
W_LOCATION = 30   # hudud
W_RATING   = 20   # reyting
W_CATEGORY = 10   # kategoriya
```

| Signal | Qanday | Chegara holat |
|---|---|---|
| Narx | `min/max` nisbat | Teng = 1.0, 10× farq = 0.1 |
| Hudud | Haversine masofa | ≤25 km = 1.0, 400 km = 0. **Noma'lum = 0.5** |
| Reyting | `reyting/5` + tasdiqlangan bo'lsa 0.1 | **Sharhsiz yangi a'zo = 0.5** |
| Kategoriya | Aniq = 1.0, «farqi yo'q» = 0.6 | — |

**Noma'lum qiymat jarima emas.** Koordinatasini kiritmagan yoki hali sharh
olmagan odam pastga tushib ketmasligi kerak — aks holda yangi foydalanuvchi
hech qachon boshlay olmaydi.

### 4.3 `will_add_cash` — eng nozik joy

Ikki tovar deyarli hech qachon teng qiymatda bo'lmaydi. Shuning uchun xohishdagi
narx oralig'i pul bayrog'iga qarab kengayadi:

```
CASH_STRETCH = 2.0
will_add_cash → yuqori chegara × 2    (ustiga pul qo'shaman → qimmatroqni olaman)
wants_cash    → quyi chegara ÷ 2      (ustiga pul olaman → arzonroqni olaman)
```

**Sinov:** 40 t guruch (6.3 mln) ↔ MTZ-892 traktor (15 mln). Traktor 2.4 barobar
qimmat — oddiy oraliqqa sig'maydi. `will_add_cash` bilan sig'adi → **76% moslik**.
Bu mahsulotning asosiy hikoyasi va busiz ishlamaydi.

### 4.4 Ikki xil «xohish»

| Jadval | Kim o'qiydi | Misol |
|---|---|---|
| `listing_wants` | **Odam** — ekranda ko'rinadi | «Traktor (80+ ot kuchi)» |
| `desires` | **Algoritm** | `category=machinery, 3.7–12.6 mln, will_add_cash` |

Birinchi versiyada faqat matn bor edi va algoritm so'zlarni taqqoslardi. Matnni
tahlil qilib xohishni tushunish ishonchsiz — shuning uchun ikkiga bo'lindi.

⚠️ **E'lon yaratishda ikkalasini ham to'ldiring.**

### 4.5 Uchburchak barter — 3-bosqich

```
A: guruch bor, qo'y kerak
B: qo'y bor,   sement kerak
C: sement bor, guruch kerak
```

Hech kim 1-ga-1 mos kelmaydi, lekin uchtasi zanjir hosil qiladi.

Hozirgi model buni **qo'llab-quvvatlaydi**: `desires` bo'yicha yo'naltirilgan
graf qurib, uzunligi 3 bo'lgan sikllarni izlash kerak. MVP dan keyin.

### 4.6 Hozir o'qishda, keyin cron'da

Biznes reja har 5 daqiqada ishlaydigan fon ishini talab qiladi. Hozir
`rebuild_matches()` o'qish paytida ishlaydi va natijani 5 daqiqa keshlaydi.

Cron'ga o'tkazish — o'sha funksiyani Celery task'idan chaqirish. Boshqa hech
nima o'zgarmaydi.

---

## 5. Pul

### 5.1 Butun son, hech qachon matn

```
value_minor: 630000000   +   currency: "UZS"   =   6 300 000 so'm
```

`minor` — tiyin. Formatlash **faqat mijozda**.

**Nega:** prototip `"$5,000"` deb saqlagan va uni na saralab, na taqqoslab, na
boshqa valyutaga o'girib bo'lgan. Matnni saralash — narxni alifbo bo'yicha
tartiblash demakdir.

### 5.2 Qo'shimcha pul yo'nalishi

`offers.cash_delta_minor`:
- musbat → **yuboruvchi** ustiga qo'shadi
- manfiy → yuboruvchi ustiga **oladi**

### 5.3 Escrow (hali qurilmagan)

Reja: qo'shimcha pul BarterApp hisobida turadi, ikkala tomon topshirishni
tasdiqlaganda o'tkaziladi. Platforma 1–2% komissiya oladi.

`GET /me/settlements` yakunlangan savdolardagi pul harakatini ko'rsatadi —
escrow ulanganda o'sha jadval to'ladi.

---

## 6. Ishonch tizimi

### 6.1 Ishonch darajasi hisoblanadi

```
phone     20  ← SMS orqali
passport  25  ← pasport / JSHSHIR
business  25  ← korxona hujjatlari
bank      20  ← escrow uchun
video     10  ← 30 soniyalik selfie
──────────────
          100
```

`trust_score` = tasdiqlangan bosqichlar vaznlari yig'indisi. `≥60` → «tasdiqlangan».

⚠️ Hech qachon qo'lda yozilmaydi. Prototipda `92` uch joyda qattiq kodlangan edi
va ostidagi ro'yxatga mos kelmasdi.

### 6.2 Reyting va sharhlar

- Sharh **faqat yakunlangan savdodan keyin**.
- `author_id ≠ about_id` — baza cheklovi.
- Bir savdoga bir odam bir marta.
- Reyting `AVG(rating)` — hisoblanadi, saqlanmaydi.

### 6.3 Javob berish tezligi

`responds_within_minutes` — «odatda 30 daqiqada javob beradi». Biznes rejada
reytingning bir qismi. Hozir seed'dan keladi, keyinchalik xabarlar orasidagi
o'rtacha vaqtdan hisoblanadi.

---

## 7. Uch til

### 7.1 Ikki xil matn

| Nima | Qayerda | Mexanizm |
|---|---|---|
| Interfeys («Qabul qilish») | Mijozda | `l10n/*.arb` |
| Kontent (e'lon sarlavhasi) | Serverda | `listing_translations` |
| Son, sana, pul | Mijozda | `intl` |

### 7.2 Server bitta tilda javob beradi

`Accept-Language: ru` → javobda faqat ruscha. Mijoz uch tilni bir vaqtda
olmaydi va o'zi tanlamaydi.

**Nega:** prototip uch tilni birga yuborardi va bitta ekranda lotin bilan kirill
aralashib ketardi.

### 7.3 Tarjima majburiy

`listing_translations` PK = `(listing_id, locale)`, va API yaratishda uchtasini
ham talab qiladi. Bittasi bo'sh bo'lsa `422`.

**Nega:** ixtiyoriy `ru` maydoni jimgina o'zbekchaga tushishga yo'l ochgan edi —
rus tilida o'qiyotgan odam uchun bu buzuq ilova ko'rinadi.

### 7.4 Ochiq savol: ismlar

Hozir `first_name`/`last_name` — bitta ustun, tarjima qilinmaydi. Shuning uchun
rus tilidagi ekranda `Sardor Choriyev` lotin harflarida chiqadi.

**Hal qilish kerak:** har foydalanuvchiga kirill varianti saqlanadimi, yoki
mijozda transliteratsiya qilinadimi? Bu mahsulot qarori, texnik emas.

---

## 8. Monetizatsiya

| Model | Holat | Qayerda |
|---|---|---|
| Bepul e'lon kvotasi (2 ta) | ✅ | `users.free_listings_left` |
| Biznes hisoblar (STIR) | ✅ | `user_type` + `tax_id` |
| Pullik e'lon | ⬜ | To'lov provayderi kerak |
| Obuna (Basic/Business/Pro) | ⬜ | `subscriptions` jadvali |
| Boost / VIP | ⬜ | `is_premium` bor, muddat va to'lov yo'q |
| Safe Deal komissiyasi 1–2% | ⬜ | `escrow_holds` jadvali |

Hozir **biznes hisoblar kvotadan ozod** — to'lov oqimi tayyor bo'lmagani uchun
pul to'laydigan segmentni bloklamaslik ma'qul.

---

## 9. Xavfsizlik va firibgarlik

| Xavf | Hozirgi himoya | Rejada |
|---|---|---|
| O'ziga sharh | `CHECK (author_id <> about_id)` | ✅ |
| O'ziga taklif | `CHECK (from_user_id <> to_user_id)` | ✅ |
| Begona e'lonni taklif qilish | `owner_id` tekshiriladi | ✅ |
| Chatga kirish | Ishtirokchilik tekshiriladi | ✅ |
| Karta ma'lumoti | Faqat oxirgi 4 raqam saqlanadi | ✅ |
| OTP brute-force | 5 urinish, 5 daqiqa | ✅ |
| Boshqa joydan olingan rasm | — | AI tekshiruvi |
| Nizo | `disputed` statusi bor | Arbitraj paneli |

---

## 10. Nima ataylab qilinmagan

Bu qarorlar — **kamchilik emas, muddat**.

| Nima | Nega hozir yo'q |
|---|---|
| Elasticsearch | 100k e'longacha SQL `ILIKE` yetadi. Erta optimizatsiya |
| Redis / ko'p protsess | WebSocket bitta protsessda to'g'ri ishlaydi. `Hub` klassi ichini almashtirsa bo'ladi |
| `freezed` modellar | Model kam, qo'lda yozilgani o'qishga oson. 40+ bo'lganda o'tiladi |
| Uchburchak barter | Model tayyor, algoritm 3-bosqichda |
| Rasm yuklash | S3/MinIO kerak, hozir URL yetadi |
| Cron matching | O'qishda hisoblash MVP uchun to'g'ri |

---

## 11. Qaror qabul qilish mezoni

Yangi funksiya qo'shayotganda:

1. **Bu «kimga nima kerak» savoliga javob beradimi?** Yo'q bo'lsa — kerak emas.
2. **Ma'lumot nusxalanmaydimi?** Nusxalansa — vaqt o'tib farqlanadi.
3. **Bazada cheklov bilan himoyalasa bo'ladimi?** Bo'lsa — kodda emas, bazada.
4. **Uch tilda ham ishlaydimi?**
5. **Yangi foydalanuvchini jazolamaydimi?** (sharhsiz, koordinatasiz odam)
