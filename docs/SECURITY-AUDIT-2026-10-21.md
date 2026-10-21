# Xavfsizlik tekshiruvi — 2026-10-21

Birinchi deploydan oldin butun loyiha besh yo'nalishda tekshirildi: kirish va
ruxsatlar, kiruvchi ma'lumot, server va baza, to'lov va savdo mantiqi, ilova
va sayt. Har bir topilma lokal serverda **so'rov yuborib tasdiqlangan**, keyin
tuzatilib, testga qo'shilgan.

Repoda va git tarixida parol, kalit, server IP manzili yoki `.env` topilmadi.

## Tuzatildi

### Jiddiy

| # | Muammo | Tuzatish | Test |
|---|---|---|---|
| 1 | Taklif yuborgan odam unga o'zi qarshi taklif berib, so'ng o'zi qabul qila olardi — qarshi tomon ko'rmagan shartda e'lon band bo'lardi | Qarshi taklifni faqat taklif kelgan tomon beradi | `test_integrity` |
| 2 | SMS kod: 60 ta parallel noto'g'ri urinish 5 urinishli kodga 37 marta tekshirilardi; parallel so'rovlar 5 ta o'rniga 8 ta SMS yuborardi | Bitta telefon bo'yicha so'rovlar navbat bilan (Postgres advisory lock) | `test_otp_races` |
| 3 | SMS kodni oylar davomida taxmin qilish mumkin edi (kuniga ~2 400 urinish), IP bo'yicha chegara yo'q | Kuniga 15 noto'g'ri urinish, IP bo'yicha chegaralar, butun xizmat bo'yicha SMS chegarasi | `test_otp_races` |
| 4 | 164 KB'lik "bomba" PNG API'ni 5 soniya qotirib, ~800 MB xotira yerdi | Piksel chegarasi sarlavhadan tekshiriladi, faqat JPEG/PNG/WebP, qayta ishlash alohida oqimda | qo'lda |
| 5 | `/events` ga 5 MB'lik yuk yuborish mumkin edi (kirmagan holda ham) | Yuk 2 000 belgi; JSON so'rovlar 1 MB | qo'lda |
| 6 | E'lon matni cheksiz (10 MB tavsif qidiruvni sekinlashtirardi); 160+ belgili sarlavha 500 qaytarardi | Har maydonga uzunlik chegarasi; matnli qidiruvga chegara | qo'lda |
| 7 | 1 ta kredit bilan 8 ta parallel so'rov 4 ta e'lon joylardi; e'lon va to'lov bir vaqtda kelsa, sotib olingan kreditlar yo'qolardi | Kredit bitta atomik `UPDATE` bilan sarflanadi va qo'shiladi | `test_integrity` |
| 8 | Hisob o'chirilsa, qabul qilingan savdodagi qarshi tomonning e'loni abadiy "band" qolardi | Band olib tashlanadi, e'lon yana sotuvga chiqadi | `test_integrity` |
| 9 | Zaxira nusxa yo'q edi | Har kuni avtomatik + har deploydan oldin (`mab-backup`) | — |
| 10 | 2 ta API jarayoni: chat xabarlari yarim holatda yetmasdi, chegaralar ikki barobar edi | 1 jarayon (Redis qo'shilguncha) | — |

### O'rta

- **Admin panel:** feed-block sarlavhasidagi `'` belgisi orqali skript qo'yish mumkin edi, endi bu yopilgan. Panelga CSP, `X-Frame-Options` va `no-store` qo'shildi.
- **Rasm havolalari:** e'lon va xabardagi suratlar faqat bizning `/media/` dan qabul qilinadi. Begona havola yoki `javascript:` bilan endi "kuzatuv surati" qo'yib bo'lmaydi.
- **Chat:**
  - ulanish chiptasi faqat bir marta ishlaydi;
  - o'chirilgan hisob ulana olmaydi;
  - hisob o'chirilsa yoki "hamma joydan chiqish" bosilsa, ochiq ulanishlar darhol uziladi.
- **Payme:** to'lov olinmaydi, agar:
  - buyurtma o'chirilgan hisobniki bo'lsa;
  - boost qilinayotgan e'lon arxivlangan bo'lsa.

  Hisob o'chirilganda to'lanmagan buyurtmalar ham yopiladi.
- **Nizo:**
  - nizodagi e'lonni egasi tahrirlay yoki arxivlay olmaydi;
  - moderator o'zi qatnashgan nizoni hal qila olmaydi.
- **Yashirin e'lonlar:** arxivdagi va qoralama e'lonni endi faqat egasi, savdo tomoni va moderator ko'radi.
- **Server:**
  - nginx'ga xavfsizlik sarlavhalari qo'shildi: HSTS, CSP, nosniff, frame-ancestors.
  - Noma'lum domen yoki to'g'ridan-to'g'ri IP bilan kelgan so'rovlar rad etiladi.
  - systemd himoyasi qo'shildi: kod faqat o'qish uchun, yozish faqat `media` ga.
  - Deploy fayllari endi har safar yangi xavfsiz papka orqali o'tadi (ilgari doimiy `/tmp` nomlari ishlatilardi).
  - Baza paroli jarayonlar ro'yxatida ko'rinmaydi.
  - Eski SMS kodlar va sessiyalar har kuni tozalanadi.
  - Bazaga indekslar qo'shildi.
- **Ilova:**
  - Token yangilash qotib qolgan siklga tushmaydi.
  - Internet bir zum uzilsa, foydalanuvchi hisobdan chiqarib yuborilmaydi.
  - Chiqishda sessiya serverda ham bekor qilinadi va push o'chiriladi.
  - Android zaxira nusxasiga token tushmaydi (`allowBackup=false`).
  - Payme havolasi faqat `paycom.uz` ga ochiladi.
  - Havoladagi ID'lar tekshiriladi.

### Kichik

- **API:**
  - Productionda `/docs` va `/openapi.json` yopiq.
  - Fayl havolalari so'rovdagi Host sarlavhasidan emas, `PUBLIC_API_URL` dan yasaladi.
- **Payme:** ASCII bo'lmagan kalit endi 500 qaytarmaydi.
- **Admin, narxlar:**
  - Chegirma sanasi vaqt mintaqasisiz kiritilsa, Toshkent vaqti deb olinadi.
  - Narx va naqd farqiga yuqori chegara qo'yildi.
- **Sharh:** ikki bosishdan keyin 500 emas, 409 qaytadi.
- **Reliz:** `.aab` debug kalit bilan imzolanmaydi. Release ilovada OTP kod avtomatik to'ldirilmaydi.

## Qoldi (keyingi bosqich)

| Nima | Nega hozir emas |
|---|---|
| Moderator uchun foydalanuvchini bloklash (ban) | Yangi funksiya: model, endpoint, admin bo'limi |
| Web'da refresh token'ni HttpOnly cookie'da saqlash; Android'da `flutter_secure_storage` | Kirish oqimini qayta qurish kerak; CSP va `allowBackup=false` hozircha xavfni kamaytiradi |
| Redis: bir nechta API jarayoni uchun chat va chegaralar | Hozirgi yuklama uchun 1 jarayon yetarli |
| `requirements.txt` versiyalarini qat'iy belgilash (lock) | Serverdagi Python 3.14 bilan sinab, alohida qilinadi |
| Deploydan keyin muvaffaqiyatsiz bo'lsa avtomatik orqaga qaytarish (release papkalari) | Hozir zaxira nusxa va health-check bor |
| Push: Android uchun `google-services.json` | Firebase loyihasi sozlanganda |
| Payme'da bajarilgan to'lovni qaytarish (refund) | Payme qoidasi bo'yicha qo'lda; jarayon hujjatlashtiriladi |
