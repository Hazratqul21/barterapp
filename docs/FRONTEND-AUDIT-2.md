# Frontend audit #2 — BarterApp (Flutter)

**Sana:** 2026-08-22 · **Usul:** statik tahlil + backend shartnomasi bilan
jonli solishtirish · **Kodga tegilmagan**

> Oldingi ikkita hujjatning davomi:
> [FRONTEND-AUDIT.md](FRONTEND-AUDIT.md) (statik) va
> [FRONTEND-BUGS-RUNTIME.md](FRONTEND-BUGS-RUNTIME.md) (simulyatorda).
> Bu — uchinchi tekshiruv: oradan o'tgan ish qabul qilinadi, qolgani va
> yangi topilganlar sanaladi.

---

## Avvalgi hisobotdan beri tuzatilganlar ✅

Ancha ish qilingan, buni alohida qayd etaman:

| Edi | Endi |
|---|---|
| `flutter analyze` — 6 ogohlantirish | **0** |
| Firebase ishga tushishda yiqilardi | Tuzatilgan (guard qo'yilgan) |
| `fcm_token` → 422 | `token` — shartnomaga mos |
| Platforma `'ios'` qattiq yozilgan | Qurilmadan aniqlanadi |
| Saqlash tugmasi faqat `setState` | `/favorites` ga ulangan |
| Hodisalar yuborilmasdi | `/events` ulangan |
| Shikoyat va bloklash yo'q edi | Menyu qo'shilgan |
| Hisobni o'chirish yo'q edi | Sozlamalarda bor |

`flutter test` — 17/17 o'tadi.

---

## P0 — Do'kon rad etadi yoki foydalanuvchi ma'lumot yo'qotadi

### P0-1. Hisobni o'chirish **ishlamaydi** — har safar 422

**Qayerda:** [auth_repository.dart:53](../app/lib/features/auth/data/auth_repository.dart#L53)

```dart
Future<void> deleteAccount() => _api.delete('/me', parse: (_) {});
```

`ApiClient.delete()` da **`body` parametri umuman yo'q**
([api_client.dart:282](../app/lib/core/network/api_client.dart#L282)) —
u faqat `_dio.delete(path)` chaqiradi.

Server esa `{"confirm": true}` talab qiladi. Jonli tekshirdim:

```
tanasiz DELETE /me → 422
```

**Nega P0:** Apple 5.1.1(v) hisobni o'chirishni talab qiladi. Tugma bor,
bosiladi, **hech qachon ishlamaydi**. Tekshiruvchi buni birinchi
daqiqalarda sinaydi.

**Nima kerak:** `ApiClient.delete()` ga `body` qo'shish va
`deleteAccount()` da `{'confirm': true}` yuborish.

### P0-2. Maxfiylik siyosati havolasi soxta manzilga ketadi

**Qayerda:** [settings_page.dart:206-208](../app/lib/features/profile/presentation/settings_page.dart#L206)

```dart
title: 'Privacy Policy', // TODO: localize
Uri.parse('https://example.com/privacy'),
```

Uchta muammo bir qatorda: manzil `example.com`, sarlavha tarjima
qilinmagan, va foydalanish shartlari umuman yo'q.

Matnlar tayyor: [docs/legal/](legal/) da uchta hujjat bor. Ularni
veb-saytga qo'yib, haqiqiy URL kiritish kerak.

---

## P1 — Backend tayyor, mijoz ulanmagan

| Endpoint | Holat | Nima yo'qoladi |
|---|---|---|
| `GET/PATCH /notification-settings` | ❌ | Sokin soatlar va tur bo'yicha o'chirish. Sozlamalarda `l.notificationSettings` yorlig'i bor, lekin ekran yo'q |
| `GET /blocks` | ❌ | Bloklanganlar ro'yxati. Bloklash **bor**, yechish **yo'q** — odam bloklaydi va uni qaytara olmaydi |
| `GET /feed-blocks` | ❌ | Admin paneldan boshqariladigan banner va tanlangan e'lonlar. Panel ishlaydi, mijoz o'qimaydi |
| `GET /config/firebase` | ❌ | Push parametrlarini serverdan olish. Hozir `GoogleService-Info.plist` kerak |

**`GET /blocks` alohida muhim:** Apple 1.2 bo'yicha bloklash mexanizmi
talab qilinadi, lekin uni **bekor qilish imkoni** ham bo'lishi kerak.
Hozir bir tomonlama.

---

## P2 — Oldingi hisobotdan qolganlar

Bular hali ham ochiq — batafsil tavsif
[FRONTEND-AUDIT.md](FRONTEND-AUDIT.md) da:

| # | Nima |
|---|---|
| P1-2 | «Dark Mode» tugmasi qorong'i rejimni yoqmaydi (`themeMode` yo'q) |
| P3-3 | 31 ta qattiq rang — qorong'i rejim yoqilsa o'qilmaydi. **P1-2 bilan birga tuzatilsin** |
| P1-3 | Lentada filtr va saralash UI si yo'q (`min_value`, `region`, `sort`) |
| P3-1 | `textScaler` bilan ishlanmagan, 48 ta qattiq balandlik |
| P3-2 | 18 ta `IconButton`, yorliqlar deyarli yo'q |
| P3-7 | Xato ekranida `request_id` ko'rsatilmaydi |
| R2-1..3 | Lentadagi bo'sh oq karta, kesilgan banner, status bar ostiga kiruvchi karta |
| P4-1 | `genkit`, `video_player`, `http` — import qilinmagan, hajmni oshiradi |
| P4-3 | Versiya `0.1.0+1`, iOS'da `MARKETING_VERSION = 1.0` — mos emas |
| P4-4 | Paket nomlari mos emas: `barter_app` (Android) va `barterApp` (iOS). **Relizdan keyin o'zgartirib bo'lmaydi** |

---

## Tavsiya etilgan tartib

1. **P0-1** — bir qator kod, lekin do'kon uchun to'sqinlik
2. **P0-2** — huquqiy hujjatlarni saytga qo'yib, URL kiritish
3. **P1: `GET /blocks`** — bloklashni ikki tomonlama qilish
4. **P1-2 + P3-3 birga** — qorong'i rejim va ranglar
5. Qolgan P1 lar: bildirishnoma sozlamalari, lenta bo'laklari, filtr UI
6. P2 ro'yxati

---

## Tekshirish usuli

```bash
# Backend
cd barter-platform && docker compose up -d
cd api && .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8010

# Shartnomani solishtirish
curl -s localhost:8010/openapi.json | python3 -m json.tool | less

# Ilova
cd app && flutter analyze && flutter test
flutter build ios --simulator --debug
```

Backend shartnomasi: [API.md](API.md) ·
O'zgarishlar: [BACKEND-CHANGELOG.md](BACKEND-CHANGELOG.md)
