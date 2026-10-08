# MAB — barter platformasi

Naqd pulsiz ayirboshlash: Flutter (iOS, Android, web), FastAPI va PostgreSQL.

```
app/          Flutter interfeysi
api/          FastAPI backend
ai_backend/   Ixtiyoriy AI yordamchi xizmati
docs/         Auditlar, reliz talablari va hujjatlar
```

## Joriy holat

Interfeys va API integratsiyasida tuzatishlar bor. Production reliz hali alohida tekshiruvlarni talab qiladi; lokal build muvaffaqiyati barcha xizmatlar tayyorligini bildirmaydi.

- [2026-10-08 audit: tuzatilgan xatolar, testlar va ustuvor ishlar](docs/MARKETPLACE-AUDIT-2026-10-08.md)
- [Reliz konfiguratsiyasi va tashqi xizmatlar](docs/MAB-RELEASE-READINESS.md)
- [Ekran rasmlari va tekshiruv loglari](artifacts/marketplace-audit/)

## Lokal ishga tushirish

```sh
docker compose up -d db
cd api
# .env.example asosida lokal .env tayyorlang; kuchli JWT_SECRET kiriting.
.venv/bin/uvicorn app.main:app --port 8010 --reload
```

Boshqa terminalda:

```sh
cd app
flutter pub get
flutter gen-l10n
flutter run
# Web:
flutter run -d web-server --web-port=8086 --web-hostname=127.0.0.1
```

### Production rejimi

Serverda `APP_ENV=production` qo‘ying. Bu rejimda API quyidagilardan biri bo‘lsa **ishga tushmaydi** va barcha muammolarni bitta xabarda chiqaradi:

- `OTP_DEBUG=true` (kod javobda qaytadi);
- `JWT_SECRET` standart yoki 32 belgidan qisqa;
- `ESKIZ_EMAIL`/`ESKIZ_PASSWORD` bo‘sh yoki `SMS_REQUIRED=false`;
- `CORS_ORIGINS` bo‘sh, `*` bor, `https` emas yoki `localhost`/`127.0.0.1`.

Productionda localhost uchun CORS regex ham o‘chadi. Tekshiruv: `api/tests/test_config_guard.py`.

Android emulator default API manzili `10.0.2.2:8010`, iOS simulator/web `127.0.0.1:8010`. Real telefon yoki release build uchun tegishli `API_BASE_URL` qiymatini `--dart-define` orqali bering.

## Tekshiruvlar

```sh
cd app
flutter analyze
flutter test
flutter build ios --simulator --debug
flutter build apk --debug --target-platform android-arm64
flutter build web --debug
```

Ishlayotgan lokal backendda qidiruv/filtr testi:

```sh
cd api
.venv/bin/python tests/test_feed_search.py
```

`api/tests/run_all.sh` har ssenariy oldidan bazani seed qiladi. Mavjud ma’lumotli bazada ishlatmang; buning uchun alohida test bazasi kerak.
