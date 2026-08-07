# Backend qo'llanma — `api/`

FastAPI + SQLAlchemy 2 + PostgreSQL. Bu hujjat kodni **qo'lda o'zgartirish** uchun
yozilgan: har bir qism qayerda turishi, nega shunday qilingani va o'zgartirsangiz
nima buziladi.

---

## 1. Papkalar — nima qayerda

```
api/
├── alembic/versions/     Migratsiyalar. Har bir sxema o'zgarishi shu yerda.
├── app/
│   ├── main.py           Ilova, CORS, router'lar ulanadi
│   ├── seed.py           Demo ma'lumot. `python -m app.seed`
│   ├── core/
│   │   ├── config.py     BARCHA sozlamalar. .env dan o'qiydi
│   │   ├── security.py   JWT yaratish/tekshirish, current_user
│   │   └── locale.py     Accept-Language → uz | ru | en
│   ├── db/
│   │   ├── base.py       Base, UUID kaliti, created_at/updated_at
│   │   └── session.py    Ulanish va get_db()
│   ├── models/           SQLAlchemy jadvallari (= baza)
│   ├── schemas/          Pydantic — API kirish/chiqishi
│   ├── services/         Biznes mantiq. Endpoint'lar ingichka bo'lishi uchun
│   └── api/              HTTP endpoint'lar
└── tests/test_trade_loop.py   Butun savdo aylanishi uchun e2e test
```

**Oltin qoida:** `api/` faqat HTTP bilan shug'ullanadi. Har qanday qaror —
kim nima qila oladi, ball qanday hisoblanadi — `services/` da.

---

## 2. Qatlamlar: so'rov qanday o'tadi

```
HTTP so'rov
   │
   ├─▶ api/listings.py          Depends() bilan: kim so'rayapti, qaysi tilda
   │        │
   │        ├─▶ core/security.py    token → User
   │        ├─▶ core/locale.py      header → "uz"
   │        │
   │        ├─▶ models/*            SQL so'rov
   │        ├─▶ services/*          qoidalar va hisob
   │        └─▶ services/presenter  model → API shakli
   │
   └─▶ schemas/*                 javob tekshiriladi va JSON bo'ladi
```

**Nega `presenter.py` alohida?** Prototipda savdogar ismi to'rt xil joyda to'rt xil
yig'ilgan va vaqt o'tib bir-biriga mos kelmay qolgan. Endi `trader_brief()` —
yagona joy. Ismni o'zgartirmoqchi bo'lsangiz **faqat o'sha funksiyani**
o'zgartirasiz, hamma ekran birdan yangilanadi.

---

## 3. Ma'lumotlar bazasi

### 3.1 Jadvallar va bog'lanishlar

| Jadval | Nima saqlaydi | Muhim nuqta |
|---|---|---|
| `users` | Shaxs haqidagi **yagona** manba | Ism/rasm/reyting boshqa hech qayerda nusxalanmaydi |
| `listings` | E'lon. Faqat `owner_id` | `value_minor` — tiyinda, butun son |
| `listing_translations` | Sarlavha/tavsif uch tilda | PK: `(listing_id, locale)` |
| `listing_wants` + `_translations` | «Nima kerak» — **odam o'qishi uchun** | Ekranda ko'rinadi |
| **`desires`** | «Nima kerak» — **algoritm uchun** | Kategoriya + narx oralig'i + pul yo'nalishi |
| `listing_photos` | Rasmlar, tartib bilan | |
| `offers` | Taklif. Mahsulotning markazi | `status` butun oqimni boshqaradi |
| `offer_items` | Taklif qiluvchi qo'yayotgan e'lonlar | |
| `conversations` / `messages` | Chat. Har taklifga bitta suhbat | |
| `reviews` | `author_id` **va** `about_id` | O'ziga sharh yozib bo'lmaydi |
| `notifications` | `target_type` + `target_id` | Manzil turdan taxmin qilinmaydi |
| `matches` | Hisoblangan mosliklar | Fon ishi qayta yozadi |
| `verification_steps` | Tasdiqlash bosqichlari | Ishonch darajasi shundan yig'iladi |
| `payment_methods` | Kartalar (faqat oxirgi 4 raqam) | |

### 3.2 `listing_wants` va `desires` — nega ikkitasi?

Bu eng ko'p savol tug'diradigan joy.

- **`listing_wants`** — «Traktor (80+ ot kuchi)» degan **matn**, uch tilda.
  Foydalanuvchi o'qiydi.
- **`desires`** — `category=machinery, min=3.7M, max=12.6M, will_add_cash=true`.
  **Algoritm** o'qiydi.

Birinchi versiyada faqat matn bor edi va algoritm so'zlarni taqqoslardi. Natija:
«MacBook ↔ 6 tonna makkajo'xori» 85% moslik chiqdi. Matnni tahlil qilib xohishni
tushunish ishonchsiz — shuning uchun ikkiga bo'lindi.

**O'zgartirsangiz:** yangi e'lon yaratganda ikkalasini ham to'ldiring.
`api/listings.py` → `create_listing()` ga qarang.

### 3.3 Cheklovlar — kod emas, baza ushlab turadi

```sql
-- O'ziga sharh yozish
CHECK (author_id <> about_id)
-- O'ziga taklif yuborish
CHECK (from_user_id <> to_user_id)
-- Manzilsiz bildirishnoma
CHECK (target_type = 'matches' OR target_id IS NOT NULL)
-- Qo'llab-quvvatlanmagan til
CHECK (locale IN ('uz','ru','en'))
-- STIRsiz biznes hisob
CHECK (user_type <> 'business' OR tax_id IS NOT NULL)
```

Sinab ko'ring — rad etadi:

```bash
docker exec barter-db psql -U barter -d barter -c "UPDATE users SET locale='fr' WHERE phone='+998901234122';"
```

**Nega kodda emas, bazada?** Kodda tekshiruv unutilishi mumkin, migratsiyada
o'tkazib yuborilishi mumkin, boshqa servis to'g'ridan-to'g'ri yozishi mumkin.
Bazadagi `CHECK` — oxirgi chegara.

---

## 4. Pul — eng ko'p xato qilinadigan joy

**Qoida: pul hech qachon matn emas.**

```python
value_minor: int   # 6_300_000_00  → 6 300 000 so'm
currency: str      # "UZS"
```

`_00` oxiri — tiyin. `6_300_000_00` = 6 300 000 so'm 00 tiyin.

Formatlash **faqat mijozda**, `intl` orqali — o'sha bir son uzbekchada
`6 300 000 so'm`, ruschada `6 300 000 сум` bo'lib chiqadi.

Prototip `"$5,000"` deb saqlagan va uni na saralab, na taqqoslab bo'lgan.

Valyutani o'zgartirish: `core/config.py` → `default_currency`.

---

## 5. Taklifning holat mashinasi

Butun mahsulot shu jadvalga suyanadi — `services/offers.py`:

```python
TRANSITIONS = {
  # amal:      (qaysi holatdan,              natija,      kim)
  "accept":   ({pending, talking},           accepted,    "recipient"),
  "decline":  ({pending, talking},           declined,    "recipient"),
  "counter":  ({pending, talking},           talking,     "either"),
  "complete": ({accepted},                   completed,   "either"),
  "dispute":  ({accepted},                   disputed,    "either"),
}
```

- `"recipient"` — faqat taklif **kelgan** tomon bosa oladi.
- `counter` tomonlarni **almashtiradi**: javob bergan odam endi yuboruvchi
  bo'ladi, keyingi `accept` narigi tomonga o'tadi.
- `complete` ikkala e'lonni `completed` qiladi — ular lentadan chiqadi.

**Yangi amal qo'shish:** shu jadvalga qator qo'shing. Endpoint o'zgarmaydi.

**Sinash:**
```bash
cd api && .venv/bin/python tests/test_trade_loop.py
```

---

## 6. Matching algoritmi — `services/matching.py`

### 6.1 Ikki bosqich

```
1) FILTR   — wanted()      Bu narsa umuman kerakmi?
2) SARALASH — score_pair()  Kerak bo'lganlar orasida qaysi biri yaxshiroq?
```

Biznes rejada kategoriya 10% vazn oladi. Bu **saralash** uchun to'g'ri, lekin
**qabul qilish** uchun emas: 10% jarima bilan mutlaqo keraksiz narsa ham
85% chiqib ketdi. Shuning uchun avval filtr, keyin vazn.

### 6.2 Vaznlar (biznes rejadan)

```python
W_VALUE    = 40   # narx ekvivalenti
W_LOCATION = 30   # hudud
W_RATING   = 20   # reyting
W_CATEGORY = 10   # kategoriya mosligi
```

Vaznni o'zgartirish — shu to'rt qatorni tahrirlash. Boshqa hech nima
tegmaydi.

### 6.3 Har bir signal qanday hisoblanadi

| Signal | Funksiya | Mantiq |
|---|---|---|
| Narx | `value_score` | `min/max`. Teng = 1.0, 10× farq = 0.1 |
| Hudud | `location_score` | ≤25 km = 1.0, 400 km dan keyin 0. **Noma'lum = 0.5** (jarima emas) |
| Reyting | `rating_score` | `reyting/5`, tasdiqlanganga +0.1. Yangi a'zo 0.5 dan boshlaydi |
| Kategoriya | `category_score` | Aniq kategoriya 1.0, «farqi yo'q» 0.6 |

Masofa — `haversine_km()`, haqiqiy geografik masofa. Samarqand→Toshkent = 279 km.

### 6.4 `will_add_cash` — eng nozik joy

Ikki tovar deyarli hech qachon teng qiymatda bo'lmaydi. Shuning uchun
`Desire.accepts_value()` pul bayroqlariga qarab oraliqni kengaytiradi:

```python
CASH_STRETCH = 2.0
if will_add_cash:  yuqori chegara × 2    # ustiga pul qo'shaman → qimmatroqni ola olaman
if wants_cash:     quyi chegara ÷ 2      # ustiga pul olaman → arzonroqni ola olaman
```

Busiz asosiy hikoya ishlamaydi: 40 t guruch (6.3 mln) traktorga (15 mln)
mos kelmaydi, chunki traktor 2.4 barobar qimmat. Pul bilan — mos keladi, 76%.

### 6.5 Hozir o'qishda, kelajakda cron'da

Biznes reja har 5 daqiqada ishlaydigan fon ishini talab qiladi. Hozir
`rebuild_matches()` o'qish paytida ishlaydi (`STALE_AFTER = 5 daqiqa`).

Cron'ga o'tkazish: Celery/APScheduler task'idan **shu funksiyani chaqiring**.
Boshqa hech nima o'zgarmaydi.

### 6.6 Uchburchak barter (hali yo'q)

Biznes rejada 3-bosqich. Hozirgi model uni qo'llab-quvvatlaydi:
`desires` jadvali bo'yicha yo'naltirilgan graf qurib, uzunligi 3 bo'lgan
sikllarni izlash kerak. `matching.py` ga `find_triangles()` qo'shiladi.

---

## 7. Uch til

**Interfeys yozuvlari mijozda, kontent serverda.**

```
So'rov:  Accept-Language: ru
   ↓
core/locale.py → "ru"
   ↓
presenter._text(listing, "ru") → listing_translations dagi ru qatori
   ↓
Javob:   {"title": "Трактор МТЗ-892"}
```

Mijoz uch tilni bir vaqtda **olmaydi**. Prototipda shunday edi va bitta ekranda
lotin va kirill aralashib ketgandi.

**Yangi e'lon:** `ListingCreate` uch tilni ham majburiy qiladi (`TranslatedText`).
Bittasi bo'sh bo'lsa — 422, ya'ni yarim tarjima lentaga tushmaydi.

---

## 8. Autentifikatsiya

```
POST /auth/otp/request  {phone}         → SMS kod (hozircha javobda qaytadi)
POST /auth/otp/verify   {phone, code}   → access + refresh token
POST /auth/refresh      {refresh_token} → yangi juftlik
```

- Kod `otp_challenges` da, 5 daqiqa yashaydi, 5 marta xato — bloklanadi.
- Birinchi kirishda foydalanuvchi **avtomatik yaratiladi** + 5 ta tasdiqlash
  bosqichi qo'shiladi.
- `OTP_DEBUG=true` bo'lsa kod javobda qaytadi. **Ishlab chiqarishda `false` qiling.**

**SMS ulash:** `api/auth.py` → `request_otp()` ichida `# A real SMS gateway goes
here` izohi bor. Eskiz, Playmobile yoki boshqa provayderni shu yerga qo'ying.

---

## 9. Monetizatsiya — hozir nima bor, nima yo'q

| Biznes reja | Holat |
|---|---|
| Bepul e'lon kvotasi | ✅ `users.free_listings_left`, `create_listing` da tekshiriladi |
| Biznes hisoblar (STIR) | ✅ `user_type` + `tax_id` |
| Pullik e'lon | ⬜ To'lov provayderi kerak |
| Obuna paketlari | ⬜ `subscriptions` jadvali kerak |
| Boost / VIP | ⬜ `listings.is_premium` bor, muddat va to'lov yo'q |
| Safe Deal komissiyasi | ⬜ `escrow_holds` jadvali rejalashtirilgan |

Hozir biznes hisoblar kvotadan ozod — to'lov oqimi tayyor bo'lmagani uchun
pul to'laydigan segmentni bloklamaslik ma'qul.

---

## 10. Amaliy retseptlar

### Yangi maydon qo'shish

```bash
# 1. models/ da ustun qo'shing
# 2. Migratsiya yarating
cd api && .venv/bin/alembic revision --autogenerate -m "nima qo'shildi"
# 3. Yaratilgan faylni O'QING — autogenerate enum o'zgarishini ko'rmaydi
# 4. Qo'llang
.venv/bin/alembic upgrade head
```

⚠️ **Enum'ga yangi qiymat qo'shsangiz** avtomatik chiqmaydi, qo'lda yozing:

```python
op.execute("ALTER TYPE listing_status ADD VALUE IF NOT EXISTS 'reserved'")
op.execute("COMMIT")
```

### Bazani noldan tiklash

```bash
docker exec barter-db psql -U barter -d barter -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
cd api && .venv/bin/alembic upgrade head && .venv/bin/python -m app.seed
```

### Yangi endpoint

1. `schemas/` da kirish/chiqish modeli
2. `services/` da mantiq (agar oddiy CRUD bo'lmasa)
3. `api/` da router
4. `main.py` da `include_router`

### Xato xabarlari

`HTTPException` ichidagi matn **to'g'ridan-to'g'ri foydalanuvchiga ko'rinadi** —
Flutter uni `detail` dan olib ekranga chiqaradi. Shuning uchun ular o'zbekchada
va odam tilida yozilgan:

```python
raise HTTPException(409, "Faqat taklif kelgan tomon bu amalni bajara oladi.")
```

---

## 11. Ishga tushirish

```bash
docker compose up -d                       # baza
cd api
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/alembic upgrade head
.venv/bin/python -m app.seed
.venv/bin/uvicorn app.main:app --port 8010 --reload
```

- Hujjatlar: http://127.0.0.1:8010/docs
- Test hisob: **+998901234122**

---

## 12. Ishlab chiqarishga chiqishdan oldin

| Nima | Qayerda |
|---|---|
| `JWT_SECRET` ni o'zgartiring | `core/config.py` yoki `.env` |
| `OTP_DEBUG=false` | Aks holda kod javobda qaytadi |
| Haqiqiy SMS provayderi | `api/auth.py` |
| CORS'ni aniq domenlarga cheklang | `main.py` — hozir har qanday localhost |
| Rasm yuklash (S3/MinIO) | Hozir faqat URL qabul qilinadi |
| Elasticsearch | 100k+ e'londa SQL `ILIKE` sekinlashadi |
| Matching'ni cron'ga | `matching.rebuild_matches()` |
| Migratsiyalarni tekshiring | `alembic upgrade head` toza bazada |
