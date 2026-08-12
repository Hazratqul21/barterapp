# BarterApp backend tahlili

Tekshiruv sanasi: 2026-08-12  
Qamrov: `api/` FastAPI servisi, autentifikatsiya, savdo oqimi, fayl yuklash,
chat va production sozlamalari.

## Qisqa xulosa

Backendning asosiy funksional oqimlari ishlaydi: Python sintaksisi tekshirildi,
PostgreSQL konteyneri sog‘lom holatda va mavjud integratsion testlar to‘liq
o‘tdi. Testlar barter savdosi, e’lon yaratish, counter-offer, review, upload va
profil oqimlarini qamraydi.

Shunga qaramay, servis productionga chiqarilishidan avval autentifikatsiya,
tokenlarni bekor qilish va bir vaqtning o‘zida bajariladigan savdo amallariga
oid muammolar tuzatilishi kerak. Eng katta xavflar OTP orqali hisobni egallash,
SMS xarajatining nazoratsiz o‘sishi va bitta e’lonning parallel deal’larga
tushishidir.

## Tekshiruv natijalari

| Tekshiruv | Natija |
| --- | --- |
| Python sintaksisi (`compileall`) | O‘tdi |
| PostgreSQL container healthcheck | Sog‘lom |
| API `/health` | `{"status":"ok"}` |
| Integratsion testlar | 6 ta fayl, 60 ta tekshiruv — hammasi o‘tdi |
| Git conflict markerlari | Topilmadi |

O‘tgan testlar hali security, rate-limit, parallel request va production CORS
holatlarini to‘liq qamramaydi.

## Muhim topilmalar

### 1. OTP so‘rovlarida rate-limit yo‘q

**Xavf darajasi:** yuqori  
**Joy:** `api/app/api/auth.py`, `POST /auth/otp/request`

Har qanday mijoz OTP endpointiga takroran murojaat qilib, istalgan telefon
raqamiga cheksiz OTP so‘rashi mumkin. Hozir `OTP_DEBUG=true` bo‘lgani uchun bu
test muhitida SMS yubormaydi. Lekin SMS provayder ulanganida bu holat:

- SMS-spamga;
- provayder xarajatlarining oshishiga;
- legitim foydalanuvchilar uchun xizmatning yomonlashishiga;
- telefon raqam bo‘yicha brute-force yordamchi hujumlariga

olib keladi.

**Tavsiya:**

- IP bo‘yicha va telefon raqami bo‘yicha alohida rate-limit qo‘shish;
- masalan, bir raqamga 10–15 daqiqada 3–5 ta so‘rovdan ortiq ruxsat bermaslik;
- limitni Redis kabi umumiy storage’da saqlash;
- limit buzilganda `429 Too Many Requests` va foydalanuvchiga aniq retry vaqti
  qaytarish;
- CAPTCHA yoki device-attestation’ni faqat shubhali trafikda qo‘llash.

### 2. OTP kodi bazada ochiq matn ko‘rinishida saqlanadi

**Xavf darajasi:** yuqori  
**Joy:** `api/app/models/user.py`, `OtpChallenge.code`

OTP qiymati DB’da olti xonali kod sifatida saqlanmoqda va tekshiruvda bevosita
solishtiriladi. Database backup, log, administrator accounti yoki noto‘g‘ri
ruxsat orqali ma’lumot chiqib qolsa, hali muddati tugamagan kodlar ishlatilishi
mumkin.

**Tavsiya:**

- `code` o‘rniga HMAC yoki password hash saqlash;
- verify paytida kelgan koddan xuddi shu hashni hisoblab solishtirish;
- OTP muddati juda qisqa qolishi (hozir 300 soniya) va successful verify’dan
  keyin challenge darhol consume qilinishi;
- eski/consume qilingan OTP yozuvlarini periodik tozalash.

### 3. Refresh tokenlarni logout yoki qurilmadan bekor qilish imkoni yo‘q

**Xavf darajasi:** yuqori  
**Joy:** `api/app/api/auth.py`, `POST /auth/refresh`; `api/app/core/security.py`

Refresh token JWT sifatida yaratiladi va 60 kun ishlaydi. Server refresh token
holatini saqlamaydi. Shuning uchun token nusxasi o‘g‘irlangan bo‘lsa, parol
almashtirish, logout yoki qurilmani chiqarish ham uning ishlashini to‘xtatmaydi.

**Tavsiya:**

- refresh token uchun DB jadvali yaratish: `jti`, user ID, device, expiry,
  revoked-at va token hash;
- refresh vaqtida token rotation qilish: eski tokenni revoke qilib, yangisini
  berish;
- `POST /auth/logout` va `POST /auth/logout-all` endpointlarini qo‘shish;
- access token muddatini 24 soatdan qisqaroq qilish (masalan 15–60 daqiqa);
- shubhali refresh reuse aniqlansa shu foydalanuvchining barcha sessiyalarini
  bekor qilish.

### 4. Taklifga nofaol yoki tugallangan listing qo‘shish mumkin

**Xavf darajasi:** o‘rta  
**Joy:** `api/app/api/offers.py`, `create_offer`

`wanted` listing uchun `active` status tekshiriladi. Biroq barterga berilayotgan
`offered_listing_ids` faqat aynan shu userga tegishli ekani bilan tekshiriladi.
Ularning `active` ekani tekshirilmaydi. Natijada closed yoki completed listing
taklif tarkibiga kiritilishi mumkin.

**Tavsiya:**

- offered listing query’iga `Listing.status == ListingStatus.active` shartini
  qo‘shish;
- so‘ralgan ID soni va topilgan faol listing soni teng bo‘lmasa `400` qaytarish;
- bunday holat uchun integration test qo‘shish.

### 5. Bir listing parallel savdolarda ikki marta yakunlanishi mumkin

**Xavf darajasi:** o‘rta / yuqori  
**Joy:** `api/app/api/offers.py`, `act_on_offer`

Offer statusi o‘qilib, keyin Python’da transition tekshiriladi va oxirida
commit qilinadi. Ikki request deyarli bir vaqtda kelganda, ikkalasi ham eski
`pending` holatini ko‘rib, ikkala savdoni ham qabul/yakunlash ehtimoli bor.
Listing `completed` bo‘lib qoladi, biroq undan oldin ikkita deal tasdiqlangan
bo‘lishi mumkin.

**Tavsiya:**

- transaction ichida offer va tegishli listinglarni `SELECT ... FOR UPDATE`
  bilan lock qilish;
- statusni atomik `UPDATE ... WHERE status IN (...)` orqali yangilash va
  affected row count’ni tekshirish;
- listingga bog‘langan boshqa pending/accepted offer’larni deal yakunlanganda
  atomik ravishda cancel/expire qilish;
- parallel request testini qo‘shish.

### 6. Production CORS sozlamasi ishlatilmayapti

**Xavf darajasi:** o‘rta  
**Joy:** `api/app/core/config.py`, `cors_origins`; `api/app/main.py`

`Settings` ichida `cors_origins` mavjud, ammo middleware uni ishlatmaydi.
Middleware faqat `localhost` va `127.0.0.1` originlarini regex orqali qabul
qiladi. Production Flutter Web yoki admin panel boshqa domen orqali API’ga
murojaat qilsa, browser CORS so‘rovini bloklaydi.

**Tavsiya:**

- `allow_origins=list(settings.cors_origins)` dan foydalanish;
- development va production originlarini environment orqali ajratish;
- wildcard (`*`) bilan `allow_credentials=True` kombinatsiyasini ishlatmaslik;
- production domenlari uchun HTTPS’ni majburiy qilish.

### 7. WebSocket access token URL query parametrida yuboriladi

**Xavf darajasi:** o‘rta  
**Joy:** `api/app/api/chat.py`, `GET /ws?token=...`

Browser WebSocket handshake’da odatiy Authorization header qo‘yish cheklangan,
shu sabab token query parametriga qo‘yilgan. Query string reverse-proxy,
web-server yoki monitoring loglariga yozilishi mumkin. Bu access tokenning
beixtiyor tarqalish xavfini oshiradi.

**Tavsiya:**

- qisqa umrli, faqat socket uchun token yaratish;
- yoki `Secure`, `HttpOnly`, `SameSite` cookie asosidagi sessiya ishlatish;
- proxy loglarida token parametrini redaction qilish;
- productionda faqat `wss://` orqali WebSocket ulanishini qabul qilish.

### 8. Yuklangan rasmlar uchun disk cleanup siyosati yo‘q

**Xavf darajasi:** past / o‘rta  
**Joy:** `api/app/api/uploads.py`

Fayl yuklangach UUID nomi bilan lokal diskka yoziladi. Listing o‘chirilsa,
foydalanuvchi rasmni almashtirsa yoki upload ishlatilmasa, faylni o‘chiradigan
oqim mavjud emas. Uzoq muddatda storage cheksiz o‘sadi.

**Tavsiya:**

- upload yaratilgan vaqt va unga bog‘langan entity’ni saqlash;
- orphan fayllarni scheduled job bilan o‘chirish;
- listing o‘chirish/yangilash transactionida bog‘liq media cleanup qilish;
- productionda object storage (S3-compatible) va lifecycle policy’dan
  foydalanish.

## Production konfiguratsiyasi bo‘yicha eslatmalar

`OTP_DEBUG=false` va kuchli `JWT_SECRET` production uchun majburiy. Mavjud
guard standart yoki 32 belgidan qisqa secret bilan `OTP_DEBUG=false` holatida
serverni to‘xtatadi — bu yaxshi himoya. Ammo deployment konfiguratsiyasi aniq
tekshirilsin:

- `JWT_SECRET` kamida 32 belgili tasodifiy qiymat bo‘lsin;
- `.env` Git’ga qo‘shilmasin;
- `OTP_DEBUG=false` bo‘lsin va haqiqiy SMS provayder sozlangan bo‘lsin;
- database va media backup siyosati bo‘lsin;
- API reverse proxy ortida HTTPS bilan ishga tushsin;
- bir nechta API instance kerak bo‘lsa chat Hub’ini Redis pub/sub bilan
  almashtirish zarur. Hozirgi Hub faqat bitta process ichida xabar tarqatadi.

## Tavsiya etilgan ish tartibi

1. OTP rate-limit va OTP hash saqlashni joriy qilish.
2. Refresh token rotation, revocation va logout endpointlarini joriy qilish.
3. Offer/listing status tekshiruvlari hamda parallel transaction lock’larini
   qo‘shish.
4. CORS va WebSocket token oqimini production domenlar uchun sozlash.
5. Upload cleanup va object storage lifecycle siyosatini qo‘shish.
6. Yuqoridagi har bir holat uchun integration/security test yozish.

## Hozirgi qaror

Demo va ichki test muhiti uchun backend funksional. Public production release
uchun esa kamida 1–6-bandlar bo‘yicha tuzatishlar bajarilib, qayta security va
parallel-load testi o‘tkazilishi kerak.
