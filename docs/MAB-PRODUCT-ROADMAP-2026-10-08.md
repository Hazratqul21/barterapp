# MAB: barterga xos yangi imkoniyatlar va amalga oshirish rejasi

Sana: 2026-10-08. Holat: mahsulot taklifi; quyidagi yangi funksiyalar hali amalga oshirilgani bildirilmaydi. Hujjat UI/UX dizaynini emas, mahsulot mazmuni, savdo qoidalari va texnik bajarish yo‘lini qamrab oladi.

## Asosiy tavsiya

MABning kuchli tomoni «e’lon joylashtirish» bilan tugamasligi kerak. U **mendagi narsani xohlaydigan va menga kerakli narsasi bor odamni topish, shartlarni kelishish va almashinuvni yakunlash** xizmatiga aylanishi kerak.

Birinchi navbatda to‘rtta yo‘nalishni tavsiya qilaman:

1. Haqiqiy ikki tomonlama moslashtirish: ikkala odamning ehtiyoji hisobga olinsin.
2. Bitim shartlarini saqlash va ikki tomon tasdiqlaydigan topshirish jarayoni.
3. Talab e’lonlari va mos taklif paydo bo‘lganda xabar berish.
4. Miqdor bilan ishlash: mahsulotning bir qismini almashish va qoldiqni hisoblash.

Bularning maqsadi funksiyalar sonini ko‘paytirish emas, muvaffaqiyatli almashinuvlar ulushini oshirish. Qisman almashishning ustuvorligi boshlang‘ich auditoriyaga bog‘liq: fermer va kichik biznesda yuqori; asosan telefon va shaxsiy buyumlar bozorida keyinroq bajarilishi mumkin.

## 1. Loyihada bor narsalar va haqiqiy bo‘shliqlar

Quyidagi holatlar kodga asoslangan. Eski biznes-rejada yozilgan imkoniyat mavjud va ishlab turgan funksiya deb qabul qilinmadi.

| Yo‘nalish | Hozirgi asos | Taklif qilinayotgan rivojlanish |
|---|---|---|
| E’lon va ehtiyoj | E’lon, rasmlar, tarjimalar, toifa va qiymat chegarali `Desire` bor | Toifaga xos xususiyatlar, aniq pul qo‘shish chegarasi, mustaqil talab |
| Moslashtirish | Qiymat, masofa, reyting va toifa asosidagi ball bor | Ikkala tomon istagini tekshirish va dalilga asoslangan sabablar |
| Taklif | Qarshi taklif, pul farqi, bir nechta buyumni taklif qilish bor | O‘zgarmas kelishuv nusxasi, har bir buyumning miqdori, ikki tarafdan to‘plam |
| Yakunlash | `accepted → completed` amalini tomonlardan biri bajara oladi | Ikkala ishtirokchining alohida topshirish/qabul qilish tasdig‘i |
| Ishonch | Sharh, shikoyat, bloklash, verifikatsiya modeli bor | Tekshirilgan dalillar, haqiqiy bitim tarixi va nizoni ko‘rib chiqish jarayoni |
| Xabarlar | Chat, bildirishnomalar va push uchun asos bor | Saqlangan ehtiyojga mos, takrorlanmaydigan, rozilikka asoslangan xabarlar |
| Miqdor | E’lon tarjimasida matnli `quantity` bor | Sonli qoldiq, o‘lchov birligi va band qilish hisobi |
| AI | E’lon tayyorlashga yordam beruvchi servis bor | Faktlarni tasdiqlatish, tuzilmali xususiyatlar ajratish va tarjima nazorati |
| To‘lov | Pul farqi va to‘lov usuli haqidagi ma’lumotlar mavjud | Haqiqiy escrow yoki pul o‘tkazish bor deb bo‘lmaydi; alohida loyiha talab qiladi |

Muhim topilma: moslashtirish hozir bir tomonning `Desire` shartlarini tekshiradi. «Ular aynan sizning toifangizni izlamoqda» yoki «mavsumiy talab yuqori» kabi izohlar har doim tegishli faktga tayanmaydi. Moslik balli bitim bo‘lish ehtimoli yoki kafolati sifatida ko‘rsatilmasligi kerak.

## 2. Takliflar

### F01. Ikki tomonlama barter mosligi va aniq ehtiyojlar

**Misol:** Alida guruch bor, unga muzlatkich kerak. Valida muzlatkich bor, lekin u guruchni emas, telefonni istaydi. Bunday juftlik faqat qiymati yaqinligi sababli «juda mos» bo‘lmasligi kerak.

**Birinchi versiya:** ikkala tomon qabul qiladigan toifa, kerakli xususiyatlar, hudud va qiymat chegaralari tekshiriladi. Majburiy shart bilan afzallik ajratiladi. Istagi noma’lum odam «o‘zaro mosligi tasdiqlangan» deb belgilanmaydi. «Har qanday taklifni ko‘raman» alohida, foydalanuvchi bildirgan tanlov bo‘ladi.

**Amalga oshirish:**

- `Desire`ga aniq `max_cash_topup_minor`, valyuta, masofa chegarasi va tuzilmali talablar qo‘shish; hozirgi avtomatik 2× qiymat cho‘zilishini yangi ma’lumotlar uchun almashtirish.
- Toifaga xos xususiyatlar lug‘ati: masalan, telefon uchun model/xotira/holat; guruch uchun nav/miqdor/birlik. Faqat tanlangan boshlang‘ich toifalardan boshlash.
- `matching.py`da A→B va B→A shartlarini tekshirish. Avval SQL orqali nomzodlarni qisqartirish, so‘ng ball hisoblash; barcha e’lonlarni doimiy juftlab chiqishni kamaytirish.
- Natijada `reason_codes`, qo‘llangan qoidalar versiyasi va yetishmayotgan ma’lumotni qaytarish. Izohlar shu faktlardan tuziladi.
- Moslash uchun qiymat — egasining taxmini; yakuniy pul farqi tomonlar kelishgan shart. Turli valyutalarni kurs manbaisiz taqqoslamaslik.

**Qabul mezoni:** faqat bir tomon rozi bo‘ladigan juftlik o‘zaro mos deb chiqmaydi; pul chegarasidan tashqari juftlik majburiy shartdan o‘tmaydi; sababi ma’lumotdan tekshiriladi. O‘lchov: o‘zaro mos natijadan yuborilgan va qabul qilingan takliflar ulushi.

**Ustuvorlik:** P0. Bog‘liqlik: toifa xususiyatlari va ehtiyoj ma’lumotlarini to‘ldirish. Hajm: katta.

### F02. Kelishuv nusxasi, band qilish va ikki tomonlama yakunlash

**Misol:** bir telefon bir vaqtda ikki odamga va’da qilinmasin; bir ishtirokchi «tugatish» bilan ikkinchisining e’lonini ham yopib yubormasin.

**Birinchi versiya:** kelishuvda kim nima beradi, holati, pul farqi, topshirish usuli va muddati saqlanadi. Ikkala tomon shartlarni qabul qiladi. Topshirishdan keyin har biri olgan narsasini tasdiqlaydi. Faqat ikkala tasdiqdan keyin bitim yakunlanadi.

**Amalga oshirish:**

- `TradeAgreement`, `AgreementLine`, `TradeConfirmation`, `Reservation` modellarini kiritish. Bular taklif qilinayotgan yangi nomlar.
- Har bir shartlar versiyasi o‘zgarmas bo‘lsin. E’lon keyin tahrirlansa, qabul qilingan kelishuv o‘zgarmaydi. Qarshi taklif yangi versiya yaratadi va oldingi roziliklarni bekor qiladi.
- Bitta buyumli bitimda qabul qilish paytida buyumni band qilish. Qisman almashish keyin shu mexanizmni sonli qoldiqqa kengaytiradi.
- Bir tranzaksiyada tegishli e’lonlarni bir xil tartibda bloklash; bir e’lonni turli takliflarda bir vaqtda band qilishni DB cheklovi bilan to‘xtatish. Faqat taklif qatorini bloklash yetmaydi.
- Muddati o‘tgan bandni fon vazifasi bo‘shatadi. Bitta tasdiq kelganda avtomatik muvaffaqiyat yozilmaydi; eslatma yoki nizo ko‘rib chiqish yo‘li ishlaydi.
- Yangi tasdiqlash amallari uchun idempotency kaliti va versiya tekshiruvi. Eski mobil ilovaning `complete` amali yangi qoidani chetlab o‘tmasligi kerak.

**Qabul mezoni:** bir vaqtdagi ikkita qabuldan faqat bittasi bir buyumni band qiladi; takror so‘rov hisobni o‘zgartirmaydi; bitta tasdiq savdoni yakunlamaydi; nizo paytida odatiy yakunlash to‘xtaydi. O‘lchov: ikki taraf tasdiqlagan bitimlar va yakunlashgacha vaqt.

**Ustuvorlik:** P0. Bog‘liqlik: taklif holatlari migratsiyasi. Hajm: katta. Bu mexanizm haqiqiy pulni saqlash yoki o‘tkazish xizmati emas.

### F03. «Menga kerak» talab e’lonlari va mos taklif xabarlari

**Misol:** fermerga keyingi haftada suv nasosi kerak, evaziga kartoshka taklif qiladi. Hozir nasos topilmasa ham ehtiyoji saqlanadi va mos e’lon kelganda xabar oladi.

**Birinchi versiya:** foydalanuvchi ehtiyoj, hudud, muddat va taklif qila oladigan narsalarni belgilaydi. Hali buyum qo‘shmagan odam talabni saqlashi mumkin, lekin barter taklifini yuborishdan oldin nimani berishini aniqlaydi. Talab e’loni mahsulot qoldig‘i sifatida hisoblanmaydi.

**Amalga oshirish:** `Demand`, `DemandSupplyLink`, `SavedSearch`, `AlertDelivery` modellarini qo‘shish. Talab va umumiy saqlangan qidiruv bitta moslashtirish xizmatidan foydalanadi. E’lon yaratilishi yoki muhim sharti o‘zgarishi outbox hodisasi yaratadi; worker mos talablarni tekshiradi. `(user, demand, listing, match_version)` asosida xabarni takror yuborish cheklanadi.

Foydalanuvchi xabar turiga rozilik beradi; darhol yoki jamlanma rejim, o‘chirish, muddati tugash va chastota chegarasi bo‘ladi. Push ishlamasa, ilova ichidagi xabar saqlanadi. Qiziqish bildirilgan talab egasining aloqa ma’lumotlari avtomatik ochilmaydi.

**Qabul mezoni:** bekor qilingan talabga xabar bormaydi; qayta ishlangan hodisa takror push yaratmaydi; mos kelmagan natija yuborilmaydi. O‘lchov: talabdan malakali taklifgacha vaqt va talablarning bitimga aylanishi.

**Ustuvorlik:** P1. Bog‘liqlik: F01, ishchi bildirishnoma infratuzilmasi. Hajm: o‘rta–katta.

### F04. Qisman almashish, miqdor va ikki tomonlama to‘plam

**Misol:** 10 tonna guruch egasi uning 500 kilogrammini muzlatkichga almashtiradi; qolgan 9,5 tonna savdoda qoladi. Ikkinchi misol: bir telefon evaziga noutbuk va printer kelishiladi.

**Birinchi versiya:** tanlangan qishloq xo‘jaligi yoki qurilish toifalarida miqdor, birlik, minimal partiya va qisman berish imkoniyati. Bir nechta buyumni taklif qilish allaqachon bor; yangilik — har ikki tarafdagi aniq miqdorlar va qoldiqni hisoblash.

**Amalga oshirish:** `ListingStock` va rezervatsiya harakatlari hisobi; `AgreementLine`da tomon, listing, miqdor va birlik. Miqdor uchun `Decimal`, pul uchun kichik birlikdagi integer ishlatiladi. Kg↔tonna kabi aniq konversiyalar qo‘llanadi; «qop» vazni egasi aniqlamaguncha kilogrammga aylantirilmaydi.

`available = total − completed − reserved` qoidasi tranzaksiyada saqlanadi. Bekor qilish rezervni qaytaradi. Butun e’lon faqat qoldiq nol bo‘lganda yopiladi. Eski matnli `quantity` avtomatik taxmin qilib zaxiraga o‘tkazilmaydi: egasi miqdorni tasdiqlaydi yoki e’lon bir butun lot sifatida qoladi.

**Qabul mezoni:** parallel takliflar qoldiqni manfiy qilmaydi; 500 kg bitim 10 tonnalik e’lonni to‘liq yopmaydi; bir xil bekor qilish ikki marta zaxira qo‘shmaydi. O‘lchov: qisman yakunlangan almashinuvlar va ombordagi miqdor bo‘yicha xatolar.

**Ustuvorlik:** P1, fermer/B2B pilotida yuqori. Bog‘liqlik: F02. Hajm: katta.

### F05. Ishonch pasporti va ishlaydigan nizo jarayoni

**G‘oya:** bitta umumiy «ishonch foizi» o‘rniga uning manbalari bo‘lsin: ikki tomon tasdiqlagan bitimlar, sharhlar soni, tekshiruv turi, oxirgi faollik va kuzatilgan javob vaqti. Telefonni tasdiqlash mahsulot sifatiga kafolat bo‘lmaydi.

**Birinchi versiya:** hisoblangan bitim statistikasi; tekshiruv holatlari; bitimga bog‘langan shikoyat, dalil, mas’ul moderator va qaror tarixi. Nizo ochilganining o‘zi odamni aybdor yoki firibgar deb belgilamaydi. Qarorga e’tiroz yo‘li bo‘ladi.

**Amalga oshirish:** F02 hodisalaridan statistika; javob vaqtini haqiqiy xabar va javob juftliklaridan hisoblash; namunalar yetarli bo‘lmasa «ma’lumot yetarli emas». `DisputeCase`, dalillarga ruxsat nazorati va audit jurnali. Hujjatlarni profilga ochiq chiqarmaslik, saqlash muddati va o‘chirish tartibini belgilash. Bir-biriga sun’iy bitim yozadigan akkauntlar signali moderatorga yuboriladi, avtomatik ayblov chiqarilmaydi.

**Qabul mezoni:** begona foydalanuvchi nizo dalillarini o‘qiy olmaydi; sharh faqat haqiqiy yakunlangan bitimdan; moderator qarori kim va qachon chiqargani qayd etiladi. O‘lchov: 100 ta bitimga nizolar, ko‘rib chiqish vaqti, qayta ochilgan ishlar.

**Ustuvorlik:** P1; oddiy nizo operatsiyasi F02 bilan birga. Bog‘liqlik: mas’ul operator/moderator. Hajm: o‘rta–katta.

### F06. Uchrashuv va yetkazib berishni kelishish

**G‘oya:** kim olib boradi, qayerda, qachon, transport xarajatini kim to‘laydi — bitimning bir qismi bo‘lsin.

**Birinchi versiya:** uchrashuv yoki yetkazish, vaqt oralig‘i, mas’ul tomon va kelishilgan xarajat. Dastlab transportni qo‘lda kelishish yetarli; tekshirilmagan logistika APIlariga bog‘lanmaslik.

**Amalga oshirish:** kelishuvga `FulfillmentPlan`; aniq manzil faqat kelishuv ishtirokchilariga; muddat eslatmalari. Kuryerning yetkazdim degan hodisasi avtomatik ravishda ikki taraf roziligini almashtirmaydi. Keyinchalik real hamkor tanlangach narx so‘rovi, buyurtma, webhook imzosi va qayta urinishlar integratsiyasi.

**Qabul mezoni:** vaqt o‘zgarishini ikki taraf ko‘radi va qayta kelishadi; manzil ommaviy qidiruvga chiqmaydi; transport hodisasi yolg‘iz o‘zi bitimni tugatmaydi. O‘lchov: qabul qilingan, lekin topshirilmagan bitimlar sabablari.

**Ustuvorlik:** P1, oddiy versiya. Bog‘liqlik: F02. Hajm: o‘rta.

### F07. Tovar evaziga xizmat

**Misol:** usta uch kunlik ta’mirlash xizmati evaziga maishiy texnika oladi; fermer hosilning bir qismini texnika xizmatiga almashtiradi.

**Birinchi versiya:** bitta aniq yakunlanadigan xizmat: ish hajmi, bajarilish muddati, hudud, material kimdan va qabul mezoni. «Ta’mirlab beraman» kabi noaniq taklif yetarli bo‘lmaydi. Ko‘p bosqichli yirik ishlarni keyinroq qo‘shish.

**Amalga oshirish:** `listing_kind=goods|service`, `ServiceScope` va vaqt mavjudligi. Matcher xizmatning hudud/muddat shartlarini ham tekshiradi. F02 kelishuvida bajariladigan natija va qabul mezonlari nusxalanadi. Xizmat haqidagi maxsus e’tirozlar F05 orqali yuradi.

**Qabul mezoni:** xizmat qoldig‘i kilogramm bilan hisoblanmaydi; band qilingan vaqt ikkinchi bitimga berilmaydi; ish hajmi tahriri avvalgi kelishuvni o‘zgartirmaydi. O‘lchov: tovar↔xizmat bitimlari va shu turdagi nizolar.

**Ustuvorlik:** P2. Bog‘liqlik: F02, F05, F06. Hajm: katta.

### F08. Mavsum, mavjudlik muddati va takroriy ehtiyoj

**Misol:** hosil faqat noyabrda tayyor bo‘ladi; yangi mahsulot uch kun ichida topshirilishi kerak; korxonaga har oy bir xil xomashyo kerak.

**Birinchi versiya:** «hozir bor», «falon sanada tayyor», «falon sanagacha taklif amal qiladi» va qayta tasdiqlash. Qaytalanuvchi ehtiyoj eslatma yaratadi, avtomatik bitim tuzmaydi.

**Amalga oshirish:** `available_from`, `available_until`, `last_confirmed_at`; muddatli fon vazifalari va matcherda sanalar kesishmasi. Saqlangan talabning yangi davri egasining tasdig‘idan keyin faollashadi. Haqiqiy ma’lumot bo‘lmasa «mavsumiy talab yuqori» degan xulosa chiqarilmaydi.

**Qabul mezoni:** muddati o‘tgan mahsulot yangi takliflarga faol ko‘rinmaydi; davom etayotgan kelishuv yo‘qolmaydi; kelajakdagi mahsulot hozir tayyor sifatida chiqmaydi. O‘lchov: «mahsulot allaqachon yo‘q» sababli bekor qilish ulushi.

**Ustuvorlik:** P1 uchun oddiy mavjudlik, P2 uchun takroriy ehtiyoj. Bog‘liqlik: fon vazifalari. Hajm: o‘rta.

### F09. Kichik biznes uchun zaxira importi va yopiq taklif yig‘ish

**Misol:** korxonada ortiqcha qurilish materiali bor; uni boshqa zarur materiallarga almashtirish uchun bir nechta hamkordan taklif yig‘adi.

**Birinchi versiya:** CSV orqali qoralama e’lon importi, takror mahsulotni aniqlash, yopiq talabga belgilangan hamkorlarni taklif qilish. Platforma o‘zi tashqi odamlarga xabar yubormaydi; biznes vakili kimni taklif qilishini tanlaydi.

**Amalga oshirish:** `Organization`, `Membership`, `ImportJob`, `RFQ`, `RFQResponse`; egasi/operator/tasdiqlovchi rollari. Import avval tekshiriladi, keyin egasi tasdiqlab chop etadi. Takliflar muddatigacha raqobatchilarga ochilmaydi. Bir importni qayta yuborish dublikat yaratmaydi. Dastlab ERP va buxgalteriya integratsiyasini kiritmaslik.

**Qabul mezoni:** boshqa tashkilot ma’lumotiga kirish yopiq; operator o‘ziga berilmagan yirik bitimni tasdiqlay olmaydi; xato CSV qisman yashirin nashr qilinmaydi. O‘lchov: faol bizneslar, takror bitimlar, importdan faol e’longacha vaqt.

**Ustuvorlik:** P2, biznes auditoriyasi tasdiqlansa. Bog‘liqlik: F02, F04. Hajm: katta.

### F10. Uch tomonlama barter zanjiri

**Misol:** A guruch beradi va nasos xohlaydi; B nasos beradi va telefon xohlaydi; C telefon beradi va guruch xohlaydi. Ikki tomonli kelishuv topilmasa, uchalasi uchun aylana hosil bo‘ladi.

**Birinchi versiya:** faqat uch ishtirokchi, bitta hudud, pul farqisiz va operator yordamida tashkil qilinadigan pilot. Har bir ishtirokchi nimani berishi va kimdan nima olishini aniq tasdiqlaydi. Buni oddiy `OfferItem`lar bilan to‘liq hal qilib bo‘lmaydi.

**Amalga oshirish:** F01 mosliklaridan yo‘naltirilgan graf; faqat cheklangan eng yaxshi nomzodlar orasida uzunligi 3 sikllar. Yangi `TradeGroup`, `TradeLeg`, ishtirokchi roziliklari va guruh rezervatsiyasi. Barcha zaxiralar bitta DB tranzaksiyasida band qilinadi yoki hech biri band qilinmaydi.

Bazadagi atomarlik haqiqiy hayotdagi topshirishni atomar qilmaydi. Shu sabab bir joyda muvofiqlashtirilgan topshirish va oldindan bekor qilish/nizo tartibi kerak. Bir kishi chiqib ketsa qolganlar avtomatik «yakunlandi» holatiga o‘tmaydi. Keyinchalik pul farqi qo‘shilsa, ko‘p tomonli hisob-kitob alohida loyihalanadi.

**Qabul mezoni:** uchta buyumning bittasi band bo‘lsa guruhning qolgan rezervlari ham yaratilmaydi; faqat ikki rozilik bilan guruh faollashmaydi; takror hisoblash dublikat guruh chiqarmaydi. O‘lchov: ikki tomonlama yo‘l topilmagan ehtiyojlardan haqiqiy yakunlangan uch tomonlama bitimlar.

**Ustuvorlik:** P3. Bog‘liqlik: yetarli faol e’lonlar, F01/F02/F05/F06. Hajm: juda katta. Eski biznes-rejada ham uchraydi; tavsiya — uni nazoratli pilotga aylantirish.

### F11. AI yordamchisini e’lon sifatiga xizmat qildirish

**G‘oya:** mavjud e’lon yaratish yordamchisi yetishmayotgan ma’lumotni aniqlasin, tarjimani tayyorlasin va matndan tuzilmali xususiyatlar ajratsin.

**Birinchi versiya:** foydalanuvchi bir tilda faktlarni beradi; yordamchi tarjimalar va xususiyatlar qoralamasini yaratadi. Egasi tasdiqlamaguncha ular mahsulot fakti bo‘lmaydi. AI suratga qarab «original», «nuqsonsiz» yoki «ishonchli sotuvchi» degan kafolat bermaydi.

**Amalga oshirish:** mavjud `ai_backend` oqimiga sxema bo‘yicha natija, manba matni, noaniq qiymatlar va foydalanuvchi tasdig‘ini qo‘shish. Narx tavsiyasini faqat yetarli haqiqiy taqqoslanadigan ma’lumot bo‘lganda alohida tajriba sifatida boshlash; e’lon narxini bitim qiymati deb qabul qilmaslik.

**Qabul mezoni:** matnda bo‘lmagan holat, quvvat yoki model tayyor fakt sifatida yozilmaydi; AI xatosida qo‘lda e’lon yaratish davom etadi; foydalanish limiti va xarajat nazorati mavjud. O‘lchov: egasi tuzatgan xususiyatlar ulushi, nashr qilingan to‘liq e’lonlar va bitta e’longa servis xarajati.

**Ustuvorlik:** P2. Bog‘liqlik: F01 xususiyatlar lug‘ati. Hajm: o‘rta.

## 3. Qaysi tartibda bajarish kerak?

Hajm baholari muddat va’dasi emas: «o‘rta» bir nechta model/API va platformalararo tekshiruvni, «katta» savdo qoidalari, migratsiya va parallel so‘rovlar testlarini anglatadi. Aniq kun hisobini boshlang‘ich auditoriya va jamoa quvvati tanlangach chiqarish kerak.

| Bosqich | Ish | Keyingisiga o‘tish sharti |
|---|---|---|
| 0. Tayanch | Amaldagi savdo oqimini haqiqiy qurilmalarda tekshirish; OTP/push va operator jarayonini ishlatish; boshlang‘ich metrikalarni olish | Ro‘yxatdan o‘tishdan taklif va chatgacha oqim ishonchli ishlaydi, xatolar kuzatiladi |
| 1. Asosiy barter | F01ning bir necha toifadagi versiyasi + F02 + oddiy nizo ko‘rib chiqish | O‘zaro moslik tushuntiriladi; bitta buyum ikki bitimga band bo‘lmaydi; ikki tasdiq ishlaydi |
| 2. Faol savdo | F03 + F08ning mavjudlik qismi + F06ning oddiy versiyasi | Talablar mos taklif oladi; xabarlar takrorlanmaydi; topshirilmagan bitimlar sababi ma’lum |
| 3. Auditoriyaga mos chuqurlik | Fermer/B2B bo‘lsa F04 va F09; xizmat talabi bo‘lsa F07; e’lon to‘ldirish qiyin bo‘lsa F11 | Tanlangan imkoniyat pilotda ishlatiladi va yakunlangan bitimga hissa qo‘shadi |
| 4. Murakkab kengayish | F10 piloti, haqiqiy logistika integratsiyasi, zarurat bo‘lsa escrow tahlili | Asosiy barter ishlaydi; operatsion mas’ul va real hamkorlar bor |

Boshlang‘ich sinov uchun bitta hudud va bir-biriga bog‘liq 2–3 toifadan foydalanish tavsiya qilinadi. Masalan, qishloq xo‘jaligi mahsuloti, kichik uskuna va qurilish materiali. Bu tanlov faraz: uni hozirgi foydalanuvchi va e’lonlar ma’lumotlari bilan tekshirish kerak.

20–30 nafar rozilik bildirgan faol ishtirokchi bilan yordam ko‘rsatiladigan pilot o‘tkazish mumkin. Bu statistik isbot yoki bozor hajmi bahosi emas; moslik, kelishuv va topshirishdagi to‘siqlarni topish usuli. Har bir muvaffaqiyatsiz almashinuv sababi yozilsin: istak mos emas, qiymat kelishilmadi, masofa, mahsulot yo‘q, javob yo‘q yoki ishonch muammosi.

## 4. Texnik bajarish tamoyillari

Mavjud Flutter ilova va Python API ushbu funksiyalarni bosqichma-bosqich qo‘shish uchun asos bo‘la oladi. Bu takliflarning o‘zi iOS va Androidni qaytadan alohida yozishni talab qilmaydi. Savdo qoidalari serverda yagona bo‘ladi; mobil va web bir xil qoidaga bo‘ysunadi.

1. **Qo‘shimcha migratsiyalar:** yangi maydonlar boshida ixtiyoriy; eski e’lonlarga taxminiy miqdor yoki talab to‘qilmaydi. Faol eski kelishuvlar uchun alohida migratsiya va tushunarli o‘tish qoidasi yoziladi.
2. **API versiyalash:** yangi kelishuv amallari eski `complete` orqali chetlab o‘tilmasin. Eski mijozga yangilanish talabi yoki mos tushuntirilgan javob beriladi; eski amal ikki tarafni avtomatik tasdiqlamasin.
3. **Ma’lumotlar yaxlitligi:** rezerv, qoldiq, tasdiq va holat o‘zgarishlari tranzaksiya, unique/check cheklovlari va idempotency bilan himoyalanadi.
4. **Fon ishlari:** qidiruvdan tashqari moslashtirish, band muddati va xabarlar uchun outbox va worker. DBga yozilgan hodisa yo‘qolmasin; xabar servisi yiqilsa bitim yo‘qolmasin. Dastlab mikroservislarga ajratish shart emas.
5. **Bosqichli ishga tushirish:** feature flag orqali bitta toifa/hududda yoqish. Flag o‘chishi boshlangan bitimlarni tashlab qo‘ymaydi; yakunlash jarayoni ishlashda davom etadi.
6. **Tekshiruv:** API integratsiya va parallel band qilish testlari; worker takroriy ishlash testlari; eski/yangi ilova mosligi; iOS, Android va webda asosiy bitim yo‘li. Faqat ekran ko‘rinishi testlari yetarli emas.
7. **Qaytarish rejasi:** yangi taklif yaratishni to‘xtatish mumkin, lekin mavjud rezerv va tasdiqlar audit tarixini o‘chirmaslik. Destruktiv migratsiyani dastlabki chiqarishda bajarmaslik.

Taklif qilinayotgan API yo‘llariga misollar: `POST /demands`, `POST /offers/{id}/agreements`, `POST /agreements/{id}/accept`, `POST /agreements/{id}/confirm-receipt`, `POST /agreements/{id}/disputes`. Yakuniy nomlar amaldagi API konvensiyasiga moslashtiriladi; hozir bu endpointlar mavjudligi da’vo qilinmaydi.

## 5. Natijani nimada o‘lchaymiz?

Asosiy ko‘rsatkich: **ikki tomon tasdiqlagan, takror hisoblanmagan yakuniy barter bitimlari soni**. Nizo keyin ochilsa uning holati alohida kuzatiladi. Uch tomonli bitim bir guruh sifatida hisoblanadi; uni uchta mustaqil muvaffaqiyat qilib ko‘paytirmaslik kerak.

| Ko‘rsatkich | Hisoblash qoidasi | Nimani tushuntiradi |
|---|---|---|
| Moslik qamrovi | Kamida bitta o‘zaro mos faol nomzodi bor faol e’lonlar / barcha faol e’lonlar; hudud/toifa bo‘yicha | Bozorda bir-biriga kerakli taklif bormi? |
| Taklif qabul qilinishi | Qabul qilingan noyob takliflar / yuborilgan noyob takliflar; bir davr kohortasi | Moslashtirish va shartlar sifati |
| Yakunlash ulushi | Ikki taraf tasdiqlagan bitimlar / qabul qilingan bitimlar; tugashiga vaqt berilgan kohorta | Kelishuv haqiqiy almashinuvga yetdimi? |
| Birinchi mos taklifgacha vaqt | E’lon faollashganidan shartlariga mos birinchi taklifgacha median vaqt; hali taklif olmaganlar ulushi ham beriladi | Foydalanuvchi qanchalik tez foyda oladi? |
| Takror foydalanish | Birinchi bitimdan keyin 30/60 kun ichida yana yakunlangan bitim qilganlar / kuzatuv davri to‘lgan foydalanuvchilar | Mahsulot qayta kerak bo‘lyaptimi? |
| Nizolar va bekor qilish | 100 ta qabul qilingan bitimga holatlar, sabablar va hal qilish vaqti | Savdo sifati va operatsion yuk |

Mavjud `EventKind` hodisalariga kelishuv qabul qilindi, rezerv yaratildi/bo‘shadi, har bir taraf topshirishni tasdiqladi, talab mosligi topildi va bekor qilish sababi kabi hodisalar qo‘shiladi. Yakunlangan bitim serverdagi holatdan olinadi; mijoz yuborgan analytics hodisasi muvaffaqiyat isboti bo‘lmaydi. Boshlang‘ich ma’lumot olinmaguncha foizli o‘sish va’dalari berilmaydi.

## 6. Daromad modeli va keyinga qoldiriladigan ishlar

Daromad bo‘yicha avval **biznesga real vaqt tejaydigan vositalar**ni sinash mumkin: katta hajmda import, jamoaviy rollar, takroriy hamkorlar va zaxira hisobotlari uchun obuna. Narx va talab alohida tekshiriladi. Asosiy bozorda yetarli taklif paydo bo‘lmasdan har bir oddiy amalni pullik qilish savdoni kamaytirishi mumkin — bu sinov bilan tekshiriladigan faraz.

Pullik ko‘tarish bo‘lsa, reklama ekanligi aniq bo‘ladi va majburiy barter shartlariga mos kelmagan e’lon «eng mos» deb olinmaydi. Ishonch belgisi pulga sotilmaydi. Platformadan tashqarida topshiriladigan tovarlarda komissiyani hisoblash va undirish qanday ishlashi oldindan aniqlanadi.

Hozir birinchi navbatga qo‘ymaslik tavsiya etiladi:

- **Ichki token, kripto yoki universal barter valyutasi:** asosiy moslik muammosini hal qilmasdan alohida murakkablik yaratadi.
- **To‘liq escrow:** provayder imkoniyati, ikki tomondagi tovar va pul oqimi, nizo/refund tartibi, xarajat va tegishli talablar aniqlangandan keyin alohida qaror. `refunded` statusi borligi pul qaytarish integratsiyasi borligini anglatmaydi.
- **Hamma toifani birdan ochish:** talab va taklifni tarqatib yuborishi mumkin; avval tanlangan bozorda ishlashini tekshirish.
- **AI narx yoki ishonch kafolati:** yetarli dalilsiz mahsulot bahosi, originallik va sotuvchi ishonchliligini kafolatlamaslik.
- **Ijtimoiy lenta va murakkab gamifikatsiya:** bitimga olib borishi isbotlanmaguncha asosiy savdo resursini sarflamaslik.

## 7. Ish boshlashdan oldingi mahsulot qarorlari

Quyidagi savollar alohida funksiyalar hajmini aniqlaydi; hujjatdagi tavsiya ularning javobi ma’lum deb faraz qilmaydi:

- Birinchi asosiy auditoriya kim: oddiy odamlar, fermerlar yoki kichik biznes?
- Boshlang‘ich hudud va eng ko‘p faol e’lonli toifalar qaysilar?
- Nizoni kim ko‘rib chiqadi va foydalanuvchiga qaysi vaqt ichida javob bera oladi?
- Pul farqi dastlab tomonlar o‘rtasida kelishiladimi yoki provayder integratsiyasi kerakmi?
- Qo‘lda yordam beriladigan dastlabki bitimlar uchun kim mas’ul bo‘ladi?

Tavsiya etilgan birinchi ish paketi: **F01 va F02ni kichik toifalar to‘plamida ishlab chiqish, oddiy nizo jarayonini yo‘lga qo‘yish va haqiqiy bitimlarni kuzatish**. Keyingi tanlov foydalanuvchilarning aynan qayerda to‘xtayotganiga qarab qilinadi.

## 8. Kod va hujjat manbalari

Yo‘llar repository ildiziga nisbatan berilgan. Ular takliflarni mavjud loyiha bilan bog‘laydi; eski rejalardagi barcha va’dalar amalga oshirilgan deb olinmagan.

- `api/app/services/matching.py` — amaldagi moslashtirish va izohlar.
- `api/app/models/desire.py` — ehtiyoj chegaralari va pul qo‘shish bayroqlari.
- `api/app/models/listing.py` — e’lon, toifalar, tarjima va matnli miqdor.
- `api/app/models/offer.py`, `api/app/services/offers.py`, `api/app/api/offers.py` — taklif, qarshi taklif, yakunlash va e’lon holatlari.
- `api/app/models/event.py` — mavjud kuzatuv hodisalari.
- `app/lib/features/trade/presentation/create_listing_page.dart` — e’lon va ehtiyoj kiritish oqimi.
- `ai_backend/lib/generate_listing_flow.dart` — mavjud AI yordamchisi asosi.
- `docs/DOMAIN.md`, `docs/biznes-reja/Barter_Biznes_Reja.md` — mahsulotning dastlabki mazmuni va rejalari.
- `docs/MARKETPLACE-AUDIT-2026-10-08.md` — avvalgi texnik audit va chiqarishdan oldingi ochiq ishlar.
