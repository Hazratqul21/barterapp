# BarterApp

Naqd pulsiz ayirboshlash platformasi — fermer xo'jaliklari, ustaxonalar va
xususiy shaxslar uchun. Uch tilda: **uz · ru · en**.

```
barter-platform/
├── docs/                 ← HUJJATLAR. Ishni shu yerdan boshlang
│   ├── DOMAIN.md              biznes mantiq
│   ├── API.md                 mijoz–server shartnomasi
│   ├── FLUTTER-BRIEF.md       Flutter topshirig'i
│   ├── BACKEND.md             backend qo'llanmasi
│   ├── DESIGN.md              dizayn tizimi: rang, shrift, o'lcham
│   ├── AI-TOPSHIRIQ.md        boshqa AI'ga beriladigan matn
│   └── biznes-reja/           asl biznes reja (.md, .pdf)
├── docker-compose.yml    PostgreSQL 16, port 5434
├── api/                  FastAPI + SQLAlchemy 2 + Alembic
└── app/                  Flutter — web, iOS, Android
```

> React prototipi (`~/Desktop/Barterapp`) — bu loyihaning bir qismi emas.
> U ekran xatti-harakatini aniqlash uchun ishlatilgan va endi faqat arxiv.

---

## Hujjatlar — kim nimani o'qishi kerak

| Hujjat | Kimga | Nima haqida |
|---|---|---|
| **[docs/DOMAIN.md](docs/DOMAIN.md)** | **Hammaga** | Biznes mantiq: savdo qanday kechadi, matching qanday ishlaydi, nega shunday qaror qilingan |
| **[docs/API.md](docs/API.md)** | Mijoz yozuvchiga | Har bir endpoint: so'rov, javob, xatolar. Mijoz va server o'rtasidagi **yagona shartnoma** |
| **[docs/FLUTTER-BRIEF.md](docs/FLUTTER-BRIEF.md)** | **Flutter yozuvchiga** | Har bir ekran: qanday ko'rinishi, qaysi ma'lumot, qanday xatti-harakat. Mustaqil topshiriq |
| **[docs/BACKEND.md](docs/BACKEND.md)** | Backend yozuvchiga | Papkalar, qatlamlar, migratsiya, retseptlar |
| **[docs/DESIGN.md](docs/DESIGN.md)** | Dizayner va Flutter yozuvchiga | Rang, shrift, radius, oraliq — nima uchun shunday |
| **[docs/AI-TOPSHIRIQ.md](docs/AI-TOPSHIRIQ.md)** | Loyiha egasiga | Boshqa AI'ga beriladigan tayyor topshiriq matni |
| **[docs/biznes-reja/](docs/biznes-reja/)** | Hammaga | Asl biznes reja — barcha mahsulot qarorlarining manbai |

### Flutter'ni boshqa dasturchi yoki AI yozayotgan bo'lsa

Unga uchta faylni bering:

1. `docs/FLUTTER-BRIEF.md` — asosiy topshiriq
2. `docs/API.md` — API shartnomasi
3. `docs/DOMAIN.md` — biznes qoidalar

Bu uchtasi yetarli. Backend kodini ko'rish shart emas va **o'zgartirmasligi kerak**.

---

## Ishga tushirish

### 1. Baza

```bash
docker compose up -d
```

### 2. Backend → http://127.0.0.1:8010

```bash
cd api
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/alembic upgrade head
.venv/bin/python -m app.seed
.venv/bin/uvicorn app.main:app --port 8010 --reload
```

Sinab ko'rish uchun jonli hujjatlar: **http://127.0.0.1:8010/docs**

### 3. Mijoz

```bash
cd app
flutter pub get
flutter gen-l10n
flutter run -d chrome                    # web
flutter run -d <simulator-udid>          # iOS
flutter run -d <emulator-id>             # Android
```

Kirish: **+998901234122** — SMS kodi javobda qaytadi (provayder hali ulanmagan).

---

## Holat

### Backend

33 endpoint, 18 jadval, butun savdo aylanishi sinalgan.

```bash
cd api && .venv/bin/python tests/test_trade_loop.py
```

| Bosqich | Holat |
|---|---|
| Sxema va migratsiyalar | ✅ |
| Auth (OTP + JWT) | ✅ |
| Lenta, e'lon, qidiruv, masofa, kursorli sahifalash | ✅ |
| E'lon yaratish (3 til majburiy) + `desires` | ✅ |
| Surat yuklash (`POST /uploads`, Pillow bilan) | ✅ |
| Hududlar va koordinatalar (`GET /regions`) | ✅ |
| Takliflar + holat mashinasi | ✅ |
| Chat + WebSocket | ✅ |
| Mosliklar (40/30/20/10 ball) | ✅ |
| Bildirishnomalar | ✅ |
| Profil, sharhlarni **o'qish**, tasdiqlash | ✅ |
| To'lov usullari, hisob-kitob | ✅ |
| Sharh **yozish** (`POST /reviews`) | ⬜ |
| Escrow, obuna, boost | ⬜ |
| Taklif muddatining avtomatik tugashi | ⬜ |

### Mijoz

Barcha ekran yozilgan va ulangan. `flutter analyze` → 0 muammo.

| Ekran | Holat |
|---|---|
| Splash + uch kirish ekrani | ✅ |
| Kirish (telefon + SMS) | ✅ |
| Profil to'ldirish (ism, hudud, surat) | ✅ |
| Lenta (hero, kategoriyalar, cheksiz scroll) | ✅ |
| E'lon sahifasi | ✅ |
| E'lon yaratish (4 bosqich) | ✅ |
| Taklif yuborish | ✅ |
| Chat + kelishuv paneli | ✅ |
| Xabarlar, Mosliklar, Bildirishnomalar | ✅ |
| Profil, savdogar profili | ✅ |
| Sozlamalar, tasdiqlash, to'lovlar | ✅ |

## Sxema nimani kafolatlaydi

Prototip auditidan chiqqan oltita qoida — ilova kodiga emas, **bazaga** yozilgan:

| Qoida | Qanday |
|---|---|
| E'lon egasining ismi/rasmi/reytingini nusxalamaydi | Faqat `owner_id`, qolgani `JOIN` |
| Hech kim o'ziga sharh yoza olmaydi | `CHECK (author_id <> about_id)` |
| Bildirishnoma o'z manzilini olib yuradi | `target_type` + `target_id` |
| Har bir e'lon uch tilda mavjud | `listing_translations (listing_id, locale)` |
| Sanoqlar hisoblanadi, yozilmaydi | `COUNT`/`AVG`, `services/stats.py` |
| Pul — butun son + valyuta | `value_minor bigint`, `currency char(3)` |

Sinab ko'ring — rad etadi:

```bash
docker exec barter-db psql -U barter -d barter -c "INSERT INTO reviews (id,offer_id,author_id,about_id,rating,body,created_at) VALUES (gen_random_uuid(),gen_random_uuid(),'11111111-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111',5,'x',now());"
```

---

## Ishlab chiqarishga chiqishdan oldin

| Nima | Nega |
|---|---|
| `JWT_SECRET` o'rnatish | Standart kalit bilan har kim istalgan hisobga kira oladi. Server `OTP_DEBUG=false` bo'lsa-yu kalit standart bo'lsa **ishga tushmaydi** — `api/.env.example` ga qarang |
| SMS provayderini ulash | Hozir `OTP_DEBUG=true` bo'lganda kod javobda qaytadi |
| Suratlar uchun doimiy joy | Hozir `api/media/` papkasi. Ko'p serverga chiqilganda S3/MinIO kerak — o'zgarish faqat `api/uploads.py` ichida |
| `POST /reviews` | Sharh o'qiladi, lekin yozib bo'lmaydi |
| Cron: taklif muddati | `expires_at` yoziladi, hech kim `expired` ga o'tkazmaydi |

## Ma'lum kamchiliklar

- **Android SDK o'rnatilmagan** — kod Android'ga mo'ljallangan, faqat toolchain
  yo'q. Android Studio o'rnating, keyin `flutter doctor`.
- **`GET /conversations` N+1 so'rov beradi** — har suhbat uchun taklif alohida
  yig'iladi. 20 suhbat ≈ 180 so'rov.
- **Savdogar ismlari tarjima qilinmaydi** — rus tilida lotin harflarida chiqadi.
  Mahsulot qarori kerak: kirill varianti saqlanadimi yoki transliteratsiya
  qilinadimi? (DOMAIN.md §7.4)
- **Uchburchak barter** — model tayyor, algoritm yozilmagan.
