# Dizayn tizimi — BarterApp

Nima uchun shunday ko'rinadi. Kod: `app/lib/core/theme/tokens.dart` va
`app_theme.dart`, komponentlar `app/lib/core/widgets/`.

---

## 1. Kim uchun chizilgan

Uchta segment bor (DOMAIN.md §2), lekin dizayn qarorlari **C segmentga**
qaratilgan: uyda ortiqcha noutbugi bor va uni remontga almashtirmoqchi bo'lgan
oddiy odam.

Sabab: B2B foydalanuvchi matnni o'qiydi, chunki uning ishi shu. C segment
o'qimaydi — **rasm ko'radi**. Agar ekran unga tushunarli bo'lsa, fermerga ham
tushunarli bo'ladi; teskarisi to'g'ri emas.

Birinchi versiya bank ilovasiga o'xshardi: sovuq kulrang fon, kulrang matn
chiplari, hamma joyda bir xil radius. U C segmentni yo'qotardi.

---

## 2. Rang — ma'no, bezak emas

Mahsulotning butun g'oyasi ikkilikda: **beraman ⇄ olaman**. Palitra shuni
takrorlaydi.

| Ma'no | Yorug' | Qorong'i | Qayerda |
|---|---|---|---|
| **Beraman** (give) | `#0E7A52` | `#4FCB92` | Egasi beradigan narsa, asosiy tugma, tasdiq |
| **Olaman** (take) | `#1D4FBF` | `#8FB0F5` | «Kerak:» bloklari, xohishlar |
| **Pul** (money) | `#B47714` | `#E0B45A` | Narx, premium, o'qilmagan |

`vivid` darajalari faqat bitta ish uchun: **gradient**. Lenta sarlavhasi va
splash yashildan ko'kka oqadi — ya'ni sarlavhaning o'zi savdo rasmi. Boshqa
hech qayerda to'liq kuchda ishlatilmaydi.

```dart
palette(context).swapGradient   // give → take
```

### Yuzalar issiq

```
canvas   #FAF8F4    sahifa
surface  #FFFFFF    kartalar
sunken   #F2EEE7    qidiruv maydoni, inert plitkalar
hair     #E7E2D9    ajratuvchi chiziq
```

Sovuq ko'k-kulrang emas. Bu fermerlar va ustaxonalar bozori — u qog'ozga
tushgan kunduzgi yorug'likka o'xshashi kerak, bank paneliga emas.

### Kategoriya ranglari

Olti bo'lim, har biri o'z rangi va belgisi bilan (`CategoryStyle`):

| Bo'lim | Rang | Belgi |
|---|---|---|
| Qishloq xo'jaligi | yashil | `agriculture` |
| Chorva | qahrabo | `pet_supplies` |
| Texnika | to'q sariq | `precision_manufacturing` |
| Transport | ko'k | `local_shipping` |
| Elektronika | binafsha | `devices` |
| Qurilish | qizil | `construction` |

Bular uchala tilda bir xil ishlaydi va uchta tarjimani tejaydi.

---

## 3. Shrift

| Rol | Shrift | Vazn |
|---|---|---|
| Sarlavha, narx, bo'lim nomi | **Rubik** | 700 / 800 |
| Matn, interfeys, tugma | **Manrope** | 400 / 500 / 600 |

**Ikkalasi ham ilovaga o'rnatilgan** (`app/assets/fonts/`), internetdan
yuklanmaydi. Bozorning yarmi qishloq mobil internetida ochadi.

### Nega almashtirildi

Ilova Plus Jakarta Sans'da qurilgan edi. Uning Google Fonts to'plamlari:
`latin`, `latin-ext`, `vietnamese`, `cyrillic-ext`. Oxirgisi **kam
ishlatiladigan tarixiy harflarni** saqlaydi, А–Я ni emas. Ya'ni har bir ruscha
ekran tizim shriftiga tushib ketardi.

Rubik va Manrope — o'zgaruvchan shriftlar, bitta fayl 300–900 vaznni qoplaydi,
ikkalasi ham to'liq kirill blokini saqlaydi (`fontTools` bilan tekshirilgan).

⚠️ Tarjimalarda `‘` (U+2018) ishlatiladi, `ʻ` (U+02BB) emas. Ikkala shrift ham
birinchisini qoplaydi, ikkinchisini yo'q. Bir xil bo'lib qolsin.

### Shkala

```
displayLarge   48/800     headlineLarge  28/700     titleLarge   18/700  ← bo'lim sarlavhasi
displayMedium  40/800     headlineMedium 24/700     titleMedium  16/600
displaySmall   32/700     headlineSmall  20/700     titleSmall   14/600

bodyLarge  15/400   bodyMedium 14/400   bodySmall 12.5/400
labelLarge 14/600   labelMedium 12/600  labelSmall 11/700 ← «BERAMAN» kabi yorliqlar
```

Eski shkala 22 dan 28 ga, undan 32 ga sakrardi va oraliqda ishlatiladigan
narsa yo'q edi — shuning uchun ekranlar bo'lim sarlavhasi uchun `titleLarge`
ni qarzga olardi va hamma narsa baqirardi.

---

## 4. Shakl ierarxiyani ko'taradi

```dart
Radii.xs    8    chip, nishon
Radii.sm   12    kichik plitka, rasm
Radii.md   16    input, tugma      ← barmoq tushadigan narsalar
Radii.lg   20    karta
Radii.xl   28    panel, dialog
Radii.full 999   pill, avatar
```

Birinchi versiyada karta ham, input ham, tugma ham, dialog ham **bir xil 24px**
edi. Natijada hech narsa boshqasidan muhimroq ko'rinmasdi. Odam so'zdan oldin
shaklni o'qiydi — demak shakl darajani tashishi kerak.

### Oraliq — 4px to'r

```dart
Gap.x1 4   Gap.x2 8   Gap.x3 12   Gap.x4 16
Gap.x5 20  Gap.x6 24  Gap.x8 32   Gap.x10 40
```

Column ichida `Gap.h4`, Row ichida `Gap.w2`. Bo'sh son yozilmaydi.

### Tugma balandligi

```
Sizes.buttonSm 40   ikkinchi darajali
Sizes.buttonMd 48   standart
Sizes.buttonLg 56   ekrandagi asosiy amal
```

Ilgari hammasi 60 edi.

---

## 5. San'at chiziladi, yuklanmaydi

Kod: `app/lib/core/art/`.

### Girih — loyihaning o'z naqshi

`girih.dart` — sakkiz burchakli yulduz panjarasi (**xatam**), Samarqand va
Buxoro koshinkorligidan. `CustomPainter` bilan chiziladi.

Nega aynan shu: oddiy gradient dunyodagi istalgan bozorga tegishli bo'lishi
mumkin, bu naqsh esa **aynan shu bozorga** tegishli. Pichirlab ishlatiladi —
sezilishi kerak, lekin ko'rinmasligi kerak, va hech qachon fotosurat bilan
raqobatlashmasligi kerak.

| Qayerda | Qanday |
|---|---|
| Intro, kirish, profil to'ldirish foni | Yashil chiziq, `opacity 0.055`, pastga qarab so'nadi |
| Lenta sarlavhasidagi gradient | Oq chiziq, `opacity 0.14` — to'q maydonda qora chiziq yo'qoladi |
| Ishonch qalqoni ichida | Qalqon shakli bilan kesilgan |
| Moslik chokida | Bitta yulduz — mos kelishning o'zi |

### Illyustratsiyalar

`illustrations.dart` — beshta rasm, yo'llar (path) bilan chizilgan.

⚠️ **Ikonka quti ichida — illyustratsiya emas.** Ikonka belgi: u so'z o'rnida
turadi. Illyustratsiya esa sodir bo'layotgan narsaning rasmi, bu yerda esa
aniq bir narsa sodir bo'ladi: ikki odam bir-biriga tovar uzatadi, ba'zan
farqni pul yopadi. Hech qanday ikonka to'plamida bu yo'q — shuning uchun
chiziladi.

| Rasm | Nima | Qayerda |
|---|---|---|
| `SwapIllustration` | Ikki quti qo'l almashadi, orada tanga | Intro 1 |
| `MatchIllustration` | Ikki yarim qulflanadi — o'xshash emas, **mos** ikki narsa | Intro 2 |
| `TrustIllustration` | Koshin naqshli qalqon, yulduzlar bilan qozonilgan | Intro 3 |
| `EmptyIllustration` | Ochiq bo'sh quti | Bo'sh holatlar |
| `BrokenIllustration` | Sinib qolgan almashinuv strelkasi | Xato holatlari |

Quti ataylab telefon yoki guruch qopi emas: bu ilova noutbuk, traktor, qoramol
va shifer tashiydi — hammasini ifodalaydigan yagona shakl bu **ichida nimadir
bor quti**.

Xato holati ham umumiy ogohlantirish uchburchagi emas, **mahsulotning o'z
tilida**: uzilib qolgan almashinuv strelkasi.

### Nega chiziladi

- Har o'lchamda tiniq
- Qorong'i temaga o'zi moslashadi (rangni palitradan oladi)
- Yuklamaga bir bayt qo'shmaydi
- Litsenziya muammosi yo'q

Ilgari bo'sh va xato holatlari `Lottie.network` bilan tashqi CDN'dan animatsiya
tortardi — sekin internetda bo'sh kvadrat, internetsiz esa umuman yo'q, **aynan
xato ekrani kerak bo'lgan paytda**.

### Fon — `AuroraBackground`

Bir burchakdan yashil, ikkinchisidan ko'k yumshoq shu'la, ustidan girih
panjarasi. Radial gradient, blurlangan rasm emas: yuklab olinadigan fayl yo'q,
har kadrda blur hisoblanmaydi.

**Faqat o'z suratlari yo'q ekranlarda.** Fotosuratlar lentasi ostida sokin
sahifa kerak, e'tibor uchun kurashadigan ikkinchi narsa emas.

## 5.5 Web — o'sha ilova, boshqa emas

720px dan keng ekranda ilova **telefon ramkasi ichida** markazda turadi
(`core/widgets/device_frame.dart`). Orqa fon — girih naqshi, ya'ni qurilma
atrofidagi bo'shliq ham mahsulotga tegishli.

Nega: ilgari keng ekranda chapdan panel chiqardi — ikkinchi navigatsiya modeli,
o'z chrome'i va o'z layoutlari bilan. Bu bozorning hammasi dalada yoki
ustaxonada turgan telefon uchun qurilgan; noutbukdan tashrif — o'sha narsani
kattaroq ekranda ko'rayotgan odam, boshqa mahsulot emas.

Ramka `MaterialApp.builder` da, navigator ustida — shuning uchun bosiladigan
marshrutlar, panellar va dialoglar ham uning ichida. `MediaQuery` ham
almashtiriladi, aks holda chat pufagi o'zini butun oyna kengligiga o'lchardi.

## 6. Umumiy komponentlar

| Komponent | Nima uchun |
|---|---|
| `TradeSides` | «X ⇄ Y» — mahsulotdagi eng ko'p takrorlanadigan fikr, bir marta chizilgan |
| `CategoryTile` | Kategoriya avval rasm, keyin so'z |
| `CategoryBadge` | Kartadagi kichik bo'lim nishoni |
| `PhotoWell` | Surat tanlash maydoni — profil va e'lon yaratishda |
| `StateArt` | Bo'sh/xato holati rasmi (standart — chizilgan illyustratsiya) |
| `GirihField` | Koshin panjarasi |
| `SwapBanner` | Naqshli gradient sarlavha |
| `DeviceFrame` | Web'da telefon ramkasi |
| `SkeletonBox` | Yuklanayotgan ekran o'z shaklini darrov ko'rsatadi |
| `Pill` | Ma'no tashiydigan yorliq: give / take / money |
| `errorMessage()` | Serverning o'zbekcha xatosini o'zgartirmay ko'rsatadi |

---

## 7. Har ekran uchun tekshiruv ro'yxati

- [ ] To'rt holat: yuklanmoqda / xato / bo'sh / ma'lumot
- [ ] Barcha matn `l10n` dan — qattiq kodlangan satr yo'q
- [ ] `theme.textTheme` ishlatiladi, xom `TextStyle(fontSize: …)` emas
- [ ] Ranglar `palette(context)` yoki `colorScheme` dan, `Colors.grey` emas
- [ ] Oraliqlar `Gap`, radiuslar `Radii` dan
- [ ] Sana `DateFormat`, pul `Money.format`
- [ ] 375px va 1280px da tekshirilgan
- [ ] Yorug' va qorong'i temada o'qiladi
- [ ] Uch tilda ham kesilmaydi (ruscha eng uzun)
- [ ] `flutter analyze` → 0 muammo

---

## 8. Qaror mezoni

Yangi ekran yoki komponent qo'shayotganda:

1. **Bu C segmentga tushunarlimi?** Matnni olib tashlasangiz, nima qilish
   kerakligi ko'rinadimi?
2. **Ikkilik ko'rinyaptimi?** Har ekran «nima beriladi / nima olinadi» savoliga
   javob berishi kerak.
3. **Bu token bilan qilinadimi?** Bo'sh son yoki yangi rang qo'shishdan oldin
   `tokens.dart` ga qarang.
4. **Rasm fayl kerakmi?** Ehtimol kerak emas — `core/art/` da chizib bo'ladi.
5. **Ishlamaydigan tugma qo'shyapmanmi?** Qo'shmang. Ishlamaydigan tugma
   egallagan joyidan qimmatroq turadi: u odamga bu ilovaning tugmalari bezak
   ekanini o'rgatadi.

## Tashqi assetlar auditi

Desktopdagi `flutterdevs/` papkasi to'liq ko'rib chiqildi — undan hech narsa
olinmadi, sababi:

| Repo | Nima bor | Xulosa |
|---|---|---|
| `flutter_Ecommerce_UI_clone` | 32 ta PNG | Flipkart brendi (`flipkart-plus`, `fk-plus`) va mahsulot fotolari — birovning tovar belgisi |
| `flutter_classified_app` | 20 ta PNG/JPG | Aeologic brendi, 2019 yildagi mahsulot fotolari |
| `flutter_splash_app` | 3 ta skrinshot | Faqat demo rasmlari, asset emas |
| `awesome-flutter` | Havolalar ro'yxati | Fayl yo'q; Animation bo'limidagi `flutter_animate` bizda allaqachon ishlatiladi |

Butun papkada **birorta ham Lottie (`.json`) yoki Rive (`.riv`) fayli yo'q**,
wallpaper ham yo'q. Shu sababli fon, illyustratsiya va naqshlarning hammasi
kod bilan chizilgan:

- `core/art/girih.dart` — Samarqand va Buxoro koshinlaridagi sakkiz burchakli
  yulduz panjarasi (`CustomPainter`)
- `core/art/illustrations.dart` — beshta illyustratsiya
- `core/widgets/backgrounds.dart` — `AuroraBackground` (wallpaper),
  `SwapBanner` (feed sarlavhasi)

Bu shunchaki huquqiy ehtiyotkorlik emas: chizilgan fon har qanday o'lchamda
o'tkir qoladi, qorong'i mavzuga o'zi moslashadi, yuklab olish hajmiga hech
narsa qo'shmaydi va tarmoqsiz ham ko'rinadi — aynan xato ekrani chiqqan
paytda CDN dan kelmay qoladigan Lottie animatsiyasidan farqli.

**Wallpaper qayerda ishlatiladi:** intro, kirish, profil sozlash, tasdiqlash.
Ya'ni o'z rasmi yo'q ekranlarda. E'lonlar lentasi kabi fotosuratga to'la
ekranlarda fon tekis qoladi — aks holda ikkita narsa e'tibor uchun kurashadi.
