# Huquqiy hujjatlar

Hujjatlar endi **admin panelda** turadi va saytda ochiladi:

| Hujjat | Manzil |
|---|---|
| Maxfiylik siyosati | https://mab.uz/privacy |
| Foydalanish shartlari | https://mab.uz/terms |
| Ommaviy oferta (Payme uchun) | https://mab.uz/offer |
| Hisobni o'chirish (Google Play uchun) | https://mab.uz/delete-account |
| Admin qo'shgan boshqa hujjatlar | https://mab.uz/legal/&lt;nom&gt; |

**Tahrirlash:** https://api.mab.uz/admin → **Hujjatlar**. Matn Markdown'da,
uch tilda (UZ majburiy; tarjimasi yo'q til o'zbekchani ko'rsatadi).
Matnni `.md`/`.txt` fayldan yuklash va PDF nusxa biriktirish mumkin.
Saqlangan zahoti saytda yangilanadi — deploy kerak emas. Sahifada
«Oxirgi yangilanish» sanasi o'zi qo'yiladi.

Boshlang'ich matn: `api/app/legal_defaults/*.md` (faqat birinchi
migratsiyada bazaga yoziladi; keyingi o'zgarishlar faqat admin panelda).

| Fayl | Nima uchun |
|---|---|
| [STORE-DATA-SAFETY.md](STORE-DATA-SAFETY.md) | App Store "Privacy Labels" va Google Play "Data safety" formalariga tayyor javoblar. |

---

## ⚠️ Bularni e'lon qilishdan oldin

**1. Yurist ko'rib chiqsin.** Bu huquqiy hujjat va sizning kompaniyangiz
nomidan chiqadi. Men uni texnik jihatdan to'g'ri yozdim — nima yig'ilishi,
qayerda saqlanishi, qancha turishi — lekin javobgarlik bandlari va
O'zbekiston qonunchiligiga muvofiqligi yurist ishi.

Ayniqsa tekshirilishi kerak: **«Shaxsga doir ma'lumotlar to'g'risida»gi
O'zbekiston Respublikasi qonuni** (2019, 547-son) talablari, xususan
ma'lumotlarni **mamlakat hududida saqlash** majburiyati. Bu serveringiz
qayerda joylashishini belgilaydi.

**2. `{{...}}` belgilarini to'ldiring.** Hujjatlarda o'zim to'qib
yozmagan joylar shunday belgilangan:

```
{{KOMPANIYA_NOMI}}      {{HUQUQIY_MANZIL}}       {{STIR}}
{{ALOQA_EMAIL}}         {{ALOQA_TELEFON}}        {{VEB_SAYT}}
{{KUCHGA_KIRISH_SANASI}}   {{SUD_YURISDIKSIYASI}}   {{HOSTING_PROVAYDER}}
```

Bularni to'qib yozish — hujjatni yaroqsiz qilish, shuning uchun bo'sh
qoldirdim.

Admin panel to'ldirilmagan belgilarni ro'yxat qilib ko'rsatadi.

**3. Uch tilga tarjima qiling.** Hozir faqat o'zbekcha. Ilova uz/ru/en da
ishlaydi, ya'ni siyosat ham shunday bo'lishi kerak. Aytsangiz tarjimasini
ham yozib beraman.

**4. Havolani do'konlarga kiriting.** Ikkala do'kon ham **ochiq
havola** talab qiladi — bu `https://mab.uz/privacy`:

- App Store Connect → App Information → Privacy Policy URL
- Play Console → App content → Privacy policy

**5. Hisobni o'chirish sahifasi** (faqat Google Play): Play Console →
Data deletion ga `https://mab.uz/delete-account` ni kiriting.

**6. Ommaviy oferta** — Payme shartnomasi uchun saytda bo'lishi shart:
`https://mab.uz/offer`. Bank rekvizitlarini (`{{BANK_NOMI}}`,
`{{HISOB_RAQAMI}}`, `{{MFO}}`) ham to'ldiring.

---

## Ilova ichida qayerda ko'rinishi kerak

Sozlamalar → pastki qismda:

```
Maxfiylik siyosati        →   (veb-sahifa ochiladi)
Foydalanish shartlari     →   (veb-sahifa ochiladi)
Hisobni o'chirish         →   (tasdiqlash oynasi → DELETE /me)
```

Va ro'yxatdan o'tish ekranida, "Kodni yuborish" tugmasi ostida:

> Davom etish orqali siz **Foydalanish shartlari** va **Maxfiylik
> siyosati**ga rozilik bildirasiz.

Ikkala nom ham bosiladigan havola bo'lsin.

---

## Hujjat kodga bog'liq — kod o'zgarsa, hujjat ham o'zgaradi

Bu eng tez eskiradigan hujjat turi. Quyidagilar o'zgarsa, siyosatni ham
yangilash kerak:

| Kodda o'zgarish | Siyosatda nima o'zgaradi |
|---|---|
| Yangi `EventKind` qo'shilsa | 3-bo'lim: yig'iladigan hodisalar |
| FCM/APNs ulansa | 5-bo'lim: uchinchi tomonlar |
| To'lov tizimi ulansa | Yangi bo'lim + Data Safety formasi |
| Saqlash muddati o'zgarsa (`events_prune`, `media_sweep`) | 6-bo'lim: muddatlar |
| Yangi tashqi xizmat qo'shilsa | 5-bo'lim va Data Safety formasi |

Shuning uchun [BACKEND-CHANGELOG.md](../BACKEND-CHANGELOG.md) da bunday
o'zgarish bo'lsa, shu papkani ham ko'zdan kechiring.
