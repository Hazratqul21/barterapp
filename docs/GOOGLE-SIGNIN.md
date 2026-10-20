# Google orqali kirish

Kod tayyor. Ishlashi uchun Google Cloud'da bir marta sozlash kerak (10 daqiqa).
Sozlanmaguncha Google tugmasi ilovada ham, saytda ham **ko'rinmaydi** —
telefon orqali kirish odatdagidek ishlayveradi.

## Qanday ishlaydi

```
Ilova / sayt ──(Google hisobini tanlash)──► Google ──► ID token
Ilova / sayt ──POST /auth/google {id_token}──► API ──► token Google kaliti bilan tekshiriladi
                                                     └► MAB sessiyasi (access + refresh)
```

- Hisob Google'ning o'zgarmas ID'si (`sub`) bo'yicha topiladi. Yangi bo'lsa —
  yaratiladi, ism, familiya va surat Google'dan olinadi, keyin onboarding.
- Telefon bilan ochilgan hisobga **email bo'yicha ulanmaydi** — bu boshqa
  odamning hisobini egallab olishning oldini oladi.
- Google parol bizga kelmaydi. API Google'ga so'rov yubormaydi, faqat
  uning ochiq kalitlarini (googleapis.com) vaqti-vaqti bilan oladi.

## 1. Google Cloud Console

https://console.cloud.google.com → yangi loyiha (masalan, «MAB»).

**OAuth consent screen** (APIs & Services → OAuth consent screen):
- User type: **External**; App name: **MAB**; support email;
- App domain: `https://mab.uz`, Privacy policy: `https://mab.uz/privacy`,
  Terms: `https://mab.uz/terms`; Authorized domains: `mab.uz`;
- Scopes: `openid`, `email`, `profile` (boshqasi kerak emas);
- **Publish app** (Testing rejimida faqat test foydalanuvchilar kira oladi).

**Credentials → Create credentials → OAuth client ID** — uchta:

| Turi | Sozlama | Nima uchun |
|---|---|---|
| **Web application** | Authorized JavaScript origins: `https://mab.uz`, `https://www.mab.uz` | Sayt va **asosiy ID** — API va ilova shuni ishlatadi |
| **Android** | Package: `uz.mab.app`, SHA-1: **upload** kaliti | O'zingiz yig'gan APK |
| **Android** | Package: `uz.mab.app`, SHA-1: **Play App Signing** kaliti | Play'dan o'rnatilgan ilova |

SHA-1 qayerdan:
- upload kaliti: `keytool -list -v -keystore ~/mab-upload.jks -alias upload`
- Play App Signing: Play Console → Test and release → App integrity → App signing key certificate
- debug (ixtiyoriy, sinov uchun): `keytool -list -v -keystore ~/.android/debug.keystore -storepass android`

Android client ID'larini hech qayerga yozish shart emas — Google ularni
package nomi va SHA-1 bo'yicha o'zi taniydi.

## 2. Web client ID'ni ulash

Web client ID (`1234…-abc.apps.googleusercontent.com`) maxfiy emas.

**Server** — `/opt/mab/api/.env` ga:
```
GOOGLE_CLIENT_IDS=["1234…-abc.apps.googleusercontent.com"]
```
keyin `sudo systemctl restart mab-api`.

**Sayt va ilova** — repoga fayl:
```sh
echo '1234…-abc.apps.googleusercontent.com' > deploy/google_client_id
bash deploy/deploy.sh --web        # sayt
bash app/scripts/build_apk.sh      # APK
```
Play uchun `.aab`: `flutter build appbundle --release --dart-define=GOOGLE_CLIENT_ID=$(cat ../deploy/google_client_id)`.

## 3. Tekshirish

- https://mab.uz/signin → «Google bilan davom etish» → hisob tanlash → onboarding.
- Admin huquqi Google hisobiga: `python -m app.grant_moderator ism@gmail.com`.

## iOS

Hozircha o'chiq. Yoqish uchun: iOS turidagi client ID, `Info.plist` da
`GIDClientID` va teskari client ID URL sxemasi, so'ng `google_auth.dart` dagi
`googleSignInAvailable` ga iOS qo'shiladi.

## Muammolar

| Belgi | Sabab |
|---|---|
| Tugma yo'q | `GOOGLE_CLIENT_ID` build'ga berilmagan |
| Android: «Developer console is not set up correctly» / `[28444]` | SHA-1 yoki package nomi Android client'da noto'g'ri |
| Sayt: `origin_mismatch` | Web client'da `https://mab.uz` origin yo'q |
| API 401 «Google orqali kirib bo'lmadi» | Serverdagi `GOOGLE_CLIENT_IDS` ilovadagi ID bilan bir xil emas |
| API 404 | Serverda `GOOGLE_CLIENT_IDS` bo'sh |
