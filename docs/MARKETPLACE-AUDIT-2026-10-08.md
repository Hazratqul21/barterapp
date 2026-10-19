# MAB: interfeys va mahsulot auditi

2026-10-08. Flutter mobil ilovalari va web, FastAPI bilan integratsiya.

Holat: asosiy discovery interfeysi qayta ishlangan, bir nechta real API xatosi tuzatilgan. Bu hujjat barcha funksiyalar production muhitda tekshirilgan yoki loyiha relizga to‘liq tayyor degani emas. Avvalgi lokal o‘zgarishlar saqlandi; production deploy qilinmadi.

## Tekshiruvda aniqlangan va tuzatilgan holatlar

| Before | After | Why |
| --- | --- | --- |
| Web 480px telefon ramkasiga majburlangan | Haqiqiy viewport; 1000px dan boshlab yon navigatsiya, feed 1/2/3 ustun | Katta ekranda katalogdan foydalanish va bir nechta e’lonni solishtirish |
| Pastki bar: SafeArea + qo‘shimcha 16px tashqi masofa, kontent uning orqasida | Ekran chetiga tutashgan, SafeArea bir marta hisoblangan bar; klaviatura ochilganda yashirinadi | iOS home indicator va Android tizim navigatsiyasi bilan masofa to‘g‘ri bo‘lishi |
| Bosish hududi tor, matni uzun markaziy action | Standart InkWell, semantika va qisqa lokalizatsiyalangan “E’lon” yorlig‘i | Touch va klaviatura boshqaruvi, kesilgan yorliqlarni kamaytirish |
| Baland rasmli hero ichidagi qidiruv | Yuqorida doim ko‘rinadigan qidiruv, alohida filtr tugmasi va faol filtr belgisi | Qidiruvga tez qaytish, ekran maydonini e’lonlarga berish |
| Multfilmga o‘xshash kategoriya tasvirlari va soyalar | Bir xil uslubdagi material belgilar, o‘qiladigan nomlar va aniq tanlangan holat | Vizual tartib va izchillik |
| Banner ichida rasm ustidagi zich matn | Past kontrastli, ixcham, yopiladigan action | E’lonlardan e’tiborni olib qo‘ymaslik |
| Kartalarda rasm ustiga joylashgan narx va belgilar | Bir xil nisbatdagi rasm, pastida narx, nom, ayirboshlash talabi, sotuvchi va sana | Narx va tavsifni har qanday rasm fonida o‘qish |
| Sarlavhalarda og‘ir, turli fontlar | Asosiy tipografiyada Manrope, yengilroq tonal ranglar | Bir xil vizual ierarxiya |
| `category`, `min_price`, `max_price`, `sort=date_desc` yuborilgan | `tag`, `min_value`, `max_value`, `new/cheap/expensive`; so‘m → tiyin | Backend kontrakti: eski default saralash 422 qaytargan, kategoriya/narx parametrlari ishlamagan |
| Hudud erkin yozilgan | Backendning `/regions` ro‘yxatidan tanlanadi; xatoda qayta urinish | Hudud nomining imlo farqi tufayli bo‘sh natija chiqmasligi |
| Narxda manfiy/yaroqsiz qiymat qabul qilingan | Son, chegaralar va min ≤ max tekshiriladi; uch tilda tushuntirish | Noto‘g‘ri filtr so‘rovlarini oldini olish |
| Qidiruv tozalanganda kechikkan debounce uni qaytargan | Tozalash/Enter oldingi taymerni bekor qiladi | Ko‘rinayotgan matn va natijalar mos qolishi |
| Pagination xatosida loading qotgan, eski javob yangi qidiruvni bosgan | Xatoda mavjud natijalar saqlanadi, Retry; generation tekshiruvi va ID bo‘yicha deduplikatsiya | Tarmoqdagi uzilish va tez qidirishdagi ishonchlilik |
| `/favorites` javobi oddiy List deb o‘qilgan | `items` ichidan o‘qiladi, 50 tagacha so‘raladi | Backend Page obyekt qaytaradi; eski parser xato bergan |
| Saqlangan holat har safar false; API xatosi yashirilgan | `is_favorite` modelda saqlanadi, saqlash so‘rovi kutiladi, xatoda avvalgi holat tiklanadi | Foydalanuvchiga yolg‘on muvaffaqiyat ko‘rsatmaslik |
| Saqlanganlar har qanday telefonda 2 ustun | Kenglik va matn masshtabiga mos grid, mehmon uchun kirish taklifi | Kichik ekranlarda kartalar sig‘ishi |
| Shikoyatda `target_type` yo‘q, reason tarjima matni bo‘lgan | Backend enum va alohida note; tasdiqlash, muvaffaqiyat/xato xabari | Shikoyatning 422 bilan rad etilishini tuzatish |
| Bildirishnomani o‘qish PATCH bo‘lgan | Backenddagi POST ishlatiladi | 405 xatosini tuzatish |
| Chat swipe orqali mavjud bo‘lmagan archive endpoint chaqirilgan, xato yashirilgan | Ishlamaydigan swipe olib tashlangan, chat joyida qoladi | Soxta arxivlash va Dismissible qayta chizish muammosini yo‘qotish |
| Analitikada barcha qurilmalar `ios` bo‘lgan | Web yoki haqiqiy target platform yoziladi; impression hodisalari saqlandi | Platformalar bo‘yicha o‘lchovlarni buzmaslik |

## Dalillar va qamrov

- `flutter analyze --no-pub`: xato va lint yo‘q.
- `flutter test --no-pub`: **38/38**. 17 ta yangi regression holati, jumladan API kontraktlari, offline pagination/retry, eskirgan javob, debounce va 12 ta ekran/matn masshtabi kombinatsiyasi.
- Ekranlar: 320×568, 390×844, 430×932, 844×390, 1024×768, 1440×900; matn 1.0 va 1.6; yuqori 47px va pastki 34px insets bilan widget testlar. Bu haqiqiy Android qurilmasi sinovining o‘rnini bosmaydi.
- Forma sinovi: manfiy narx, teskari oraliq, to‘g‘ri oraliqni qo‘llash.
- `api/tests/test_feed_search.py`: **24 PASS**, ishlayotgan lokal PostgreSQL va FastAPI orqali. Saralash, narx, region, kategoriya, qidiruv tillari va cursorlar. Mavjud bazani qayta seed qilmasdan bajarildi.
- Web 1440px va 390px kengliklarda haqiqiy lokal backend bilan vizual ko‘rildi. Screenshotlar `artifacts/marketplace-audit/` ichida.
- iPhone 17e / iOS 26.5 simulyatorida native build o‘rnatilib, ekran rasmi tekshirildi.
- Android arm64 debug APK build tekshirildi; emulator/haqiqiy Android qurilmasi ulanmagan. Android klaviaturasi, gesture navigation va back harakati amalda tekshirilishi kerak.
- Oxirgi kod bilan `flutter build ios --simulator --debug`, `flutter build apk --debug --target-platform android-arm64` va `flutter build web --debug` muvaffaqiyatli. Bular development buildlar, store release emas.
- Build va test loglari shu artifact papkasida. Dastlab disk to‘lib native build to‘xtadi; shu urinish yaratgan `app/build/app` fayllari tozalanib, qayta yig‘ildi.

## Qolgan muhim ishlar

| Ustuvorlik | Muammo / dalil | Tugallash mezoni |
| --- | --- | --- |
| P0 — reliz | Production API, SMS, Firebase/APNs, signing va legal URLlar hali muhitda tasdiqlanmagan. `docs/MAB-RELEASE-READINESS.md` | Haqiqiy iOS/Android qurilmada OTP → e’lon → taklif → chat → kelishuv → report/block/account deletion ssenariylari to‘liq o‘tishi |
| P0 — konfiguratsiya | `api/app/core/config.py`: `OTP_DEBUG=true` bo‘lsa zaif/default JWT secret ogohlantirish bilan o‘tadi; SMS majburiyligi default false | Production konfiguratsiyasida debug o‘chiq, kuchli secret va ishlaydigan SMS shart; alohida production startup tekshiruvi |
| P1 — katalog | Faqat 6 ta category; mahsulotga xos parametrlar yo‘q | Auditoriyaga qarab subkategoriyalar, telefon modeli/xotirasi, transport yili va holati; schema va search indeksi |
| P1 — lokatsiya | Region hozir e’lon emas, uning egasi orqali filtrlanadi; tuman/radius tanlovi yo‘q | Har e’lonning mustaqil hududi, shahar/tuman va ixtiyoriy radius; ruxsat rad etilganda qo‘lda tanlash |
| P1 — qidiruvni saqlash | Saved search, ogohlantirishlar va URLga serializatsiyalangan filtrlar yo‘q | Filtrli havola refresh/share qilinganda saqlanishi, yangi mos e’lon xabarlari |
| P1 — e’lon yaratish | `create_listing_page.dart` formasi xotirada; draft saqlash yo‘q | Ilova yopilib ochilganda draft tiklanishi, yuklash retry/progress, fotosuratlar tartibini almashtirish |
| P1 — saqlanganlar | Backend `/favorites` eng ko‘pi 50 ta, `next_cursor=null` | Haqiqiy cursor pagination va ko‘p saqlangan e’lonlar testi |
| P1 — e’lon sahifasi | Native share va chuqur havola konfiguratsiyasi tugallanmagan | Telegram/browser havolasi iOS/Androidda kerakli e’lonni ochishi; o‘chirilgan e’londa tushunarli fallback |
| P1 — ommaviy web | `web/index.html` umumiy metadata; har e’longa alohida HTML/OG/canonical yo‘q | Indekslanadigan e’lon sahifalari, sitemap, strukturali metadata va link preview; alohida server-rendered web frontendni baholash |
| P1 — kontent | Lokal seedda stock fotosuratlar e’lon modeliga mos kelmasligi mumkin, masalan MacBook nomi va foto avlodi | Haqiqiy sotuvchi fotosuratlari, EXIF/rotatsiya/siqish tekshiruvi; AI rasmni haqiqiy mahsulot fotosi o‘rniga ishlatmaslik |
| P1 — ishonch | Report/block tuzatildi, ammo moderator jarayoni, dalillar va javob muddatlari E2E tasdiqlanmagan | Moderator navbati va audit izi; takroriy shikoyat/dublikat e’lon nazorati |
| P2 — chat | Arxivlashning backend mexanizmi yo‘q | Har ishtirokchi uchun alohida arxivlash, qayta tiklash, yangi xabarda qayta ochilish qoidasi |
| P2 — foydalanish | Saqlash feed kartasida yo‘q; faqat detaildan; foydalanuvchi fotosini kattalashtirish tajribasi qayta tekshirilishi kerak | Inline favorite, accessible gallery, list/grid tanlovi, uzoq nomlar va RU/EN katta matnda vizual QA |
| P2 — kuzatuv | Build/test mavjud, production crash/performance ko‘rsatkichlari tasdiqlanmagan | Crash monitoring, API xato darajasi, real qurilmada scroll/frame profiling, test ma’lumotlarini productiondan ajratish |

Testlar login va haqiqiy SMS, to‘lov, push, kamera permissionlari hamda real foydalanuvchilar o‘rtasidagi savdoni bu auditda jonli tasdiqlamaydi. API bo‘yicha unit testlar haqiqiy production mutatsiyasining isboti emas.

## OLX bilan taqqoslash

[OLX e’lonlar sahifasi](https://www.olx.uz/list/) qidiruv, joy, kategoriya, narx, saralash va qidiruv parametrlarini saqlashni bir oqimda beradi. MAB uchun ustuvorlik shu discovery asoslarini ishonchli qilish, keyin barterga xos “menda bor ↔ menga kerak” mosliklarini kuchaytirish. Bu OLX bilan funksional tenglikka erishildi degani emas.

MAB uchun mahsulot tashabbuslari: saqlangan barter istagi va yangi moslik xabarlari; nima sabab mos kelgani tushuntiriladigan matching; umumiy qiymat/pul qo‘shimchasi aniq ko‘rsatiladigan taklif; ikki tomon tasdiqlaydigan kelishuv tarixi; savdo tugagach tekshirilgan baholar.

## Flutter yoki alohida native?

Hozir mobil ilovalarni Flutter’da davom ettirish tavsiya qilinadi. Topilgan asosiy xatolar frameworkdan emas, layout va API kontraktidan kelib chiqqan. Native rewrite ikkita UI va test tizimini yuritishni talab qiladi. Zarur OS funksiyalarini [platform channels](https://docs.flutter.dev/platform-integration/platform-channels) orqali alohida Swift/Kotlin modulda ishlatish mumkin.

Web uchun boshqa qaror kerak bo‘lishi mumkin: ommaviy e’lonlar Google orqali topilishi biznesning muhim qismi bo‘lsa, HTML va serverda render qilishga asoslangan katalog frontendini alohida loyihalash kerak. Flutter o‘zining [web FAQ](https://docs.flutter.dev/platform-integration/web/faq) sahifasida kontentga yo‘naltirilgan web va SEO cheklovlarini tushuntiradi. Bu auditda yangi frameworkga migratsiya qilinmadi.
