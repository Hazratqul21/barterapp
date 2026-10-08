# F02 — kelishuvlar, band qilish, nizolar

## Oqim

1. **Qabul** (`accept`): shartlar `trade_agreements`ga muzlatiladi; savdodagi **barcha** e'lonlar bitta tranzaksiyada band qilinadi (`reservations`, holat `in_negotiation`) — yoki hech biri. Bitta e'londa bir vaqtda faqat bitta faol band bo'ladi (qisman unikal indeks). E'lonlar id tartibida qulflanadi — deadlock yo'q.
2. **Tasdiq** (`confirm`; eski nomi `complete`): har bir tomon alohida. Ikkalasi tasdiqlagach — `completed`, e'lonlar yopiladi, raqib takliflar `expired`.
3. **Muddat:** band `reservation_hours` (standart 72) ichida ikki tasdiq bo'lmasa — `expired`, e'lonlar sotuvga qaytadi. Hozircha `/offers` so'rovlarida tekshiriladi (`agreements.expire_stale`); keyin cron ishchi chaqiradi.
4. **Nizo** (`dispute` + `dispute_reason`): savdo pauzaga (`disputed`), band muddati to'xtaydi.

## Nizo qoidalari (admin panel → "Nizolar")

| Sozlama | Standart | Ma'nosi |
|---|---|---|
| `reservation_hours` | 72 | Band qilish muddati |
| `auto_max_value_minor` | 5 000 000 so'm | Bundan qimmat savdo — har doim operatorga |
| `auto_cancel_reasons` | `no_show` | Qoida avtomatik bekor qila oladigan sabablar |

Qoida faqat **hammasi** bajarilganda hal qiladi: summa chegarada, sabab ro'yxatda, **va** ikkinchi tomon hali tasdiqlamagan (tasdiq "kelmadi"ga zid — buni odam ko'rishi kerak). Aks holda → operator navbati. Har saqlash `version`ni oshiradi; har nizoda qaysi qoida va versiya qaror qilgani saqlanadi (`decided_by_rule`, `rules_version`).

## Operator

Moderator hisobi: `GET /admin/disputes` (navbat), `POST /admin/disputes/{id}/resolve` — `cancel` (bekor, e'lonlar qaytadi) yoki `complete` (savdo kuchda); izoh majburiy, ikkala tomonga bildirishnoma.
