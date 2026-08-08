// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class LUz extends L {
  LUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'BarterApp';

  @override
  String get back => 'Orqaga';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get clear => 'Tozalash';

  @override
  String get introTitle1 => 'Sotmang — almashtiring';

  @override
  String get introBody1 =>
      '«Menda ortiqcha X bor, menga Y kerak.» Naqd pul topishning hojati yo‘q — tovar tovarga.';

  @override
  String get introTitle2 => 'Kerakli odamni o‘zimiz topamiz';

  @override
  String get introBody2 =>
      'Nima berayotganingizni va nima izlayotganingizni ayting. Qiymat, hudud va reyting bo‘yicha mos savdogarlarni ko‘rsatamiz.';

  @override
  String get introTitle3 => 'Ishonch bilan savdolashing';

  @override
  String get introBody3 =>
      'Tasdiqlangan profillar, haqiqiy sharhlar va kelishuv paneli. Har bir savdo ochiq kechadi.';

  @override
  String get introSkip => 'O‘tkazish';

  @override
  String get introNext => 'Keyingisi';

  @override
  String get introStart => 'Boshlash';

  @override
  String get navHome => 'Asosiy';

  @override
  String get navMatches => 'Mosliklar';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profil';

  @override
  String get navCreate => 'Barter e’lonini yaratish';

  @override
  String get navSettings => 'Sozlamalar';

  @override
  String get settingsGeneral => 'Umumiy';

  @override
  String get settingsSecurity => 'Xavfsizlik va to‘lovlar';

  @override
  String get feedTradingIn => 'Savdo hududi';

  @override
  String get feedSearchHint => 'Mahsulot, xizmat, texnika izlash…';

  @override
  String get feedHeading => 'Barterga tayyor';

  @override
  String feedNearby(int count) {
    return '$count ta yaqinda';
  }

  @override
  String feedResults(int count) {
    return '$count ta e’lon topildi';
  }

  @override
  String get feedEmpty => 'Hech narsa topilmadi';

  @override
  String get feedEmptyHint =>
      'Boshqa so‘z bilan qidirib ko‘ring yoki filtrni tozalang.';

  @override
  String get feedPremium => 'Premium';

  @override
  String get feedLookingFor => 'Kerak:';

  @override
  String get feedEstValue => 'taxminiy qiymat';

  @override
  String get feedPostedAt => 'Joylangan';

  @override
  String get feedNotifications => 'Bildirishnomalar';

  @override
  String get filterAll => 'Barchasi';

  @override
  String get filterAgri => 'Qishloq xo‘jaligi';

  @override
  String get filterLivestock => 'Chorva';

  @override
  String get filterMachinery => 'Texnika';

  @override
  String get filterTransport => 'Transport';

  @override
  String get filterElectronics => 'Elektronika';

  @override
  String get filterConstruction => 'Qurilish';

  @override
  String get listingGives => 'Egasi beradi';

  @override
  String get listingWants => 'Evaziga oladi';

  @override
  String get listingAbout => 'Tavsif';

  @override
  String get listingSpecs => 'Xususiyatlar';

  @override
  String get listingOwner => 'E’lon egasi';

  @override
  String get listingSimilar => 'O‘xshash e’lonlar';

  @override
  String get listingMessage => 'Yozish';

  @override
  String get listingOffer => 'Taklif yuborish';

  @override
  String get listingSave => 'Saqlash';

  @override
  String get listingSaved => 'Saqlandi';

  @override
  String get listingCashOk => 'Qo‘shimcha pulga rozi';

  @override
  String get listingCashNo => 'Faqat mol-mol almashuv';

  @override
  String get listingSafety =>
      'Mol-mulkni topshirishdan oldin ko‘rib oling. Qo‘shimcha pul escrow orqali o‘tsin.';

  @override
  String listingTrades(int count) {
    return '$count ta savdo';
  }

  @override
  String get specCategory => 'Toifa';

  @override
  String get specCondition => 'Holati';

  @override
  String get specQuantity => 'Miqdori';

  @override
  String get specPosted => 'E’lon berilgan';

  @override
  String get specLocation => 'Joylashuv';

  @override
  String get specValue => 'Taxminiy qiymat';

  @override
  String get authTitle => 'Telefon raqamingiz';

  @override
  String get authSubtitle => 'Kirish uchun SMS kod yuboramiz.';

  @override
  String get authPhoneLabel => 'Telefon raqam';

  @override
  String get authSendCode => 'Kod yuborish';

  @override
  String get authCodeTitle => 'Kodni kiriting';

  @override
  String authCodeSubtitle(String phone) {
    return '$phone raqamiga yuborilgan 6 xonali kod.';
  }

  @override
  String get authVerify => 'Tasdiqlash';

  @override
  String get authInvalidPhone => 'Raqamni +998 bilan to‘liq kiriting.';

  @override
  String get authSignedOut => 'Hisobga kirmagansiz';

  @override
  String get authSignIn => 'Kirish';

  @override
  String get authSignOut => 'Chiqish';

  @override
  String get authChangeNumber => 'Raqamni o‘zgartirish';

  @override
  String authOtpDebug(String code) {
    return 'SMS provayderi hali ulanmagan. Sinov kodi: $code';
  }

  @override
  String get authResend => 'Kodni qayta yuborish';

  @override
  String get profileSetupTitle => 'O‘zingiz haqingizda';

  @override
  String get profileEditTitle => 'Profilni tahrirlash';

  @override
  String get profileSetupLede =>
      'Ismingiz har bir e’lon va taklifda ko‘rinadi. Hudud esa yaqin savdogarlarni topishga yordam beradi.';

  @override
  String get profileFirstName => 'Ism';

  @override
  String get profileLastName => 'Familiya';

  @override
  String get profileHandle => 'Korxona nomi';

  @override
  String get profileHandleHint => 'Ixtiyoriy — biznes hisoblar uchun';

  @override
  String get profileRegion => 'Hudud';

  @override
  String get profileRegionHint =>
      'Hudud moslik balining 30% ini tashkil qiladi';

  @override
  String get profilePhoto => 'Surat';

  @override
  String get profilePhotoPick => 'Surat tanlash';

  @override
  String get profilePhotoChange => 'Suratni almashtirish';

  @override
  String get profileSave => 'Saqlash';

  @override
  String get profileRequired => 'Bu maydon to‘ldirilishi shart';

  @override
  String get uploading => 'Yuklanmoqda…';

  @override
  String get photoCamera => 'Kamera';

  @override
  String get photoGallery => 'Galereya';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileTrustLabel => 'Ishonch darajasi';

  @override
  String get profileStatActive => 'Faol e’lon';

  @override
  String get profileStatCompleted => 'Yakunlangan savdo';

  @override
  String get profileStatCompletion => 'Yakunlangan ulush';

  @override
  String get profileLanguage => 'Til';

  @override
  String get profileMyListings => 'E’lonlarim';

  @override
  String get profileReviews => 'Sharhlar';

  @override
  String get profileNoReviews => 'Hozircha sharhlar yo‘q.';

  @override
  String get traderVerified => 'Hujjatlari tasdiqlangan';

  @override
  String get traderUnverified => 'Tasdiqlanmagan hisob';

  @override
  String get traderListings => 'Faol e’lonlari';

  @override
  String get traderListingsEmpty => 'Hozircha faol e’lon yo‘q.';

  @override
  String get traderReviews => 'Sherik baholari';

  @override
  String get traderReviewsEmpty => 'Hozircha sherik baholari yo‘q.';

  @override
  String get traderMemberSince => 'A’zo bo‘lgan';

  @override
  String get traderRating => 'Reyting';

  @override
  String get traderDeals => 'Yopilgan savdo';

  @override
  String get traderCompletion => 'Yakunlangan ulush';

  @override
  String get traderMessage => 'Xabar yozish';

  @override
  String get traderOnline => 'Onlayn';

  @override
  String get errorNetwork => 'Serverga ulanib bo‘lmadi. Internetni tekshiring.';

  @override
  String get errorGeneric => 'Nimadir noto‘g‘ri ketdi.';

  @override
  String get comingSoon => 'Bu bo‘lim keyingi bosqichda ulanadi.';

  @override
  String get offerTitle => 'Savdo taklif qilish';

  @override
  String get offerYouWant => 'Sizga kerak';

  @override
  String get offerSelectItems => 'Taklif qilish uchun e’loningizni tanlang';

  @override
  String get offerAddCash => 'Pul qo‘shish';

  @override
  String get offerAddCashHint => 'savdoni tenglashtirish uchun';

  @override
  String get offerSend => 'Taklifni yuborish';

  @override
  String get offerNoItems => 'Avval o‘z e’loningizni joylang.';

  @override
  String get offerSent => 'Taklif yuborildi';

  @override
  String get inboxTitle => 'Xabarlar';

  @override
  String get inboxEmpty => 'Hozircha suhbat yo‘q.';

  @override
  String inboxUnread(int count) {
    return '$count ta o‘qilmagan';
  }

  @override
  String get chatPlaceholder => 'Xabar yozing…';

  @override
  String get chatSend => 'Yuborish';

  @override
  String get chatTyping => 'yozmoqda…';

  @override
  String get dealPending => 'Kutilayotgan savdo';

  @override
  String get dealAccept => 'Qabul qilish';

  @override
  String get dealDecline => 'Rad etish';

  @override
  String get dealCounter => 'Qarshi taklif';

  @override
  String get dealComplete => 'Savdoni yakunlash';

  @override
  String get dealCompleted => 'Savdo yakunlandi';

  @override
  String get dealDeclined => 'Rad etilgan';

  @override
  String get dealAccepted => 'Qabul qilingan';

  @override
  String get dealTalking => 'Muhokamada';

  @override
  String get dealExpired => 'Muddati tugagan';

  @override
  String get matchesTitle => 'Aqlli mosliklar';

  @override
  String get matchesLede =>
      'Sizning e’lonlaringiz va boshqalarning so‘rovlari o‘rtasidagi mosliklar.';

  @override
  String get matchesEmpty =>
      'Hozircha moslik yo‘q. E’lon joylasangiz paydo bo‘ladi.';

  @override
  String get matchesYours => 'Sizniki';

  @override
  String get matchesTheirs => 'Ularniki';

  @override
  String get matchesSkip => 'O‘tkazib yuborish';

  @override
  String get matchesOffer => 'Taklif yuborish';

  @override
  String get notificationsTitle => 'Bildirishnomalar';

  @override
  String get notificationsEmpty => 'Yangi bildirishnoma yo‘q.';

  @override
  String get notificationsMarkAll => 'Hammasini o‘qilgan qilish';

  @override
  String get createTitle => 'Barter yaratish';

  @override
  String get createGive => 'Nima beraman';

  @override
  String get createTake => 'Nima olmoqchiman';

  @override
  String get createFieldTitle => 'Sarlavha';

  @override
  String get createFieldDesc => 'Tavsif';

  @override
  String get createFieldCategory => 'Toifa';

  @override
  String get createFieldValue => 'Taxminiy qiymat';

  @override
  String get createFieldCondition => 'Holati';

  @override
  String get createFieldQuantity => 'Miqdori';

  @override
  String get createFieldWants => 'Nimaga almashtirasiz';

  @override
  String get createPhotos => 'Rasmlar (URL, har qatorda bittadan)';

  @override
  String get createPublish => 'E’lonni joylash';

  @override
  String get createLangHint =>
      'Uch tilda ham to‘ldiring — bittasi bo‘sh qolsa joylab bo‘lmaydi.';

  @override
  String get createRequired => 'Bu maydon bo‘sh bo‘lmasligi kerak';

  @override
  String get createPublished => 'E’lon joylandi';

  @override
  String get verifyTitle => 'Xavfsizlik va tasdiqlash';

  @override
  String get verifyLevel => 'Ishonch darajasi';

  @override
  String get verifySteps => 'Tasdiqlash bosqichlari';

  @override
  String get verifySubmit => 'Yuborish';

  @override
  String get verifyDone => 'Tasdiqlangan';

  @override
  String get verifyPending => 'Tekshiruvda';

  @override
  String get verifyTodo => 'Boshlanmagan';

  @override
  String get paymentsTitle => 'To‘lov usullari';

  @override
  String get paymentsPrimary => 'Asosiy';

  @override
  String get paymentsMakePrimary => 'Asosiy qilish';

  @override
  String get paymentsRemove => 'O‘chirish';

  @override
  String get paymentsHistory => 'Oxirgi to‘lovlar';

  @override
  String get paymentsEmpty => 'Hali to‘lov qilinmagan.';
}
