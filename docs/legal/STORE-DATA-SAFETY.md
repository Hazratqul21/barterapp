# Do'kon formalari — tayyor javoblar

App Store "App Privacy" va Google Play "Data safety" formalarini
to'ldirish uchun. Har bir javob kodda haqiqatan nima bo'layotganiga
asoslangan.

⚠️ **Bu formalar yolg'on to'ldirilsa, ilova olib tashlanadi.** Apple va
Google buni tekshiradi va nomuvofiqlik topilsa, reliz to'xtatiladi.
Shuning uchun kod o'zgarganda bu faylni ham yangilang.

---

# 1. App Store — App Privacy

App Store Connect → App Privacy → **"Does this app collect data?"** → **Yes**

## 1.1 Contact Info

| Ma'lumot | Yig'iladimi | Maqsad | Shaxsga bog'liqmi | Kuzatish uchunmi |
|---|---|---|---|---|
| **Phone Number** | ✅ Ha | App Functionality | ✅ Ha | ❌ Yo'q |
| **Name** | ✅ Ha | App Functionality | ✅ Ha | ❌ Yo'q |
| Email Address | ❌ Yo'q | — | — | — |
| Physical Address | ✅ Ha | App Functionality | ✅ Ha | ❌ Yo'q |
| Other Contact Info | ❌ Yo'q | — | — | — |

> Telefon raqami — yagona kirish usuli. Manzil ixtiyoriy va faqat egasiga
> ko'rinadi.

## 1.2 User Content

| Ma'lumot | Yig'iladimi | Maqsad | Shaxsga bog'liqmi | Kuzatish uchunmi |
|---|---|---|---|---|
| **Photos or Videos** | ✅ Ha | App Functionality | ✅ Ha | ❌ Yo'q |
| **Customer Support** | ❌ Yo'q | — | — | — |
| **Other User Content** | ✅ Ha | App Functionality | ✅ Ha | ❌ Yo'q |

> "Other User Content" — e'lon matnlari, xabarlar, sharhlar.
>
> ⚠️ **Emails or Text Messages** ni belgilamang: bu SMS/emailingizni
> o'qish degani. Ilova ichidagi suhbat "Other User Content" ga kiradi.

## 1.3 Identifiers

| Ma'lumot | Yig'iladimi | Izoh |
|---|---|---|
| **User ID** | ✅ Ha | Hisob identifikatori. Maqsad: App Functionality, Analytics |
| **Device ID** | ❌ Yo'q | Reklama identifikatori olinmaydi |

> **Muhim:** push tokeni Apple hujjatlarida "Device ID" emas. Uni
> belgilamang — aks holda "Tracking" savoli ochilib ketadi.

## 1.4 Location

| Ma'lumot | Yig'iladimi | Maqsad | Shaxsga bog'liqmi |
|---|---|---|---|
| **Coarse Location** | ✅ Ha | App Functionality | ✅ Ha |
| Precise Location | ❌ Yo'q | — | — |

> ⚠️ Bu nozik nuqta. Ilova **GPS'ga umuman murojaat qilmaydi** —
> koordinatalar foydalanuvchi qo'lda tanlagan **viloyat markazidan**
> olinadi. Lekin natija baribir taxminiy joylashuv, shuning uchun
> "Coarse Location" belgilanadi. Belgilamaslik — nomuvofiqlik xavfi.

## 1.5 Usage Data

| Ma'lumot | Yig'iladimi | Maqsad | Shaxsga bog'liqmi | Kuzatish uchunmi |
|---|---|---|---|---|
| **Product Interaction** | ✅ Ha | Analytics, App Functionality | ✅ Ha | ❌ Yo'q |
| Advertising Data | ❌ Yo'q | — | — | — |
| Other Usage Data | ❌ Yo'q | — | — | — |

## 1.6 Diagnostics

| Ma'lumot | Yig'iladimi |
|---|---|
| Crash Data | ❌ Yo'q *(crash SDK ulanmagan)* |
| Performance Data | ❌ Yo'q |
| Other Diagnostic Data | ❌ Yo'q |

> Keyinchalik Crashlytics yoki Sentry qo'shilsa, buni **Yes** ga
> o'zgartirish shart.

## 1.7 Financial Info

| Ma'lumot | Yig'iladimi |
|---|---|
| Payment Info | ❌ Yo'q |

> To'lov kartasi ma'lumotlari serverga yetib bormaydi. To'lov tizimi
> ulanganda bu javob o'zgaradi.

## 1.8 Tracking

**"Does this app track users?"** → **❌ NO**

Sabab: hech qanday reklama tarmog'i yo'q, IDFA olinmaydi, ma'lumot
ma'lumot brokerlariga berilmaydi, boshqa kompaniyalarning ma'lumoti
bilan birlashtirilmaydi.

➡️ **Natija:** `NSUserTrackingUsageDescription` va ATT ruxsat oynasi
**kerak emas**. Uni qo'shish aksincha rad etishga olib kelishi mumkin —
Apple sababsiz so'ralgan ruxsatni yoqtirmaydi.

---

# 2. Google Play — Data safety

Play Console → App content → Data safety

## 2.1 Umumiy savollar

| Savol | Javob |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** |
| Data deletion URL | `{{VEB_SAYT}}/hisobni-ochirish` |

## 2.2 Ma'lumot turlari

| Kategoriya | Tur | Yig'iladi | Ulashiladi | Majburiymi | Maqsad |
|---|---|---|---|---|---|
| **Personal info** | Name | ✅ | ❌ | Ixtiyoriy | App functionality |
| | Phone number | ✅ | ❌ | **Majburiy** | Account management |
| | Address | ✅ | ❌ | Ixtiyoriy | App functionality |
| | Other info | ✅ | ❌ | Ixtiyoriy | App functionality |
| **Location** | Approximate location | ✅ | ❌ | Ixtiyoriy | App functionality |
| | Precise location | ❌ | — | — | — |
| **Photos and videos** | Photos | ✅ | ❌ | Ixtiyoriy | App functionality |
| **Messages** | Other in-app messages | ✅ | ❌ | Ixtiyoriy | App functionality |
| **App activity** | App interactions | ✅ | ❌ | Ixtiyoriy | Analytics, App functionality |
| | In-app search history | ✅ | ❌ | Ixtiyoriy | Analytics, App functionality |
| | Other user-generated content | ✅ | ❌ | Ixtiyoriy | App functionality |
| **App info and performance** | Crash logs | ❌ | — | — | — |
| **Device or other IDs** | Device or other IDs | ❌ | — | — | — |
| **Financial info** | — | ❌ | — | — | — |

> **"Ulashiladi" (Shared) hamma joyda ❌.** Eskiz'ga telefon raqami
> yuborilishi Google ta'rifi bo'yicha "sharing" emas — u bizning
> nomimizdan ishlaydigan xizmat ko'rsatuvchi (service provider).

> **"Other info"** — profil matni (bio) va biznes ma'lumotlari (korxona
> nomi, STIR).

## 2.3 Har bir tur uchun qo'shimcha savollar

| Savol | Javob |
|---|---|
| Is this data processed ephemerally? | **No** (bazada saqlanadi) |
| Is data collection required, or can users choose? | Telefon — **Required**, qolgani — **Optional** |
| Why is this user data collected? | Yuqoridagi jadvalga qarang |

---

# 3. Play Console — boshqa bo'limlar

| Bo'lim | Javob |
|---|---|
| **App category** | Shopping *(yoki Lifestyle)* |
| **Content rating** | So'rovnomani to'ldiring. UGC va foydalanuvchilar aloqasi bor → **PEGI 12 / Teen** atrofida chiqadi |
| **Target audience** | 18+ |
| **Ads** | **No ads** |
| **News app** | No |
| **COVID-19 apps** | No |
| **Government apps** | No |
| **Financial features** | **None** *(to'lov tizimi ulanmagunicha)* |
| **Privacy policy** | `{{VEB_SAYT}}/maxfiylik` |
| **Data deletion** | `{{VEB_SAYT}}/hisobni-ochirish` |

## 3.1 UGC deklaratsiyasi (majburiy)

Play Console UGC ilovalar uchun moderatsiya vositalarini so'raydi.
Javob:

- ✅ Foydalanuvchilar kontent ustidan **shikoyat qila oladi**
  (`POST /reports`, 6 ta sabab bilan)
- ✅ Foydalanuvchilar bir-birini **bloklay oladi** (`POST /blocks/{id}`)
- ✅ Moderator navbati mavjud (`GET /admin/reports`)
- ✅ Moderator e'lonni olib tashlay oladi
  (`POST /admin/listings/{id}/archive`)
- ✅ Taqiqlangan kontent ro'yxati Foydalanish shartlarining 3-bandida

---

# 4. Nomuvofiqlikni tekshirish ro'yxati

Formani topshirishdan oldin har bir qatorni kod bilan solishtiring:

- [ ] Ilovada crash SDK **yo'q**ligini tasdiqlang (`grep -ri "crashlytics\|sentry" app/`)
- [ ] Reklama SDK **yo'q**ligini tasdiqlang (`grep -ri "admob\|facebook" app/`)
- [ ] GPS ruxsati **so'ralmasligini** tasdiqlang (`grep -ri "geolocator\|location" app/pubspec.yaml`)
- [ ] `NSUserTrackingUsageDescription` **yo'q**ligini tasdiqlang
- [ ] Hisobni o'chirish ilovada **ishlashini** tekshiring
- [ ] Maxfiylik siyosati URL'i **ochilishini** tekshiring
- [ ] Hisobni o'chirish URL'i **ochilishini** tekshiring

## Qachon qayta to'ldirish kerak

| O'zgarish | Ta'sir |
|---|---|
| Crashlytics / Sentry qo'shilsa | Diagnostics → **Yes** |
| Reklama qo'shilsa | Tracking → **Yes**, ATT oynasi kerak bo'ladi |
| To'lov ulansa | Financial info → **Yes** |
| Aniq GPS qo'shilsa | Precise Location → **Yes** |
| Uchinchi tomon analitikasi qo'shilsa | "Shared" ustuni o'zgaradi |

Bularning har biri — **yangi reliz** talab qiladigan o'zgarish, chunki
forma ilova versiyasiga bog'langan.
