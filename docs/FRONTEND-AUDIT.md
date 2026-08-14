# Frontend audit — BarterApp (Flutter)

**Sana:** 2026-08-15 · **Tekshirdi:** senior developer tahlili (faqat o'qish, kod
o'zgartirilmagan) · **Qamrov:** `app/` — 46 Dart fayl, iOS/Android/Web sozlamalari

> **Bu hujjat kim uchun:** bu ishlarni bajaradigan AI yoki dasturchi uchun.
> Har bir topilma uchta narsani beradi: **nima noto'g'ri**, **qayerda** (fayl va
> qator), va **nima uchun muhim**. Yechim yozilmagan — qaror bajaruvchida.
>
> **Tartib majburiy:** P0 → P1 → P2. P0 bajarilmaguncha ilova do'konga
> tushmaydi, shuning uchun dizayn ustida ishlash P0 dan oldin — behuda mehnat.

---

## Umumiy xulosa

Kodning **sifati yaxshi**. `flutter analyze` deyarli toza (6 ta ishlatilmagan
import), 17 ta test o'tadi, arxitektura toza (feature-first, Riverpod 3,
go_router), uch til to'liq tarjima qilingan (273/273/273), Android imzo
sozlamasi va ProGuard to'g'ri qo'yilgan, web PWA manifesti bor.

Muammo sifatda emas — **to'liqlikda**. Ilova do'konga topshirilsa **rad
etiladi**, va sababi dizayn emas: uchta majburiy funksiya umuman yo'q. Bundan
tashqari bir nechta tugma **ishlayotgandek ko'rinadi, lekin hech narsa
qilmaydi** — bu foydalanuvchi uchun buzuq tugmadan yomonroq, chunki u ishlayapti
deb o'ylaydi.

| Daraja | Soni | Ma'nosi |
|---|---|---|
| **P0** | 4 | Do'kon rad etadi. Bularsiz reliz yo'q. |
| **P1** | 5 | Ishlayotgandek ko'rinib, ishlamaydigan narsalar |
| **P2** | 7 | Backend tayyor, mijoz ulanmagan |
| **P3** | 8 | Dizayn, kirish qulayligi, adaptivlik |
| **P4** | 5 | Gigiyena |

---

# P0 — Do'kon rad etadi

## P0-1. Hisobni o'chirish umuman yo'q

**Qayerda:** mijozda ham, backendda ham yo'q. `app/lib/features/profile/presentation/settings_page.dart` da faqat `logout` bor (154-qator). Backendda `DELETE /me` mavjud emas.

**Nega bu bloker:** Apple App Store Guideline **5.1.1(v)** — hisob yaratish
imkonini beradigan har qanday ilova **ilova ichida** hisobni o'chirish imkonini
ham berishi shart (2022-yil iyundan majburiy). Google Play ham 2024-yildan shuni
talab qiladi va qo'shimcha ravishda **veb orqali o'chirish havolasi** so'raydi.

Bu eng tez rad etiladigan bandlardan biri — tekshiruvchi uni birinchi
daqiqalarda qidiradi.

**Diqqat:** bu faqat UI ishi emas. Backendda ham endpoint kerak, va u nozik:
yakunlangan savdolar, sharhlar va boshqa odamning suhbatlari yo'qolmasligi
kerak. To'g'ri yechim — anonimlashtirish (`users` qatorini o'chirish emas,
shaxsiy maydonlarni tozalash), chunki savdo tarixi ikkinchi tomonga ham
tegishli.

## P0-2. Bloklash va shikoyat tugmalari yo'q

**Qayerda:** hech qayerda. `grep -rn "report\|block" lib/features/*/presentation/` — natija bo'sh.

**Nega bu bloker:** App Store Guideline **1.2 (User-Generated Content)** —
foydalanuvchi kontenti bor ilovada **shart**:
1. Nomaqbul kontentni filtrlash mexanizmi
2. **Shikoyat qilish** imkoni
3. **Foydalanuvchini bloklash** imkoni
4. Kontakt ma'lumotlari

Bu yerda uchtasi ham yo'q. Ilovada e'lonlar, suratlar, chat va profil bor —
ya'ni to'liq UGC platformasi.

**Muhim:** backend tomoni **allaqachon tayyor** (`POST/DELETE /blocks/{id}`,
`GET /blocks`, `POST /reports`). Faqat UI kerak. Batafsil —
[BACKEND-CHANGELOG.md](BACKEND-CHANGELOG.md) § Bloklash va shikoyat.

## P0-3. Maxfiylik siyosati havolasi yo'q

**Qayerda:** `settings_page.dart` — "privacy", "maxfiylik", "shartlar" so'zlari umuman yo'q.

**Nega bu bloker:** ikkala do'kon ham ilova ichida maxfiylik siyosatiga havola
talab qiladi. App Store Connect'da URL maydonini to'ldirish yetarli emas —
Apple ilovaning o'zida ham bo'lishini kutadi. Ilova shaxsiy ma'lumot yig'adi
(telefon raqami, joylashuv, suratlar), ya'ni bu majburiy.

Yonida: Foydalanish shartlari (Terms of Service) ham kerak, chunki bu
foydalanuvchilar o'rtasidagi bitim platformasi.

## P0-4. Ishlamaydigan "Apple bilan kirish" va "Google bilan kirish" tugmalari

**Qayerda:** [sign_in_page.dart:188-190](../app/lib/features/auth/presentation/sign_in_page.dart#L188)

```dart
_SocialButton(icon: Icons.apple, label: l.authWithApple, ... onPressed: () => _notYet(l)),
_SocialButton(icon: Icons.g_mobiledata, label: l.authWithGoogle, ... onPressed: () => _notYet(l)),
```

Ikkalasi ham `_notYet()` chaqiradi — ekranda "tez orada" snackbar chiqadi.

**Nega bu bloker:** Guideline **2.1 (App Completeness)** — placeholder va
ishlamaydigan funksiya rad etish sababi. Tekshiruvchi kirish ekranini birinchi
ko'radi va birinchi bosadigan narsa aynan shu tugmalar bo'ladi.

**Ikkinchi qatlam:** agar keyinchalik Google bilan kirish qo'shilsa, Guideline
**4.8** bo'yicha **Sign in with Apple** ham majburiy bo'ladi. Ya'ni "keyin
qo'shamiz" degan qaror ikkitasini birga qo'shishni anglatadi.

Eng arzon yechim — relizgacha ikkala tugmani ham yashirish.

---

# P1 — Ishlayotgandek ko'rinadi, lekin ishlamaydi

Bular P0 emas, lekin foydalanuvchi uchun buzuq tugmadan yomonroq: u bosadi,
javob ko'radi, ishonadi — va keyin ma'lumot yo'qolganini topadi.

## P1-1. "Saqlash" tugmasi hech narsani saqlamaydi

**Qayerda:** [listing_detail_page.dart:54](../app/lib/features/listing/presentation/listing_detail_page.dart#L54)

```dart
onToggleSave: () => setState(() => _saved = !_saved),
```

Tugma faqat mahalliy `bool` ni o'zgartiradi. API ga hech narsa yuborilmaydi.
Sahifadan chiqib qaytilsa — saqlangani yo'qoladi.

**Nega muhim:** foydalanuvchi e'lonni saqlaganiga ishonadi va uni qidirmaydi.
Ertaga qaytib kelganda ro'yxat bo'sh. Bu ishonchni yo'qotadigan xato turi.

Backend tayyor: `POST/DELETE /listings/{id}/favorite`, `GET /favorites`,
va `ListingCard.is_favorite` lentaning o'zida keladi.

## P1-2. "Dark Mode" tugmasi qorong'i rejimni yoqmaydi

**Qayerda:** [main.dart:50-52](../app/lib/main.dart#L50) va [settings_page.dart:104-108](../app/lib/features/profile/presentation/settings_page.dart#L104)

`MaterialApp.router` da `theme` va `darkTheme` bor, lekin **`themeMode` yo'q** —
ya'ni ilova doim tizim sozlamasiga ergashadi. Sozlamalardagi tugma esa
`_darkModeProvider` ni o'zgartiradi, uni esa **hech kim o'qimaydi**:

```
$ grep -rn "_darkModeProvider" lib/
settings_page.dart:20   (ta'rif)
settings_page.dart:88   (o'z ichida o'qish)
settings_page.dart:107  (o'z ichida yozish)
```

Tugma bosiladi, ikonka aylanadi, animatsiya ishlaydi — va ilovaning rangi
o'zgarmaydi.

## P1-3. Lentada filtr va saralash UI si yo'q

**Qayerda:** `feed_page.dart` da faqat `TextField` (335-qator). `min_value`,
`max_value`, `region`, `cash_ok`, `sort` — hech biri yuborilmaydi.

Backend bularning hammasini qo'llab-quvvatlaydi. Barter bozorida narx oralig'i
va viloyat bo'yicha filtr — asosiy ehtiyoj (traktorni qo'shni tumandan izlash
bilan mamlakat bo'ylab izlash butunlay boshqa tajriba).

## P1-4. Push-bildirishnoma umuman ulanmagan

**Qayerda:** `pubspec.yaml` da `firebase_messaging` yoki boshqa push paketi
**yo'q**. `POST /devices` hech qayerdan chaqirilmaydi.

Backendda navbat, sozlamalar va sokin soatlar tayyor. Mijoz tomoni butunlay
yo'q. Barterda bu jiddiy: **taklif 48 soatda eskiradi**, odam esa ilovani
ochmagani uchun uni boy beradi.

Qo'shilganda Android 13+ uchun `POST_NOTIFICATIONS` ruxsati va iOS uchun Push
Notifications entitlement ham kerak bo'ladi.

## P1-5. Hodisalar (analytics) yuborilmaydi

**Qayerda:** `POST /events` hech qayerdan chaqirilmaydi.

**Nega bu shoshilinch:** bu ma'lumotni **orqaga qaytib yig'ib bo'lmaydi**. Kod
keyin ham yoziladi, lekin bugun yozilmagan hodisa butunlay yo'qoladi. Har
kechiktirilgan kun — qaytarib bo'lmaydigan yo'qotish.

Mijozdan kutilayotgani: `listing_impression`, `listing_dwell`,
`filter_applied`, `match_shown`, `match_opened`, `match_dismissed`,
`chat_opened`. Batafsil — [API.md](API.md) § 7.10.

⚠️ `dedupe_key` ni albatta yuborish kerak, aks holda takroriy yuborishda CTR
ikki barobar past ko'rinadi.

---

# P2 — Backend tayyor, mijoz ulanmagan

| Endpoint | Holat | Izoh |
|---|---|---|
| `POST /listings/{id}/favorite` | ❌ | P1-1 ga qarang |
| `GET /favorites` | ❌ | "Saqlanganlar" ekrani yo'q |
| `PATCH /listings/{id}` | ❌ | E'lonni tahrirlash imkoni yo'q |
| `DELETE /listings/{id}` | ❌ | E'lonni o'chirish imkoni yo'q |
| `POST/DELETE /blocks/{id}`, `GET /blocks` | ❌ | P0-2 |
| `POST /reports` | ❌ | P0-2 |
| `POST /devices` | ❌ | P1-4 |
| `GET/PATCH /notification-settings` | ❌ | Sozlamalarda ekran yo'q |
| `POST /events` | ❌ | P1-5 |
| `GET /categories` | ✅ | Ulangan |
| `GET /ws-ticket` | ✅ | To'g'ri ulangan ([trade_repository.dart:463](../app/lib/features/trade/data/trade_repository.dart#L463)) |

**E'lonni tahrirlash alohida e'tibor talab qiladi:** hozir e'lon bir marta
yoziladi va hech qachon o'zgartirilmaydi. Xato narx yozgan odam uchun yagona
chora — yangi e'lon joylash. Backend `409` qaytaradi agar jonli taklif bo'lsa —
UI buni "avval takliflarni yakunlang" deb tushuntirishi kerak.

---

# P3 — Dizayn, kirish qulayligi, adaptivlik

## P3-1. Matn kattalashtirilganda layout buziladi

`textScaler` bilan ishlash **umuman yo'q** (grep: 0 ta natija), lekin qattiq
yozilgan balandliklar **48 ta**:

```
grep -rn "height: [0-9]\{2,\}" lib/features/*/presentation/ lib/core/widgets/ | wc -l
→ 48
```

Foydalanuvchi tizim sozlamalarida shriftni kattalashtirsa (O'zbekistonda
keksaroq foydalanuvchilar buni tez-tez qiladi), matn qattiq konteynerlardan
toshib chiqadi.

**Tekshirish usuli:** iOS Simulator → Settings → Accessibility → Larger Text →
eng katta. Android → Display → Font size → Largest.

## P3-2. Ikonkali tugmalarda yorliq yo'q

18 ta `IconButton` bor, `Semantics`/`tooltip` esa 12 ta faylda atigi bittadan.
Ya'ni ekran o'qigich (VoiceOver / TalkBack) foydalanuvchisi uchun ko'p tugmalar
"tugma" deb o'qiladi, nima qilishi aytilmaydi.

Bu rad etish sababi emas, lekin Apple accessibility auditi buni belgilaydi.

## P3-3. Qattiq ranglar qorong'i rejimda buziladi

`Colors.white` / `Colors.black` / `Color(0xFF...)` — presentation qatlamida
**31 ta**. Masalan [feed_page.dart:305-321](../app/lib/features/feed/presentation/feed_page.dart#L305) da sarlavha oq matn bilan yozilgan.

P1-2 tuzatilib, qorong'i rejim haqiqatan yoqilganda bu joylar o'qilmaydigan
bo'lib qoladi (oq fonda oq matn). **Ikkalasi birga tuzatilishi kerak** — aks
holda bitta xato ikkinchisini yaratadi.

## P3-4. Tarjima qilinmagan matnlar

To'liq tarjima (273/273/273) fonida bir nechta qattiq yozilgan satr qolgan:

| Matn | Qayerda |
|---|---|
| `'Dark Mode'` | [settings_page.dart:104](../app/lib/features/profile/presentation/settings_page.dart#L104) |
| `'Kategoriyalarni yuklashda xatolik'` | [feed_page.dart:410](../app/lib/features/feed/presentation/feed_page.dart#L410) |
| `'MATCH'` | [matches_page.dart:219](../app/lib/features/trade/presentation/matches_page.dart#L219) |
| `'OK'` | [matches_page.dart:114](../app/lib/features/trade/presentation/matches_page.dart#L114) |

`'UZ'`/`'RU'`/`'EN'` va `'•••• 1234'` kabilar to'g'ri — ular tarjima
qilinmasligi kerak.

## P3-5. Kichik ekranlar tekshirilmagan

Adaptiv joylashuv 14 ta joyda ishlatilgan, lekin hammasi **kengaytirish**
uchun (`>= kWebBreakpoint`). Kichik tomon — 320pt kenglikdagi telefon
(iPhone SE 1-avlod, arzon Android'lar) — himoyalanmagan.

O'zbekiston bozorida arzon Android katta ulush egallaydi, ya'ni bu nazariy
muammo emas.

## P3-6. Sozlamalarda ekranlar yetishmayapti

Hozirgi sozlamalar: til, Dark Mode (ishlamaydi), chiqish. Yetishmayotgani:

- Bildirishnoma sozlamalari (backend tayyor)
- Bloklangan foydalanuvchilar ro'yxati (P0-2)
- Maxfiylik siyosati va shartlar (P0-3)
- Hisobni o'chirish (P0-1)
- Ilova versiyasi va qo'llab-quvvatlash aloqasi

## P3-7. Xato ekranida `request_id` ko'rsatilmaydi

Backend endi har 500 javobida `request_id` qaytaradi — server logidagi to'liq
traceback shu id orqali topiladi. Mijoz uni ko'rsatmaydi.

Foydalanuvchi skrinshot yuborsa, sabab bir daqiqada topiladi. Bu kichik detal,
lekin qo'llab-quvvatlash oqimini butunlay o'zgartiradi.

## P3-8. Offline holati to'liq emas

`isNetworkFailure` atigi 3 ta faylda ishlatiladi. Qolgan ekranlarda tarmoq
yo'qligi va server xatosi bir xil ko'rinadi.

---

# P4 — Gigiyena

## P4-1. Ishlatilmayotgan paketlar

| Paket | Import qilingan fayllar |
|---|---|
| `genkit: ^0.15.1` | **0** |
| `video_player: ^2.14.0` | **0** |
| `http: ^1.6.0` | **0** (dio ishlatiladi) |

Uchalasi ham ilova hajmini oshiradi va `video_player` iOS'da qo'shimcha
ruxsatlar so'rashi mumkin — bu tekshiruvda savol tug'diradi.

## P4-2. Ishlatilmayotgan importlar (6 ta)

`flutter analyze` ko'rsatadi:

```
app_router.dart:5      ../theme/tokens.dart
app_shell.dart:1       package:animations/animations.dart
feed_banner.dart:6,9,12  flutter_svg, girih.dart, backgrounds.dart
intro_page.dart:2      flutter_animate
```

## P4-3. Versiya raqami relizga tayyor emas

`pubspec.yaml`: `version: 0.1.0+1`. Do'konga topshirishdan oldin `1.0.0+1`
ga ko'tarilishi kerak. iOS tomonda `MARKETING_VERSION = 1.0` allaqachon shunday
turibdi — ikkalasi mos kelmayapti.

## P4-4. Android `applicationId` da TODO izohi qolgan

[build.gradle.kts](../app/android/app/build.gradle.kts) da Flutter
shablonidan qolgan izoh:

```kotlin
// TODO: Specify your own unique Application ID (...)
applicationId = "uz.barterapp.barter_app"
```

Qiymat to'g'ri, faqat izoh olib tashlanishi kerak.

**Diqqat — nomlar mos emas:**
- Android: `uz.barterapp.barter_app` (pastki chiziq)
- iOS: `uz.barterapp.barterApp` (camelCase)

Bu texnik jihatdan xato emas, lekin analitika, deep link va Firebase
sozlashda chalkashlik keltirib chiqaradi. Bir marta tanlab, ikkalasini
moslashtirish arzonroq — **relizdan keyin `applicationId` ni o'zgartirib
bo'lmaydi** (Play Store uni yangi ilova deb qabul qiladi).

## P4-5. 14 ta paket eskirgan

`flutter pub outdated` — jiddiy emas, lekin relizdan oldin bir marta
yangilash kerak.

---

# Nima yaxshi (buzmang)

Bular ataylab o'ylangan va to'g'ri qilingan — tegmaslik kerak:

1. **`AndroidManifest.xml` dagi `INTERNET` ruxsati** — izohda aytilganidek, u
   ilgari faqat debug manifestda edi va reliz APK hech qanday so'rov
   yubora olmasdi. To'g'ri tuzatilgan.

2. **Reliz imzosi** — `key.properties` yo'q bo'lsa debug kalit bilan imzolaydi
   **va ogohlantirish chiqaradi**. Jim qolib, yaroqsiz paket berish o'rniga.

3. **`defaultApiBaseUrl()` reliz rejimida xato tashlaydi** — `API_BASE_URL`
   berilmasa build yiqiladi. Aks holda do'kondagi ilova `localhost` ga
   ulanishga urinib, "server ishlamayapti" bo'lib ko'rinardi.

4. **`NSAllowsLocalNetworking`** — `NSAllowsArbitraryLoads` emas. Tekshiruvda
   izoh talab qilmaydi va relizda teshik qoldirmaydi.

5. **WebSocket chiptasi** — `GET /ws-ticket` to'g'ri ulangan. Access token
   URL'ga tushmaydi.

6. **Shriftlar bundle qilingan**, `google_fonts` orqali yuklanmaydi. Sekin
   internetda birinchi ochilish to'g'ri ko'rinadi.

7. **ProGuard va resurs qisqartirish** yoqilgan.

8. **Uch til to'liq** — 273/273/273, hech bir tilda bo'sh joy yo'q.

---

# Tavsiya etilgan tartib

**1-bosqich — do'kon uchun (P0).** Bularsiz qolgan hamma ish behuda, chunki
ilova do'konga tushmaydi:

1. Hisobni o'chirish (backend + UI) — eng katta ish, backend tomoni ham kerak
2. Bloklash va shikoyat UI si — backend tayyor, faqat ekranlar
3. Maxfiylik siyosati va shartlar havolasi
4. Apple/Google kirish tugmalarini yashirish

**2-bosqich — yolg'on tugmalarni tuzatish (P1).** Ishlayotgandek ko'rinib
ishlamaydigan narsalar buzuq tugmadan yomonroq:

5. Saqlash tugmasini API ga ulash
6. `themeMode` ni ulash **va** shu bilan birga qattiq ranglarni tuzatish (P3-3)
7. Hodisalarni yuborishni boshlash — **har kun kechikish qaytarib bo'lmaydigan
   yo'qotish**

**3-bosqich — funksiyalarni to'ldirish (P2).** Filtr, tahrirlash, push,
bildirishnoma sozlamalari.

**4-bosqich — sayqal (P3, P4).** Kirish qulayligi, kichik ekranlar, gigiyena.

---

## Tekshirish ro'yxati (relizdan oldin)

- [ ] `flutter analyze` — 0 ta ogohlantirish
- [ ] `flutter test` — hammasi yashil
- [ ] `flutter build appbundle --release --dart-define=API_BASE_URL=https://...` — imzo ogohlantirishisiz
- [ ] `flutter build ipa --release --dart-define=API_BASE_URL=https://...`
- [ ] iPhone SE (320pt) da har bir ekran
- [ ] Eng katta shrift o'lchamida har bir ekran
- [ ] VoiceOver yoqilgan holda asosiy oqim
- [ ] Qorong'i rejimda har bir ekran
- [ ] Aviarejimda (offline) har bir ekran
- [ ] Uch tilda har bir ekran

---

## Metodologiya

Statik tahlil: `flutter analyze`, `flutter test`, `flutter pub outdated`, kod
o'qish (46 fayl), iOS `Info.plist` va `project.pbxproj`, Android manifest va
`build.gradle.kts`, `web/` sozlamalari, `pubspec.yaml`, l10n fayllari
taqqoslash, backend API shartnomasi bilan solishtirish.

**Qilinmagan:** haqiqiy qurilmada ishga tushirish, ekranlarni ko'z bilan
ko'rish, rang kontrastini o'lchash. Shuning uchun dizaynning **vizual**
tomoni (bo'shliqlar, burchaklar, animatsiya silliqligi) bu hisobotda yo'q —
u simulyatorda ko'rish talab qiladi.
