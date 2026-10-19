# Ulashish havolalari va app-link'lar

Domen: **mab.uz**. E'lon ulashilganda havola: `https://mab.uz/l/<id>`.

- **Web:** `/l/:id` → `/listing/:id` (go_router). O'chirilgan/yakunlangan e'lon — "E'lon endi mavjud emas" sahifasi.
- **Ilova o'rnatilgan bo'lsa** havola to'g'ridan-to'g'ri ilovada ochiladi — buning uchun quyidagilar kerak.

## 1. Build

Release build'lar sukut bo'yicha `https://api.mab.uz` (API) va `https://mab.uz` (ulashish) ga ulanadi. Staging uchun:

```sh
flutter build appbundle --dart-define=API_BASE_URL=https://api.staging.mab.uz --dart-define=PUBLIC_WEB_BASE_URL=https://staging.mab.uz
```

`PUBLIC_WEB_BASE_URL=` (bo'sh) berilsa, ulashishda havolasiz matn yuboriladi.

## 2. Domen'da fayllar (`app/deeplinks/` — shablonlar)

| Fayl | Manzil | To'ldirish |
|---|---|---|
| `assetlinks.json` | `https://mab.uz/.well-known/assetlinks.json` | `__RELEASE_SHA256_FINGERPRINT__` — **Play Console → Test and release → App integrity → App signing key certificate → SHA-256** (Play App Signing'da Google'ning kaliti; upload kalitning emas) |
| `apple-app-site-association` | `https://mab.uz/.well-known/apple-app-site-association` (kengaytmasiz, `application/json`) | `__APPLE_TEAM_ID__` — Apple Developer Team ID |

## 3. Ilova sozlamalari

**Android** — `AndroidManifest.xml` da `mab.uz/l/` uchun `autoVerify` intent-filter bor. `assetlinks.json` joylanmaguncha havola brauzerda ochiladi, ilova ishlashiga ta'sir qilmaydi.

**iOS** — hali qilinmagan: Apple Developer'da App ID `uz.mab.app` ga Associated Domains yoqilgach, Xcode → Runner → Signing & Capabilities → Associated Domains: `applinks:mab.uz`. Capability'siz entitlement qo'shilsa imzolash buziladi.
