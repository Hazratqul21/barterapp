# Boshqa AI'ga beriladigan topshiriq

Quyidagi matnni nusxalab, Flutter yozadigan AI'ga birinchi xabar sifatida
bering. Uning yoniga uchta faylni biriktiring:

- `docs/FLUTTER-BRIEF.md`
- `docs/API.md`
- `docs/DOMAIN.md`

---

## Nusxalash uchun matn

> Men BarterApp degan loyihaning Flutter mijozini yozishing kerak. Bu — naqd
> pulsiz ayirboshlash platformasi (O'zbekiston uchun), uch tilda: uz/ru/en,
> uchta platformada: web, iOS, Android.
>
> **Backend to'liq tayyor va o'zgartirilmasligi kerak.** U `http://127.0.0.1:8010`
> da ishlaydi, 27 ta endpoint, hammasi sinalgan. Sen faqat mijoz tomonini
> yozasan.
>
> Sizga uchta hujjat berilgan:
> - `FLUTTER-BRIEF.md` — asosiy topshiriq: har bir ekran, maket, xatti-harakat
> - `API.md` — API shartnomasi: har bir endpoint, so'rov va javob shakli
> - `DOMAIN.md` — biznes qoidalar: nega shunday ishlaydi
>
> **Loyihada allaqachon yozilgan va tegmaslik kerak:**
> - `lib/core/theme/` — ranglar va tema (`BarterPalette`: give/take/money)
> - `lib/core/network/api_client.dart` — token va til avtomatik qo'shiladi
> - `lib/core/router/` — go_router, tab bar va yon panel
> - `lib/core/widgets/common.dart` — `RemoteImage`, `Pill`, `EmptyState`, `ErrorState`, `TraderAvatar`
> - `lib/shared/models/models.dart` — **16 ta model tayyor**
> - `lib/features/*/data/*.dart` — **17 ta Riverpod provider tayyor**
> - `l10n/app_{uz,ru,en}.arb` — 145 ta tarjima kaliti
>
> **Ya'ni ma'lumot qatlami butunlay tayyor. Sen faqat UI yozasan.**
>
> **Yozilishi kerak bo'lgan 10 ta ekran** (`FLUTTER-BRIEF.md` 5-bo'limida
> har birining maketi va xatti-harakati bor):
> 1. Xabarlar ro'yxati — `/inbox`
> 2. Chat + kelishuv paneli — `/chat/:id`
> 3. Taklif yuborish paneli — `/offer/:listingId`
> 4. Mosliklar — `/matches`
> 5. Bildirishnomalar — `/notifications`
> 6. Profil — `/profile`
> 7. Savdogar profili — `/trader/:id`
> 8. E'lon yaratish — `/create`
> 9. Tasdiqlash — `/settings/verify`
> 10. To'lovlar — `/settings/payments`
>
> **Qat'iy qoidalar:**
> - Har bir ekranda to'rt holat: loading / error / empty / data
> - Xato matni serverdan keladi (`ApiException.message`) — o'zingniki bilan
>   almashtirma, u allaqachon o'zbekcha va odam tilida
> - Hech qanday qattiq kodlangan matn yo'q — hammasi `l10n` dan
> - Sana `DateFormat`, pul `Money.format(locale)` orqali — qo'lda yozma
> - `flutter analyze` → 0 muammo bo'lishi shart
> - Har ekranni 375px va 1280px kengliklarda tekshir
> - `FLUTTER-BRIEF.md` ning 10-bo'limidagi «Muhim tuzoqlar» jadvalini o'qi —
>   bular prototipda haqiqatan yuz bergan xatolar
>
> **Ishni boshlash:**
> ```bash
> cd barter-platform
> docker compose up -d
> cd api && .venv/bin/uvicorn app.main:app --port 8010 --reload   # boshqa terminalda
> cd ../app && flutter pub get && flutter gen-l10n && flutter run -d chrome
> ```
> Kirish: **+998901234122** (SMS kodi javobda qaytadi va o'zi to'ladi).
>
> Bittadan ekran yoz, har birini brauzerda tekshirib ko'r, keyin keyingisiga o't.
> Birinchi bo'lib «Xabarlar ro'yxati» va «Chat» dan boshla — ular mahsulotning
> yuragi.
>
> Backend'da biror narsa yetishmasa — o'zing qo'shma, menga ayt.

---

## Ish tugagach tekshirish

Har bir ekran uchun:

- [ ] `flutter analyze` → 0 muammo
- [ ] To'rt holat bor: loading / error / empty / data
- [ ] Uch tilda ham to'g'ri (kirill matn kesilmaydi)
- [ ] 375px va 1280px da tekshirilgan
- [ ] Qorong'i temada o'qish mumkin

Butun ilova uchun:

- [ ] Kirish → e'lon yaratish → taklif → chat → yakunlash zanjiri ishlaydi
- [ ] `flutter build web` o'tadi
