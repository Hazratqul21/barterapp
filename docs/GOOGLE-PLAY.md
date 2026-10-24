# MAB'ni Google Play'ga chiqarish

Paket ID: `uz.mab.app`. Versiya `app/pubspec.yaml` dagi `version: 1.0.0+1`
(`+` dan keyingi raqam — versionCode; har yangi yuklashda bittaga oshiring).

## 0. Play Console hisobi

1. https://play.google.com/console → ro'yxatdan o'tish (bir martalik $25).
2. Hisob turi:
   - **Shaxsiy** — tez ochiladi, lekin yangi shaxsiy hisoblar production'ga
     chiqishdan oldin **yopiq test** o'tkazishi shart: kamida 12 tester,
     ketma-ket 14 kun.
   - **Tashkilot** (MChJ) — D-U-N-S raqami kerak, lekin 12 tester talabi yo'q.
3. Shaxsni tasdiqlash (pasport) bir necha kun olishi mumkin.

## 1. Imzo kaliti (Mac'da, bir marta)

```sh
keytool -genkey -v -keystore ~/mab-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cd ~/Desktop/barter-platform/app
cp android/key.properties.example android/key.properties
# key.properties ichida parollarni va storeFile=/Users/<siz>/mab-upload.jks ni yozing
```

`mab-upload.jks` va parolni parol menejeriga + zaxiraga saqlang. Git'ga
tushmaydi (`android/.gitignore`).

## 2. Paketni qurish

```sh
cd ~/Desktop/barter-platform/app
git pull origin develop
flutter clean && flutter pub get
flutter build appbundle --release
# natija: build/app/outputs/bundle/release/app-release.aab
```

Reliz sukut bo'yicha `https://api.mab.uz` ga ulanadi, hujjatlar
`https://mab.uz/privacy`, `/terms`, `/offer` ga ochiladi. Kalit yo'q bo'lsa,
build ataylab to'xtaydi — debug kalit bilan imzolangan .aab'ni Play qabul
qilmaydi.

## 3. Play Console'da ilova yaratish

1. **Create app** → nomi `MAB`, til o'zbek, App, Free.
2. **Testing → Internal testing → Create release** → `app-release.aab` ni
   yuklang. "Play App Signing" taklifini qabul qiling.
3. Testerlar ro'yxatiga o'z Gmail'ingizni qo'shing, havola orqali telefonga
   o'rnatib tekshiring.

## 4. "App content" bo'limi (majburiy)

| Band | Nima yoziladi |
|---|---|
| Privacy policy | `https://mab.uz/privacy` |
| App access | Ko'rib chiquvchi uchun kirish usuli: test telefon raqami + kod yoki parolli hisob. Bu yozilmasa, ilova rad etiladi |
| Ads | Yo'q |
| Content rating | So'rovnoma: foydalanuvchilar o'zaro yozishadi (chat), foydalanuvchi kontenti bor |
| Target audience | 18+ |
| Data safety | Telefon, ism, email (Google), rasmlar, xabarlar; shifrlangan uzatish (HTTPS); hisobni o'chirish mumkin |
| Account deletion | Ilova ichida: Sozlamalar → Hisobni o'chirish; veb: `https://mab.uz/delete-account` |
| Government / Financial features | Moliyaviy xizmat emas |

## 5. Do'kon sahifasi (Main store listing)

- Qisqa tavsif (≤80 belgi), to'liq tavsif (≤4000)
- Ikonka 512×512 PNG
- Feature graphic 1024×500
- Telefon skrinshotlari: kamida 2 ta (9:16)

## 6. Google orqali kirish (Android)

Play'ga birinchi yuklashdan keyin: **Play Console → Test and release →
App integrity → App signing** dan **SHA-1** ni oling. So'ng Google Cloud
Console → Credentials → **Android** OAuth client: paket `uz.mab.app` + shu
SHA-1. Upload kalitning SHA-1 sini ham qo'shing (lokal test uchun):

```sh
keytool -list -v -keystore ~/mab-upload.jks -alias upload | grep SHA1
```

## 7. To'lovlar haqida muhim eslatma

Google Play qoidasi: ilova ichida **raqamli** xizmat (e'lonni ko'tarish,
qo'shimcha e'lon kvotasi) sotilsa, Google Play Billing ishlatilishi shart.
Payme orqali to'lov Android ilovada qoidani buzadi va ilova rad etilishi
mumkin. Variantlar:

1. Birinchi relizda Android ilovada tariflar/to'lov bo'limini yashirish
   (to'lov faqat mab.uz saytida qoladi).
2. Google Play Billing'ni qo'shish (alohida ish).

## 8. Production'ga chiqarish

Internal → (shaxsiy hisob bo'lsa: Closed testing, 12 tester × 14 kun) →
**Production → Create release** → o'sha .aab → Review. Ko'rib chiqish
odatda 1–7 kun.
