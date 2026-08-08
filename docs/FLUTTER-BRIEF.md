# Flutter qurish topshirig'i

**Bu hujjat mustaqil topshiriq.** Uni o'qigan dasturchi yoki AI backend kodini
ko'rmasdan, faqat shu hujjat va [`API.md`](API.md) yordamida BarterApp mijozini
oxirigacha yoza oladi.

Backend **tayyor va ishlab turibdi** — 27 ta endpoint, hammasi sinalgan.
O'zgartirish kerak emas.

---

## 1. Mahsulot bir jumlada

> Naqd pulsiz ayirboshlash. Foydalanuvchi «sotaman» demaydi — **«menda ortiqcha X
> bor, menga Y kerak»** deydi.

Butun dizayn shu ikkilikka bo'ysunadi. Har bir ekranda savdoning **ikki tomoni**
ko'rinishi kerak: nima **beriladi** va nima **olinadi**.

Bu ranglarda ham kodlangan:

| Ma'no | Rang | Qayerda |
|---|---|---|
| **Beraman** (give) | Yashil `#0E6444` | E'lon egasi beradigan narsa |
| **Olaman** (take) | Ko'k `#1D3F9C` | «Kerak:» bloklari, xohishlar |
| **Pul** | Oltin `#9A6D13` | Narx, premium, o'qilmagan badge |

---

## 2. Nima allaqachon yozilgan

`app/` papkasida quyidagilar **tayyor va ishlaydi**:

| Qism | Fayl | Holat |
|---|---|---|
| Dizayn tokenlari (radius, oraliq, o'lcham) | `core/theme/tokens.dart` | ✅ |
| Tema, ranglar, `BarterPalette` | `core/theme/app_theme.dart` | ✅ |
| Surat tanlash va yuklash | `core/widgets/photo_picker.dart` | ✅ |
| Til almashtirish | `localeProvider` | ✅ |
| API klienti, token, til | `core/network/api_client.dart` | ✅ |
| Router, tab bar / yon panel | `core/router/` | ✅ |
| Umumiy vidjetlar | `core/widgets/common.dart` | ✅ |
| **Barcha modellar** | `shared/models/models.dart` | ✅ |
| **Barcha repository va provider** | `features/trade/data/trade_repository.dart` | ✅ |
| Uch til (151 kalit) | `l10n/app_{uz,ru,en}.arb` | ✅ |
| Lenta | `features/feed/` | ✅ |
| E'lon sahifasi | `features/listing/` | ✅ |
| Kirish (telefon + SMS) | `features/auth/` | ✅ |

**Ya'ni: ma'lumot qatlami butunlay tayyor.** Qolgani — UI.

### Ekranlar — hammasi yozilgan

| # | Ekran | Route | Izoh |
|---|---|---|---|
| 1 | Splash + intro | `/`, `/intro` | Uch slayd, bir marta ko'rsatiladi |
| 2 | Kirish | `/signin` | Telefon + SMS |
| 3 | Profil to'ldirish | `/onboarding` | Ism, hudud, surat |
| 4 | Lenta | `/home` | Hero, kategoriyalar, cheksiz scroll |
| 5 | E'lon sahifasi | `/listing/:id` | |
| 6 | E'lon yaratish | `/create` | 4 bosqich |
| 7 | Taklif yuborish | `/offer/:listingId` | |
| 8 | Chat + kelishuv paneli | `/chat/:id` | |
| 9 | Xabarlar | `/inbox` | |
| 10 | Mosliklar | `/matches` | |
| 11 | Bildirishnomalar | `/notifications` | |
| 12 | Profil | `/profile` | Sozlamalar shu yerdan ochiladi |
| 13 | Savdogar profili | `/trader/:id` | |
| 14 | Sozlamalar / tasdiqlash / to'lovlar | `/settings*` | |

Yangi ekran qo'shayotgan bo'lsangiz, avval **[DESIGN.md](DESIGN.md)** ni
o'qing — rang, shrift, radius va oraliqlar u yerda belgilangan.

---

## 2.5 Bilib qo'yish kerak bo'lgan qarorlar

**Suhbat taklifsiz mavjud bo'lmaydi.** `conversations.offer_id` — `NOT NULL`
va `UNIQUE`. Shuning uchun «bu odamga xabar yozish» tugmasi yo'q va bo'lmaydi:
odamga yetib borish yo'li — uning e'loniga taklif yuborish.

**Qarshi taklif — bu yangi taklif emas.** `PATCH /offers/{id}` `counter`.
U tomonlarni almashtiradi, ya'ni `is_mine` teskarisiga o'zgaradi. Yangi taklif
yaratishga urinish server tomonidan rad etiladi.

**Ishlamaydigan tugma qo'shmang.** Apple/Google/Facebook kirish tugmalari va
ikkita «Xabar yozish» tugmasi olib tashlandi — hammasi «keyinroq» derdi.
Ishlamaydigan tugma egallagan joyidan qimmatroq turadi.

## 3. Ishni boshlash

```bash
# 1. Baza va backend
cd barter-platform
docker compose up -d
cd api && .venv/bin/uvicorn app.main:app --port 8010 --reload

# 2. Mijoz
cd ../app
flutter pub get
flutter gen-l10n
flutter run -d chrome
```

Kirish: **+998901234122** (SMS kodi javobda qaytadi va maydonga o'zi to'ladi).

---

## 4. Har bir ekran uchun majburiy naqsh

Bu naqshdan chetga chiqmang — ilovaning butunligi shunga tayanadi.

```dart
class SomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);          // tarjimalar
    final p = palette(context);        // give / take / money ranglari
    final async = ref.watch(someProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (e, _) => ErrorState(
        message: e is ApiException && e.isNetworkFailure
            ? l.errorNetwork
            : (e is ApiException ? e.message : l.errorGeneric),
        retryLabel: l.retry,
        onRetry: () => ref.invalidate(someProvider),
      ),

      data: (items) => items.isEmpty
          ? EmptyState(title: l.someTitle, hint: l.someEmpty)
          : ListView(...),
    );
  }
}
```

**To'rt holat majburiy:** yuklanmoqda / xato / bo'sh / ma'lumot.
Hech bir ekran bo'sh oq sahifa ko'rsatmasin.

⚠️ `ApiException.message` — serverdan kelgan **o'zbekcha, odam tilidagi** xato.
Uni o'z matningiz bilan almashtirmang.

### Kirish talab qiladigan ekranlar

```dart
if (!ref.watch(authStateProvider)) {
  return Scaffold(appBar: AppBar(title: Text(l.inboxTitle)), body: const SignInPrompt());
}
```

`SignInPrompt` — tayyor vidjet (`features/trade/presentation/inbox_page.dart`
ichida yozilishi rejalashtirilgan; yo'q bo'lsa `core/widgets/` ga ko'chiring).

---

## 5. Ekranlarning tafsiloti

### 5.1 Xabarlar ro'yxati — `/inbox`

**Ma'lumot:** `ref.watch(conversationsProvider)` → `List<ConversationSummary>`

Har bir qator:

```
┌────────────────────────────────────────────────┐
│ (avatar)  Bekzod Karimov              14:11    │
│  ●online  ┌──────────────────────┐             │
│           │ ⇄ MacBook ↔ iPhone 13│  KUTILMOQDA │ ← deal_summary + status
│           └──────────────────────┘             │
│           Shanba kuni ko‘rishsak bo‘ladimi?  ②  │ ← last_message + unread
└────────────────────────────────────────────────┘
```

Qoidalar:
- **`deal_summary` xabardan yuqori turadi.** Savdo — thread'ning mavjud bo'lish
  sababi, oddiy xabar emas.
- `offer_status` `isLive` bo'lmasa (`completed`/`declined`/`expired`) — avatar
  va pill kulrang, presence nuqtasi yo'q.
- `unread > 0` → ism qalin + oltin rangli badge.
- Bosilganda `context.push('/chat/${thread.id}')`.

Status yorliqlari: `l.dealPending`, `l.dealTalking`, `l.dealAccepted`,
`l.dealDeclined`, `l.dealCompleted`, `l.dealExpired`.

### 5.2 Chat — `/chat/:id`

**Ma'lumot:** `conversationProvider(id)` → `ConversationDetail`
(`summary` + `offer` + `messages`).

Uch qavat:

```
┌──── AppBar ────────────────────────────┐
│ ← (avatar) Bekzod Karimov  ⓥ           │ ← bosilsa /trader/{peer.id}
│            Onlayn · ★4.7               │
├──── KELISHUV PANELI (qadalgan) ────────┤
│ KUTILAYOTGAN SAVDO      46 soatda tugaydi│
│ MacBook Pro 14" + 1 260 000 so'm       │
│              ⇄                          │
│ iPhone 13 · 256 GB                     │
│ [Qabul qilish]  [Qarshi taklif]        │ ← faqat kerakli tugmalar
├──── XABARLAR ──────────────────────────┤
│                    Salom! ...    14:02 │
│ Ha — 14", M3 Pro...  14:04             │
├──── YOZISH ────────────────────────────┤
│ [Xabar yozing…]                    [→] │
└────────────────────────────────────────┘
```

**Kelishuv paneli — eng muhim qism.** Tugmalar `offer.status` va `offer.isMine`
dan kelib chiqadi:

| Status | `isMine == true` | `isMine == false` |
|---|---|---|
| `pending`, `talking` | *Kutilmoqda* (tugmasiz) | **Qabul qilish · Rad etish · Qarshi taklif** |
| `accepted` | **Savdoni yakunlash** | **Savdoni yakunlash** |
| `completed`, `declined`, `expired` | Faqat status | Faqat status |

⚠️ `counter` dan keyin `isMine` **teskarisiga o'zgaradi**. Har `PATCH` javobidan
keyin `ref.invalidate(conversationProvider(id))` qiling.

Amal yuborish:

```dart
await ref.read(tradeRepositoryProvider).act(offer.id, 'accept');
ref.invalidate(conversationProvider(threadId));
ref.invalidate(conversationsProvider);
```

**Live ulanish:**

```dart
@override
void initState() {
  super.initState();
  ref.read(liveChannelProvider).connect();
}

// build() ichida:
ref.listen(liveChannelProvider.select((c) => c.events), (_, event) {
  if (event case MessageArrived(conversationId: final id) when id == widget.id) {
    ref.invalidate(conversationProvider(id));
  }
  if (event case PeerTyping(conversationId: final id) when id == widget.id) {
    setState(() => _peerTyping = true);
    // 3 soniyadan keyin o'chiring
  }
});
```

Yozayotganda: `ref.read(liveChannelProvider).typing(threadId);` (throttle bilan,
har harfda emas).

### 5.3 Taklif yuborish paneli — `/offer/:listingId`

Pastdan chiqadigan panel (`showModalBottomSheet` yoki push route).

```
┌── Savdo taklif qilish              ✕ ──┐
│ ┌────────────────────────────────────┐ │
│ │ (rasm) SIZGA KERAK                 │ │ ← target listing
│ │        iPhone 13 · 256 GB          │ │
│ │        ⓥ Bekzod Karimov · 781 200  │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Taklif qilish uchun e'loningizni tanlang│
│ [MacBook]  [40 t guruch]  [Isuzu]      │ ← myListingsProvider, gorizontal
│                                        │
│ Pul qo'shish  (savdoni tenglashtirish) │
│ [ 1 260 000                        ]   │
│                                        │
│ MacBook + 1 260 000 so'm ⇄ iPhone 13   │ ← jonli xulosa
│                                        │
│ [      Taklifni yuborish          ]    │
└────────────────────────────────────────┘
```

- `myListingsProvider` bo'sh bo'lsa → `l.offerNoItems` va «E'lon yaratish» tugmasi.
- Yuborish:

```dart
final offer = await ref.read(tradeRepositoryProvider).sendOffer(
  listingId: widget.listingId,
  offeredListingIds: [selectedId],
  cashDeltaMinor: cash * 100,   // so'm → tiyin
  message: messageController.text,
);
if (context.mounted) context.go('/chat/${offer.conversationId}');
```

⚠️ **Panel yopilganda qayerdan kelgan bo'lsa o'sha yerga qaytsin.** `context.pop()`
ishlating, `context.go()` emas. Prototipda bu xato edi: mosliklardan ochilgan
panel e'lon sahifasiga tashlab ketardi.

### 5.4 Mosliklar — `/matches`

**Ma'lumot:** `matchesProvider` → `List<TradeMatch>`

```
┌────────────────────────────────────────┐
│  ┌──────┐      ┌────┐      ┌──────┐   │
│  │ rasm │  ⇄   │76% │      │ rasm │   │
│  └──────┘      └────┘      └──────┘   │
│  SIZNIKI      moslik       ULARNIKI    │
│                                        │
│  Sizning 40 t guruch ↔ ularning MTZ-892│
│  Sardor Choriyev · Qiymatlar yaqin…    │ ← owner.name + reason
│                                        │
│  [  Taklif yuborish  ] [O'tkazish]     │
└────────────────────────────────────────┘
```

- Chapda `mine` (yashil ramka), o'ngda `theirs` (ko'k ramka), o'rtada ball.
- `owner` — **doim `theirs` egasi**, server hisoblab beradi.
- «Taklif yuborish» → `context.push('/offer/${match.theirs.id}')`.
- «O'tkazish» → `dismissMatch(match.id)` + `ref.invalidate(matchesProvider)`.
  Qaytib chiqmaydi.

### 5.5 Bildirishnomalar — `/notifications`

**Ma'lumot:** `notificationsProvider` → `List<AppNotification>`

`today` bo'yicha ikki guruh: **Bugun** / **Oldinroq** (`created_at` dan hisoblang).

⚠️ **Manzil `targetType` dan olinadi, `kind` dan emas:**

```dart
void follow(AppNotification n) {
  switch (n.targetType) {
    case NotifyTargetType.chat:         context.push('/chat/${n.targetId}');
    case NotifyTargetType.matches:      context.go('/matches');
    case NotifyTargetType.verification: context.push('/settings/verify');
    case NotifyTargetType.listing:      context.push('/listing/${n.targetId}');
  }
}
```

`kind` faqat ikonka/rang uchun:

| `kind` | Ikonka | Rang |
|---|---|---|
| `offer` | `swap_horiz` | give (yashil) |
| `match` | `auto_awesome` | money (oltin) |
| `message` | `forum` | take (ko'k) |
| `system` | `shield` | neytral |

«Hammasini o'qilgan qilish» → `markRead()` + `invalidate`.

### 5.6 Profil — `/profile`

**Ma'lumot:** `meProvider` → `Me?`, `myListingsProvider`

```
┌─ yashil fon ───────────────────────────┐
│ Profil                    [Sozlamalar] │
│ (avatar) Jasur Toshmatov ⓥ             │
│          Oq Yer Agro                   │ ← handle
│          ★4.7 · 2023 yil martdan       │
│ ISHONCH DARAJASI              92 / 100 │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░                   │
├────────────────────────────────────────┤
│    2         3          100%           │
│ Faol e'lon  Yakunlangan  Yakunlangan   │ ← BARCHASI serverdan
│             savdo        ulush          │
├────────────────────────────────────────┤
│ [E'lonlarim]  [Sharhlar]               │
│ (2 ustunli grid yoki sharhlar ro'yxati)│
├────────────────────────────────────────┤
│ Til            [UZ] [RU] [EN]          │
│ Xavfsizlik va tasdiqlash            ›  │
│ To'lov usullari                     ›  │
│ Yordam markazi                      ›  │
│ [Chiqish]                              │
└────────────────────────────────────────┘
```

⚠️ Statistika **hech qachon qattiq kodlanmaydi** — `me.activeListings`,
`me.completedTrades`, `me.completionRate`, `me.trustScore`.

**Til almashtirish** (hozir UI yo'q, mantiq tayyor):

```dart
await ref.read(sessionStoreProvider).setLocale('ru');
ref.invalidate(meProvider);
// MaterialApp.locale sessionStore dan o'qiydi — ilova o'zi qayta chiziladi
```

Bu bir vaqtda interfeys tilini **ham**, `Accept-Language` header'ini **ham**
o'zgartiradi.

### 5.7 Savdogar profili — `/trader/:id`

`traderProvider(id)`, `traderListingsProvider(id)`, `traderReviewsProvider(id)`.

Uch statistika: **Reyting · Yopilgan savdo · Yakunlangan ulush**
(`rating`, `deals`, `completionRate`).

⚠️ Sharhlar — faqat **shu odam haqida** yozilganlari. Server allaqachon
filtrlaydi, mijoz qo'shimcha hech nima qilmasin.

Pastda «Xabar yozish» tugmasi.

### 5.8 E'lon yaratish — `/create`

Eng murakkab forma. Ikki blok:

```
┌─ 1 · NIMA BERAMAN ────────── BERAMAN ──┐
│ [rasm] [rasm] [+ qo'shish]             │
│ Sarlavha    [UZ][RU][EN] ← 3 ta maydon │
│ Tavsif      [UZ][RU][EN]               │
│ Toifa (tag) [dropdown]                 │
│ Holati      [UZ][RU][EN]               │
│ Miqdori     [UZ][RU][EN]               │
│ Qiymat      [ 6 300 000 ] so'm         │
└────────────────────────────────────────┘
                   ⇅
┌─ 2 · NIMA OLMOQCHIMAN ─────── OLAMAN ──┐
│ Nimaga almashtirasiz [UZ][RU][EN]      │
│ + yana qo'shish                        │
│ [✓] Ustiga pul qo'sha olaman           │
└────────────────────────────────────────┘
         [ E'lonni joylash ]
```

⚠️ **Uch til ham majburiy.** Bittasi bo'sh bo'lsa server `422` qaytaradi.
Mijoz buni **jo'natishdan oldin** tekshirsin va `l.createLangHint` ni ko'rsatsin.

Til maydonlarini `TabBar` (UZ/RU/EN) bilan qilish qulay — uchta ustun emas.

```dart
await ref.read(tradeRepositoryProvider).createListing({
  'tag': 'agri',
  'title': {'uz': ..., 'ru': ..., 'en': ...},
  'description': {...}, 'image_alt': {...}, 'category': {...},
  'condition': {...}, 'quantity': {...}, 'wants_summary': {...},
  'wants': [ {'uz': ..., 'ru': ..., 'en': ...} ],
  'photos': ['https://...'],
  'value': {'minor': somInput * 100, 'currency': 'UZS'},
  'cash_ok': true,
});
```

**`402` javobi** = bepul e'lon kvotasi tugadi. Xato emas — tarif taklif qiladigan
ekran ko'rsating.

Rasm hozircha **URL** sifatida kiritiladi (yuklash servisi hali yo'q).

### 5.9 Tasdiqlash — `/settings/verify`

`verification()` → `trustScore` + `steps`.

Har bosqich: nomi, izohi, holati (`todo`/`pending`/`done`), vazni.
`todo` bo'lganlarida «Yuborish» tugmasi → `submitStep(step)`.

Yuqorida progress bar: `trustScore / 100`.

### 5.10 To'lovlar — `/settings/payments`

`cards()`, `makePrimary(id)`, `removeCard(id)`.

⚠️ `makePrimary` va `removeCard` **yangilangan to'liq ro'yxatni qaytaradi** —
qayta so'rov qilmang, javobni ishlating.

Pastda `/me/settlements` dan to'lovlar tarixi: `outgoing: true` → `−` qizil-neytral,
`false` → `+` yashil.

---

## 6. Navigatsiya — router'ga qo'shish

`core/router/app_router.dart` da:

```dart
GoRoute(
  path: '/chat/:id',
  parentNavigatorKey: _rootKey,        // tab bar ustidan yopiladi
  builder: (context, state) => ChatPage(threadId: state.pathParameters['id']!),
),
```

- **Tab ekranlari** (`/home`, `/matches`, `/inbox`, `/profile`) — `StatefulShellBranch` ichida.
- **Qolgan hammasi** — `parentNavigatorKey: _rootKey` bilan push route.
- `context.push` — stack'ga qo'shadi (orqaga qaytadi).
  `context.go` — stack'ni tozalaydi (faqat tab almashtirishda).

---

## 7. Tarjima qo'shish

1. `l10n/app_uz.arb` ga qo'shing (**asosiy fayl**):

```json
"chatAccept": "Qabul qilish"
```

2. `app_ru.arb` va `app_en.arb` ga ham.
3. `flutter gen-l10n`
4. `Text(l.chatAccept)`

Son bilan:

```json
"inboxUnread": "{count} ta o‘qilmagan",
"@inboxUnread": { "placeholders": { "count": { "type": "int" } } }
```

`@` tavsifi **faqat `app_uz.arb`** da bo'ladi.

⚠️ **Sana va pulni qo'lda yozmang:**

```dart
DateFormat.yMMMd(locale).format(listing.postedAt)   // ✅
listing.value.format(locale)                        // ✅
'${listing.value.minor / 100} so\'m'                // ❌
'2 kun oldin'                                       // ❌
```

---

## 8. Responsive — bitta breakpoint

`core/router/app_shell.dart` da `kRailBreakpoint = 700`:

- `< 700` → pastki `NavigationBar` + markazda FAB
- `≥ 700` → chapda `NavigationRail`, kontent `maxWidth: 720`

**Boshqa hech qayerda platforma tekshirilmasin.** `Platform.isIOS` yozishga
majbur bo'lsangiz — to'xtang, ehtimol `LayoutBuilder` yetadi.

Platformaga xos narsalar faqat uch joyda va allaqachon yozilgan:
`PageTransitionsTheme` (iOS surish), `defaultApiBaseUrl()` (Android `10.0.2.2`),
`usePathUrlStrategy()` (web URL).

Har bir ekranni **375px va 1280px** da sinang.

---

## 9. Tayyor bo'lganini qanday bilasiz

Har bir ekran uchun:

- [ ] To'rt holat bor: loading / error / empty / data
- [ ] Xato serverdan kelgan `detail` ni ko'rsatadi
- [ ] Barcha matn `l10n` dan, hech bir qattiq kodlangan satr yo'q
- [ ] Sana `DateFormat`, pul `Money.format` orqali
- [ ] `flutter analyze` → **0 muammo**
- [ ] 375px va 1280px da tekshirilgan
- [ ] Uch tilda ham to'g'ri ko'rinadi (kirillcha matn kesilib qolmaydi)
- [ ] Qorong'i temada ham o'qish mumkin

Butun ilova uchun:

- [ ] Kirish → e'lon yaratish → taklif → chat → yakunlash → sharh zanjiri ishlaydi
- [ ] `flutter build web`, `flutter build apk`, `flutter build ios` o'tadi

---

## 10. Muhim tuzoqlar

Bular prototipda haqiqatan yuz bergan xatolar. Takrorlamang.

| Tuzoq | To'g'ri yo'l |
|---|---|
| `owner.handle` ni ism o'rniga ko'rsatish | `"${name} · ${handle}"`, handle bo'lsa |
| Bildirishnoma manzilini `kind` dan taxmin qilish | `targetType` + `targetId` |
| Panelni `context.go` bilan yopish | `context.pop()` — kelgan joyga qaytadi |
| `"2 kun oldin"` ni qo'lda yozish | `DateFormat` |
| Pulni matn sifatida saqlash | `Money { minor, currency }` |
| Statistikani qattiq kodlash («37 ta savdo») | Serverdan: `me.completedTrades` |
| Sharhlarni o'zi filtrlash | Server allaqachon filtrlagan |
| Har chat uchun alohida WebSocket | Bitta `LiveChannel` |
| `counter` dan keyin `isMine` ni eski holda ishlatish | Javobdan keyin `invalidate` |

---

## 11. Keyingi bosqichda (hozir shart emas)

| Nima | Nega | Paket |
|---|---|---|
| Offline kesh | Internet yomon joyda lenta ko'rinsin | `drift` |
| Rasm siqish | Barterda rasm ko'p, 200 KB gacha | `flutter_image_compress` |
| Push bildirishnoma | Taklif kelganda darrov bilish | `firebase_messaging` |
| Cheksiz sahifalash | Hozir faqat birinchi 20 ta | `next_cursor` tayyor |
| Rasm yuklash | Hozir faqat URL | S3/MinIO backend'da |

---

## 12. Savol tug'ilsa

1. **API qanday javob beradi?** → [`API.md`](API.md) yoki
   `http://127.0.0.1:8010/docs` (sinab ko'rish mumkin)
2. **Biznes qoidasi qanday?** → [`DOMAIN.md`](DOMAIN.md)
3. **Backend qanday ishlaydi?** → [`BACKEND.md`](BACKEND.md)

Backend'ni **o'zgartirmang**. Biror narsa yetishmasa — talab qilib yozing,
backend tomoni qo'shadi.
