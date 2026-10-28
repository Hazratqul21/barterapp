# MAB'ni Google Play'ga joylash — to'liq qo'llanma

Bu qo'llanma **hammasi tayyor bo'lganda** bir marta, boshidan oxirigacha
bajariladi. Har bir qadam tartib bilan: oldingisi tugamasdan keyingisiga
o'tmang.

- Paket ID: `uz.mab.app` (o'zgarmaydi — Play'ga bir marta yuklangach,
  almashtirib bo'lmaydi)
- Versiya: `app/pubspec.yaml` → `version: 1.0.0+1`. `+` dan keyingi raqam
  (versionCode) **har yangi yuklashda bittaga oshadi**: `1.0.1+2`, `1.0.2+3`…
- Do'kon matnlari, ikonka va banner: `docs/play/`

---

## 0-bosqich. Chiqarishdan oldingi tekshiruv ro'yxati

Bularning hammasi ✅ bo'lmaguncha Play'ga yuklamang:

- [ ] mab.uz va api.mab.uz ishlayapti, sayt tez ochiladi
- [ ] **SMS (Eskiz) yoqilgan** — aks holda odamlar telefon bilan kira olmaydi
      (`deploy/README.md` → Eskiz bo'limi)
- [ ] Huquqiy hujjatlardagi `{{...}}` joylar to'ldirilgan (admin panel →
      Hujjatlar): kompaniya nomi, manzil, aloqa
- [ ] https://mab.uz/privacy va https://mab.uz/delete-account ochiladi
- [ ] Admin paroli kuchli parolga almashtirilgan
- [ ] Ilova haqiqiy Android telefonda sinab ko'rilgan (3-bosqich): kirish,
      e'lon yaratish, rasm yuklash, taklif, chat, hisobni o'chirish
- [ ] (ixtiyoriy) Google bilan kirish sozlangan (7-bosqich)

## 1-bosqich. Play Console hisobi

1. https://play.google.com/console — hisob tasdiqlangan bo'lishi kerak.
2. **Shaxsiy hisob** bo'lsa: production'dan oldin **yopiq test** majburiy —
   kamida **12 tester**, ketma-ket **14 kun**. Testerlarni (do'stlar,
   hamkasblar — Gmail manzillari) oldindan yig'ib qo'ying.
   **Tashkilot hisobi** bo'lsa, bu talab yo'q.

## 2-bosqich. Imzo kaliti (Mac'da, faqat bir marta)

```sh
keytool -genkey -v -keystore ~/mab-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cd ~/Desktop/barter-platform/app && cp android/key.properties.example android/key.properties
open -e android/key.properties
```

`key.properties` ichida to'ldiring:

```
storePassword=<keytool so'ragan parol>
keyPassword=<o'sha parol>
keyAlias=upload
storeFile=/Users/<Mac foydalanuvchi nomingiz>/mab-upload.jks
```

⚠️ `mab-upload.jks` faylini va parolni **zaxiralang** (flesh, parol
menejeri). Git'ga tushmaydi.

## 3-bosqich. Paketni qurish va telefonda sinash

```sh
cd ~/Desktop/barter-platform && git checkout develop && git pull origin develop
cd app && flutter clean && flutter pub get && flutter build appbundle --release
```

Natija: `app/build/app/outputs/bundle/release/app-release.aab`

Telefonda sinash uchun (USB bilan ulangan Android, «Developer options →
USB debugging» yoqilgan):

```sh
flutter run --release
```

## 4-bosqich. Ko'rib chiquvchi uchun test hisobi

Google xodimi ilovaga kira olishi kerak. Serverda (Mac Terminal'da):

```sh
cd ~/Desktop/barter-platform && ssh -t $(cat deploy/.server) 'sudo -u mab bash -c "cd /opt/mab/api && .venv/bin/python -m app.grant_moderator +998770009999 --create --password REVIEW-Parol-2026 && .venv/bin/python -m app.grant_moderator +998770009999 --revoke"'
```

(Birinchi buyruq hisobni ochadi va parol qo'yadi, ikkinchisi moderator
huquqini olib qo'yadi — oddiy foydalanuvchi qoladi.)

## 5-bosqich. Play Console'da ilova yaratish

1. **Create app** → App name: `MAB — barter maydoni`, Default language:
   *Uzbek*, App, Free → shartlarga belgi → Create.
2. **Grow → Store presence → Main store listing**:
   - nom, qisqa va to'liq tavsif — `docs/play/LISTING.md` dan nusxa
   - App icon — `docs/play/icon-512.png`
   - Feature graphic — `docs/play/feature-graphic-1024x500.png`
   - Phone screenshots — telefondan 4–8 ta (lenta, e'lon, chat, profil,
     e'lon yaratish)
   - Rus va ingliz tillarini **Translations → Add** orqali qo'shing
3. **Policy → App content** — har bir bandni `docs/play/LISTING.md` dagi
   jadval bo'yicha to'ldiring (Privacy policy, App access + test hisobi,
   Ads, Content rating, Target audience, Data safety, Account deletion).
4. **Store settings**: Category — *Shopping*; aloqa emaili va sayt
   `https://mab.uz`.

## 6-bosqich. Yuklash va test

1. **Test and release → Testing → Internal testing → Create new release**
   → `app-release.aab` ni yuklang → «Play App Signing» ni qabul qiling →
   Release name: `1.0.0` → Save → Review → **Start rollout**.
2. **Testers** → o'z Gmail'ingizni qo'shing → havolani telefonda ochib,
   ilovani Play orqali o'rnating va tekshiring.
3. Shaxsiy hisob bo'lsa: **Closed testing** → yangi trek → shu .aab → 12+
   tester Gmail'larini qo'shing → ular havola orqali o'rnatsin va 14 kun
   ishlatsin.

## 7-bosqich. Google bilan kirish (ixtiyoriy, lekin tavsiya qilinadi)

1. **Test and release → Setup → App signing** → «App signing key
   certificate» dagi **SHA-1** ni nusxalang.
2. https://console.cloud.google.com → APIs & Services → Credentials →
   **Create credentials → OAuth client ID → Android**: package
   `uz.mab.app`, SHA-1 — yuqoridagi. Lokal sinov uchun upload kalitining
   SHA-1 sini ham qo'shing:
   ```sh
   keytool -list -v -keystore ~/mab-upload.jks -alias upload | grep SHA1
   ```
3. Server `.env` dagi `GOOGLE_CLIENT_IDS` ga **Web** client ID yoziladi
   (`docs/GOOGLE-SIGNIN.md`). Sozlanmaguncha tugma ilovada ko'rinmaydi —
   bu xato emas.

## 8-bosqich. Production

1. **Production → Create new release** → o'sha .aab (yoki yangi
   versionCode bilan) → **Countries**: Uzbekistan (+ kerakli davlatlar) →
   Review → **Start rollout to Production**.
2. Ko'rib chiqish odatda 1–7 kun. Rad etilsa, Google sababini emailga
   yozadi — menga yuboring, tuzatamiz.

## Keyingi yangilanishlar

1. `app/pubspec.yaml` da versiyani oshiring: `1.0.1+2`
2. `flutter build appbundle --release`
3. Play Console → Production → Create new release → yangi .aab

## To'lovlar haqida

Google Play ilova ichida raqamli xizmat (e'lonni ko'tarish, e'lon paketi)
faqat Play Billing orqali sotilishini talab qiladi. Shuning uchun Android va
iOS ilovalarida to'lov bo'limi yashirilgan (#42); to'lov faqat mab.uz
saytida. Bu qoidaga mos.
