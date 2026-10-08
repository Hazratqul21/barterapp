# Ulashish havolalari va app-link'lar

E'lon ulashilganda havola: `PUBLIC_WEB_BASE_URL/l/<id>` (masalan `https://barter.example.uz/l/3f2…`).

- **Web:** `/l/:id` → `/listing/:id` (go_router). O'chirilgan/yakunlangan e'lon — "E'lon endi mavjud emas" sahifasi.
- **Ilova o'rnatilgan bo'lsa** havola to'g'ridan-to'g'ri ilovada ochiladi — buning uchun quyidagilar kerak.

## 1. Build

```sh
flutter build web --dart-define=PUBLIC_WEB_BASE_URL=https://<domen> --dart-define=API_BASE_URL=https://<api>
flutter build apk --dart-define=PUBLIC_WEB_BASE_URL=https://<domen> ...
```

Berilmasa ulashishda havolasiz matn yuboriladi (localhost havola emas).

## 2. Domen'da fayllar (`app/deeplinks/` — shablonlar)

| Fayl | Manzil | To'ldirish |
|---|---|---|
| `assetlinks.json` | `https://<domen>/.well-known/assetlinks.json` | `__RELEASE_SHA256_FINGERPRINT__` — release kalit (`keytool -list -v -keystore …` yoki Play Console → App signing) |
| `apple-app-site-association` | `https://<domen>/.well-known/apple-app-site-association` (kengaytmasiz, `application/json`) | `__APPLE_TEAM_ID__` — Apple Developer Team ID |

## 3. Ilova sozlamalari (domen ma'lum bo'lgach)

**Android** — `android/app/src/main/AndroidManifest.xml`, `MainActivity` ichiga:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="<domen>" android:pathPrefix="/l/"/>
</intent-filter>
```

**iOS** — Xcode → Runner → Signing & Capabilities → Associated Domains: `applinks:<domen>`.

Domen hali tanlanmagani uchun manifest/entitlements o'zgartirilmadi: soxta domen bilan `autoVerify` relizni buzadi.
