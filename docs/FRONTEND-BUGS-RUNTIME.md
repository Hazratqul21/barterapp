# Ishga tushirish hisoboti — iPhone 17 simulyatorida

**Sana:** 2026-08-18 · **Muhit:** Xcode 26.6, iOS simulyator (iPhone 17),
debug build, backend `127.0.0.1:8010` da ishlab turgan holda.

> Bu hujjat [FRONTEND-AUDIT.md](FRONTEND-AUDIT.md) ning davomi. U statik
> tahlil edi — bu esa **haqiqatan ishga tushirilgan** ilovada ko'rilgani.
> Kodga tegilmagan.

---

## Xulosa

Ilova **quriladi va ishga tushadi**. `flutter analyze` toza — 0 xato
(avvalgi 6 ta ishlatilmagan import tuzatilgan). `flutter test` — 17 test
o'tadi.

Lekin ishga tushishning **birinchi soniyasida qayta ishlanmagan istisno**
chiqadi va u yangi qo'shilgan Firebase kodidan. Statik tahlilda bu
ko'rinmagan edi, chunki kod kompilyatsiya bo'ladi — u faqat **ishlaganda**
yiqiladi.

| Daraja | Soni |
|---|---|
| **R0** — ishga tushishda yiqiladi | 1 |
| **R1** — funksiya umuman ishlamaydi | 3 |
| **R2** — ko'rinadigan nuqson | 3 |

---

# R0 — Ishga tushishda qayta ishlanmagan istisno

## R0-1. Firebase sozlanmagan, lekin chaqirilyapti

**Simulyator logidan, aynan ko'chirilgan:**

```
flutter: Firebase init failed: [core/not-initialized]
         Firebase has not been correctly initialized.
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception:
         [core/no-app] No Firebase App '[DEFAULT]' has been created
         - call Firebase.initializeApp()
```

**Sabab.** `pubspec.yaml` ga `firebase_core` va `firebase_messaging`
qo'shilgan, lekin konfiguratsiya fayllarining **hech biri yo'q**:

```
ios/Runner/GoogleService-Info.plist   ❌ yo'q
android/app/google-services.json      ❌ yo'q
lib/firebase_options.dart             ❌ yo'q
```

`main.dart` da `Firebase.initializeApp()` `try/catch` ichida — bu to'g'ri,
u xatoni yutadi. **Lekin** darhol keyin `_BarterAppState.initState()`
`notificationServiceProvider.init()` ni chaqiradi, u esa
`FirebaseMessaging.instance` ga murojaat qiladi — **himoyasiz**. Shu yerda
istisno chiqadi.

**Fayllar:**
- [main.dart:19](../app/lib/main.dart#L19) — `initializeApp` guard bilan
- [main.dart:49](../app/lib/main.dart#L49) — `init()` guardsiz chaqiriladi
- [notification_service.dart:11](../app/lib/core/notifications/notification_service.dart#L11) — `FirebaseMessaging.instance`

**Nega jiddiy:** release rejimida bu ilova ishga tushishida **qora ekran
yoki kutilmagan yopilish** berishi mumkin. App Store ko'rigida ilova
birinchi ochilishda yiqilsa — bu darhol rad etish.

---

# R1 — Funksiya umuman ishlamaydi

## R1-1. `POST /devices` shartnomaga mos emas — har doim 422

Mijoz yuboradi ([notification_service.dart:22](../app/lib/core/notifications/notification_service.dart#L22)):

```dart
body: {'fcm_token': token, 'platform': 'ios'}
```

Server kutadi ([API.md](API.md) § 7.8):

```json
{ "token": "...", "platform": "ios|android|web", "locale": "uz" }
```

`fcm_token` degan maydon serverda **yo'q**, `token` esa majburiy. Ya'ni
Firebase sozlangan taqdirda ham har bir so'rov **422** qaytaradi.

**Va buni hech kim bilmaydi:** `catch (e) { // Ignored for now }` xatoni
jimgina yutadi. Push umuman ishlamaydi, loglarda ham iz qolmaydi.

## R1-2. Platforma qattiq `'ios'` deb yozilgan

O'sha qatorda `'platform': 'ios'`. Android telefondan kelgan qurilma ham
serverda `ios` bo'lib yoziladi. Push transporti ulanganda xabarlar
noto'g'ri xizmatga yuboriladi.

`Platform.isAndroid` / `kIsWeb` orqali aniqlash kerak.

## R1-3. Chiqishda qurilma o'chirilmaydi

`DELETE /devices/{token}` hech qayerdan chaqirilmaydi. Telefondan chiqqan
odam bildirishnoma olishda davom etadi — bu maxfiylik muammosi, ayniqsa
telefon boshqa odamga o'tsa.

---

# R2 — Ko'rinadigan nuqsonlar

## R2-1. Lentaning tepasida bo'sh oq karta

Qidiruv maydoni ostida hech narsa yozilmagan katta oq to'rtburchak bor
(taxminan 120pt balandlik). U hech qanday mazmun ko'rsatmaydi va faqat
joy egallaydi.

## R2-2. Banner rasmi noto'g'ri kesilgan

Sarlavha banneridagi 3D rasm o'ng tomondan kesilgan va chap chetida
kulrang to'rtburchak chiziq ko'rinadi — konteyner va rasm o'lchamlari
mos kelmayapti.

Bildirishnoma qo'ng'irog'i rasmning ustida turadi, kontrast past.

## R2-3. Aylantirganda karta status bar ostiga kiradi

Lentani aylantirganda e'lon kartasi soat va batareya ustiga chiqadi:
narx pili "400 000 so'm" kesiladi, soat "13:00" karta rasmiga tushadi.
Yuqori xavfsiz zona hisobga olinmagan yoki scrim yo'q.

---

# Tekshirilgan va ishlaydigan narsalar

Bularni buzmaslik kerak:

| Narsa | Holat |
|---|---|
| iOS qurilishi | ✅ `flutter build ios --simulator` xatosiz |
| `flutter analyze` | ✅ 0 xato |
| `flutter test` | ✅ 17/17 |
| Splash → intro → lenta oqimi | ✅ |
| Lenta yuklanishi va e'lon kartalari | ✅ |
| Kategoriya rasmlari | ✅ |
| Pastki panel va tablar | ✅ |
| Profil (kirmagan holat) | ✅ |
| Backend bilan aloqa | ✅ |

---

# Qanday takrorlash

```bash
# 1. Baza va API
cd barter-platform && docker compose up -d
cd api && .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8010

# 2. Simulyator
xcrun simctl boot "iPhone 17"
cd ../app && flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted uz.barterapp.barterApp

# 3. Xatolarni ko'rish
xcrun simctl spawn booted log stream --predicate 'processImagePath CONTAINS "Runner"' \
  | grep -iE "exception|error|overflow"
```
