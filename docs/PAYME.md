# Payme integratsiyasi (1-bosqich)

To'lov Payme sahifasida bo'ladi: foydalanuvchi karta raqami, amal qilish muddati va SMS kodni **Payme'da** kiritadi. Karta ma'lumoti MAB serveriga umuman kelmaydi.

## Payme'ga beriladigan ma'lumotlar

Shartnoma va kassa ochishda Payme so'raydi:

| Nima | Qiymat |
|---|---|
| Endpoint (Merchant API URL) | `https://api.mab.uz/payments/payme` |
| Protokol | Merchant API (JSON-RPC 2.0), HTTP `POST` |
| Hisob maydoni (account) | `order_id` — buyurtma raqami (UUID, 36 belgi) |
| Summa birligi | tiyin (1 so'm = 100 tiyin) |
| Sayt | `https://mab.uz` |
| Qaytish sahifasi | `https://mab.uz/payments/return?order=<id>` |

Payme kabinetida (business.paycom.uz → Kassa → Sozlamalar) **hisob maydoni nomi aynan `order_id`** bo'lishi kerak.

## Server sozlamasi (`api/.env`)

```
PAYME_MERCHANT_ID=<kassa ID>
PAYME_KEY=<kassa kaliti>                         # sinovda — test kaliti
PAYME_CHECKOUT_URL=https://test.paycom.uz        # jangovar: https://checkout.paycom.uz
PAYME_RETURN_URL=https://mab.uz/payments/return?order={order_id}
```

Ikkalasi bo'sh bo'lsa to'lov o'chiq: buyurtma 503 qaytaradi, endpoint har so'rovga `-32504`. Productionda faqat bittasi to'ldirilsa server ishga tushmaydi.

Kalitni hech kimga yubormang va git'ga qo'ymang. Kalit almashtirilsa (`.env` + qayta ishga tushirish), Payme kabinetida ham almashtiring.

## Oqim

1. Ilova `GET /payments/products` — admin belgilagan faol tariflar (chegirma bilan).
2. `POST /payments/orders {product_code, listing_id?}` — buyurtma, javobda `checkout_url`.
3. Ilova `checkout_url` ni brauzerda ochadi → foydalanuvchi Payme'da to'laydi.
4. Payme `https://api.mab.uz/payments/payme` ga `CheckPerformTransaction` → `CreateTransaction` → `PerformTransaction` yuboradi.
5. `PerformTransaction` da buyurtma `paid` bo'ladi va natija qo'llanadi:
   - `listing_pack` — foydalanuvchiga N ta e'lon qo'shiladi;
   - `boost` — e'lon N kunga premium (muddat ustiga qo'shiladi).
6. Ilova `GET /payments/orders/{id}` bilan holatni tekshiradi.

Qo'llab-quvvatlanadigan metodlar: `CheckPerformTransaction`, `CreateTransaction`, `PerformTransaction`, `CancelTransaction`, `CheckTransaction`, `GetStatement`, `SetFiscalData`.

Qoidalar:

- **Bitta buyurtma, bitta faol to'lov.** Ikkinchi tranzaksiya `-31052` oladi, shunda bitta xarid uchun ikki marta pul yechilmaydi.
- **12 soat chegarasi.** 12 soatdan eski yaratilgan tranzaksiya bajarilmaydi va 4-sabab (vaqt tugadi) bilan bekor qilinadi.
- **Bajarilgan to'lov bekor qilinmaydi** (`-31007`). Pul qaytarish qo'lda, qo'llab-quvvatlash orqali qilinadi.
- **Buyurtma summasi yaratilgan paytda qotadi.** Admin narxni o'zgartirsa, ochiq buyurtmalarga ta'sir qilmaydi.

## Narxlar va chegirmalar — admin panel

`https://api.mab.uz/admin` → **To'lovlar**:

- tarif qo'shish/o'zgartirish: kod, nomi (uz/ru/en), narx (so'm), chegirma % va tugash sanasi, e'lonlar soni yoki boost kunlari, faol/o'chiq;
- **«Bepul kvota tugaganda e'lon pullik»** kaliti. Sukut bo'yicha o'chiq, ya'ni narxlar belgilanmaguncha e'lon joylash cheklanmaydi. Uni yoqish uchun kamida bitta faol e'lon paketi bo'lishi shart;
- oxirgi buyurtmalar ro'yxati.

Fiskal chek uchun tarifga MXIK (IKPU) va o'lchov birligi kodini kiriting. Kodlar bo'lsa, `CheckPerformTransaction` chek tafsilotini (`detail`) qaytaradi. Kodlarni buxgalteriya yoki soliq maslahatchisidan oling.

## Sinov (sandbox)

1. Payme test kassa beradi: test ID va test kaliti.
2. `.env` ga test ID va kalitini, `PAYME_CHECKOUT_URL=https://test.paycom.uz` ni yozing.
3. Payme sinov sahifasida (test.paycom.uz → kassani tanlash → endpoint `https://api.mab.uz/payments/payme`) hamma ssenariylarni o'tkazing. Ular `api/tests/test_payme.py` da lokal tekshirilgan.
4. Sinov o'tgach, Payme jangovar kalitni beradi. `PAYME_KEY` va `PAYME_CHECKOUT_URL=https://checkout.paycom.uz` ni almashtiring.

## Hali qilinmagan (keyingi bosqichlar)

- Flutter ekranlari: tariflar, "To'lash" tugmasi, `checkout_url` ni ochish, holatni tekshirish, 402 bo'lganda tarif taklif qilish.
- `https://mab.uz/payments/return` sahifasi (web).
- Oylik obuna (Basic/Business/Pro). Bu Payme Subscribe API yoki takroriy to'lov bilan qilinadi.
- Bepul kvotani har oy yangilash.
- Click, Uzum va boshqa to'lov tizimlari. Ular `services/billing.py` dagi umumiy mantiqni ishlatadi.
- Payme IP manzillaridan boshqa so'rovlarni rad etish (ixtiyoriy, kalitga qo'shimcha himoya).
