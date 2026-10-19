# MAB — relizga tayyorgarlik

2026-10-05. Holat: lokal iOS simulator va web build muvaffaqiyatli; App Store submission hali tayyor emas.

Tekshiruv: `flutter analyze` xatosiz, `flutter test` 21/21. iPhone 17e (iOS 26.5) simulyatorida o‘rnatildi va intro ekrani vizual tekshirildi. Screenshot: `artifacts/mab-preview/iphone.png`. Backend bu sessiyada ishlamayotgani uchun login/SMS, real ma’lumotli sahifalar va savdo oqimi jonli tekshirilmagan.

## Kiritilgan o‘zgarishlar

- MAB nomi uz/ru/en, iOS, Android, web metadata’da.
- Foydalanuvchi bergan asl logo `app/assets/brand/mab-logo.png` sifatida saqlandi.
- iOS (jumladan 1024px RGB), Android, PWA, favicon va native launch image paketlandi.
- Tablar va responsive o‘lcham o‘zgarishida ekran holati saqlanadi.
- Native iPad/landscape telefon ramkasiga majburlanmaydi.
- Primary tugma kontrasti, kichik ekran OTP, reduced-motion va keyboard bilan karta bosish yaxshilandi.
- API xatosida soxta e’lon/kategoriya ko‘rsatish olib tashlandi.
- Kirish ekraniga privacy/terms havolalari qo‘shildi; muvaffaqiyatsiz ochilish haqida xabar chiqadi.

## Nashrdan oldin kerak bo‘ladigan ma’lumotlar

Foydalanuvchi bu ma’lumotlarni keyin berishini aytdi. Ularning o‘rniga taxminiy domen yoki Team ID qo‘yilmadi.

1. Production HTTPS API: `API_BASE_URL`.
2. Ochiq va ishlaydigan `PRIVACY_POLICY_URL`, `TERMS_URL`; hozir eski development havolalari fallback.
3. `docs/legal/` ichidagi `{{...}}` kompaniya, manzil, aloqa va sanani to‘ldirish va tasdiqlash.
4. Apple Developer Team, signing certificate/provisioning va App Store Connect record.
5. Firebase konfiguratsiyasi, APNs push entitlement/key va real qurilmada push sinovi. Hozir Firebase sozlanmasa push xavfsiz o‘chadi.
6. Ishlaydigan SMS provider, review uchun hisob va moderatorning haqiqiy aloqa ma’lumotlari.
7. App Store privacy answers, age rating, support URL va haqiqiy ekranlardan screenshotlar.
8. Production muhitda e’lon yaratish, offer/chat, report/block, hisob o‘chirishni end-to-end sinash.

Bundle ID `uz.barterapp.barterApp` saqlandi: display nom o‘zgarishi ilovaning signing/push identifikatorini avtomatik o‘zgartirmasligi kerak.

## Build

```sh
cd app
flutter analyze
flutter test
flutter build ios --simulator --debug
# Haqiqiy, foydalanuvchi tasdiqlagan qiymatlar bilan:
flutter build ipa --release --dart-define-from-file=../release.production.json
```

`release.production.json` ichida API_BASE_URL, PRIVACY_POLICY_URL va TERMS_URL bo‘ladi. Hozir bu fayl yaratilmagan.

## Apple manbalari

- https://developer.apple.com/news/upcoming-requirements/?id=04282026a — iOS 26 SDK minimum talabi; lokal Xcode 26.6.
- https://developer.apple.com/app-store/review/guidelines/ — completeness, user content va privacy talablari.
- https://developer.apple.com/support/offering-account-deletion-in-your-app — ilova ichida hisob o‘chirish talabi.

Simulator build yoki unit testlar App Store qabulini, real push/SMS ishlashini va production backend tayyorligini isbotlamaydi.
