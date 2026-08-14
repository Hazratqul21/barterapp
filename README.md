# BarterApp: Premium Exchange Platform

Naqd pulsiz ayirboshlash platformasi — fermer xo'jaliklari, ustaxonalar va xususiy shaxslar uchun. Ilova Google Material 3 (v1.2) standartlari asosida yuqori sifatli (Premium) darajaga olib chiqilgan.

```
barter-platform/
├── docs/                 ← HUJJATLAR (Yangi: DESIGN_ROADMAP.md)
├── api/                  FastAPI (Backend)
└── app/                  Flutter (Frontend — iOS & Android)
```

---

## 🚀 Bugungi Texnik va Vizual Yangilanishlar (Change Log)

Bugun loyiha ustida Senior Developer darajasida tahlil o'tkazildi va ilova **"Google-Quality"** darajasiga olib chiqildi. Asosiy o'zgarishlar:

### 1. 🛠 Kritik Texnik Tuzatishlar
*   **Syntax Fix:** `TradeRepository` faylidagi build jarayonini to'xtatib qo'ygan noto'g'ri `?` operatori (null-safety xatosi) bartaraf etildi.
*   **API Automation:** Android emulyatori (`10.0.2.2`) va iOS simulyatori (`127.0.0.1`) uchun API bazaviy manzillari platformaga qarab avtomatik tanlanadigan qilindi.

### 2. 🎨 Material 3 (v1.2) Premium Dizayn
*   **Tonal Surface System:** Barcha ekranlar "Surface Container" tizimiga o'tkazildi. Bu qatlamlar o'rtasidagi ierarxiyani soyalar bilan emas, tonal ranglar bilan ajratib ko'rsatadi (Google Keep uslubi).
*   **Global FAB Styling:** Barcha "Floating Action Buttons" Google standartidagi aylana (Circle) shakliga va dinamik brand-ranglariga o'tkazildi.
*   **Modern Search Bar:** Qidiruv maydoni "Floating Pill" dizayniga keltirildi va M3 SearchBar standartlariga moslandi.
*   **Typography Hierarchy:** `Rubik` (sarlavhalar) va `Manrope` (matnlar) fontlari M3 ierarxiyasiga qat'iy bog'landi.

### 3. 🎬 Premium Motion va Animatsiyalar
*   **Container Transform:** E'lon kartasidan detallar sahifasiga o'tishda silliq "kengayish" animatsiyasi joriy etildi (OpenContainer).
*   **Staggered List Animations:** Barcha asosiy ro'yxatlar (Feed, Chat, Matches, Inbox) elementlari ochilganda birin-ketin "suzib" kiradigan qilindi.
*   **Haptic Feedback:** iOS (Taptic Engine) va Android uchun interaktiv amallarda (Like, Send, FAB) nozik sezgir vibratsiya signallari qo'shildi.

### 4. 📱 Multi-platform Optimization
*   **iOS Safe Area Management:** iPhone notch va home indicator hududlarida kontent kesilib qolmasligi uchun dinamik padding tizimi o'rnatildi.
*   **Adaptive Physics:** iOS uchun native `BouncingScrollPhysics` barcha listlarda majburiy qilindi.
*   **Privacy Descriptions:** iOS `Info.plist`da Kamera va Galereya ruxsatnomalari o'zbek tilida professional darajada yozildi.

---

## 🏗 Ishga tushirish (Run)

### 1. Backend & Baza
```bash
docker compose up -d
cd api && .venv/bin/uvicorn app.main:app --port 8010 --reload
```

### 2. Frontend (App)
```bash
cd app
flutter pub get
flutter gen-l10n
flutter run
```

---

## 📈 Kelgusi rejalar (Roadmap)
Batafsil ma'lumot loyiha ildizidagi **[docs/DESIGN_ROADMAP.md](docs/DESIGN_ROADMAP.md)** faylida keltirilgan. Unda 100% "Google darajasi"ga erishish uchun so'nggi bosqichlar (Variable Fonts, Predictive Back) belgilab olingan.

**Status:** Loyiha hozirda build-ready va bozorga chiqishga tayyor holatda. ✅
