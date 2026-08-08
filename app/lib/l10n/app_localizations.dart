import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appName.
  ///
  /// In uz, this message translates to:
  /// **'BarterApp'**
  String get appName;

  /// No description provided for @back.
  ///
  /// In uz, this message translates to:
  /// **'Orqaga'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get retry;

  /// No description provided for @clear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get clear;

  /// No description provided for @introTitle1.
  ///
  /// In uz, this message translates to:
  /// **'Sotmang — almashtiring'**
  String get introTitle1;

  /// No description provided for @introBody1.
  ///
  /// In uz, this message translates to:
  /// **'«Menda ortiqcha X bor, menga Y kerak.» Naqd pul topishning hojati yo‘q — tovar tovarga.'**
  String get introBody1;

  /// No description provided for @introTitle2.
  ///
  /// In uz, this message translates to:
  /// **'Kerakli odamni o‘zimiz topamiz'**
  String get introTitle2;

  /// No description provided for @introBody2.
  ///
  /// In uz, this message translates to:
  /// **'Nima berayotganingizni va nima izlayotganingizni ayting. Qiymat, hudud va reyting bo‘yicha mos savdogarlarni ko‘rsatamiz.'**
  String get introBody2;

  /// No description provided for @introTitle3.
  ///
  /// In uz, this message translates to:
  /// **'Ishonch bilan savdolashing'**
  String get introTitle3;

  /// No description provided for @introBody3.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan profillar, haqiqiy sharhlar va kelishuv paneli. Har bir savdo ochiq kechadi.'**
  String get introBody3;

  /// No description provided for @introSkip.
  ///
  /// In uz, this message translates to:
  /// **'O‘tkazish'**
  String get introSkip;

  /// No description provided for @introNext.
  ///
  /// In uz, this message translates to:
  /// **'Keyingisi'**
  String get introNext;

  /// No description provided for @introStart.
  ///
  /// In uz, this message translates to:
  /// **'Boshlash'**
  String get introStart;

  /// No description provided for @navHome.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy'**
  String get navHome;

  /// No description provided for @navMatches.
  ///
  /// In uz, this message translates to:
  /// **'Mosliklar'**
  String get navMatches;

  /// No description provided for @navChat.
  ///
  /// In uz, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @navCreate.
  ///
  /// In uz, this message translates to:
  /// **'Barter e’lonini yaratish'**
  String get navCreate;

  /// No description provided for @navSettings.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar'**
  String get navSettings;

  /// No description provided for @settingsGeneral.
  ///
  /// In uz, this message translates to:
  /// **'Umumiy'**
  String get settingsGeneral;

  /// No description provided for @settingsSecurity.
  ///
  /// In uz, this message translates to:
  /// **'Xavfsizlik va to‘lovlar'**
  String get settingsSecurity;

  /// No description provided for @feedTradingIn.
  ///
  /// In uz, this message translates to:
  /// **'Savdo hududi'**
  String get feedTradingIn;

  /// No description provided for @feedSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot, xizmat, texnika izlash…'**
  String get feedSearchHint;

  /// No description provided for @feedHeading.
  ///
  /// In uz, this message translates to:
  /// **'Barterga tayyor'**
  String get feedHeading;

  /// No description provided for @feedNearby.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta yaqinda'**
  String feedNearby(int count);

  /// No description provided for @feedResults.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta e’lon topildi'**
  String feedResults(int count);

  /// No description provided for @feedEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get feedEmpty;

  /// No description provided for @feedEmptyHint.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa so‘z bilan qidirib ko‘ring yoki filtrni tozalang.'**
  String get feedEmptyHint;

  /// No description provided for @feedPremium.
  ///
  /// In uz, this message translates to:
  /// **'Premium'**
  String get feedPremium;

  /// No description provided for @feedLookingFor.
  ///
  /// In uz, this message translates to:
  /// **'Kerak:'**
  String get feedLookingFor;

  /// No description provided for @feedEstValue.
  ///
  /// In uz, this message translates to:
  /// **'taxminiy qiymat'**
  String get feedEstValue;

  /// No description provided for @feedPostedAt.
  ///
  /// In uz, this message translates to:
  /// **'Joylangan'**
  String get feedPostedAt;

  /// No description provided for @feedNotifications.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get feedNotifications;

  /// No description provided for @filterAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get filterAll;

  /// No description provided for @filterAgri.
  ///
  /// In uz, this message translates to:
  /// **'Qishloq xo‘jaligi'**
  String get filterAgri;

  /// No description provided for @filterLivestock.
  ///
  /// In uz, this message translates to:
  /// **'Chorva'**
  String get filterLivestock;

  /// No description provided for @filterMachinery.
  ///
  /// In uz, this message translates to:
  /// **'Texnika'**
  String get filterMachinery;

  /// No description provided for @filterTransport.
  ///
  /// In uz, this message translates to:
  /// **'Transport'**
  String get filterTransport;

  /// No description provided for @filterElectronics.
  ///
  /// In uz, this message translates to:
  /// **'Elektronika'**
  String get filterElectronics;

  /// No description provided for @filterConstruction.
  ///
  /// In uz, this message translates to:
  /// **'Qurilish'**
  String get filterConstruction;

  /// No description provided for @listingGives.
  ///
  /// In uz, this message translates to:
  /// **'Egasi beradi'**
  String get listingGives;

  /// No description provided for @listingWants.
  ///
  /// In uz, this message translates to:
  /// **'Evaziga oladi'**
  String get listingWants;

  /// No description provided for @listingAbout.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif'**
  String get listingAbout;

  /// No description provided for @listingSpecs.
  ///
  /// In uz, this message translates to:
  /// **'Xususiyatlar'**
  String get listingSpecs;

  /// No description provided for @listingOwner.
  ///
  /// In uz, this message translates to:
  /// **'E’lon egasi'**
  String get listingOwner;

  /// No description provided for @listingSimilar.
  ///
  /// In uz, this message translates to:
  /// **'O‘xshash e’lonlar'**
  String get listingSimilar;

  /// No description provided for @listingMessage.
  ///
  /// In uz, this message translates to:
  /// **'Yozish'**
  String get listingMessage;

  /// No description provided for @listingOffer.
  ///
  /// In uz, this message translates to:
  /// **'Taklif yuborish'**
  String get listingOffer;

  /// No description provided for @listingSave.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get listingSave;

  /// No description provided for @listingSaved.
  ///
  /// In uz, this message translates to:
  /// **'Saqlandi'**
  String get listingSaved;

  /// No description provided for @listingCashOk.
  ///
  /// In uz, this message translates to:
  /// **'Qo‘shimcha pulga rozi'**
  String get listingCashOk;

  /// No description provided for @listingCashNo.
  ///
  /// In uz, this message translates to:
  /// **'Faqat mol-mol almashuv'**
  String get listingCashNo;

  /// No description provided for @listingSafety.
  ///
  /// In uz, this message translates to:
  /// **'Mol-mulkni topshirishdan oldin ko‘rib oling. Qo‘shimcha pul escrow orqali o‘tsin.'**
  String get listingSafety;

  /// No description provided for @listingTrades.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta savdo'**
  String listingTrades(int count);

  /// No description provided for @specCategory.
  ///
  /// In uz, this message translates to:
  /// **'Toifa'**
  String get specCategory;

  /// No description provided for @specCondition.
  ///
  /// In uz, this message translates to:
  /// **'Holati'**
  String get specCondition;

  /// No description provided for @specQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Miqdori'**
  String get specQuantity;

  /// No description provided for @specPosted.
  ///
  /// In uz, this message translates to:
  /// **'E’lon berilgan'**
  String get specPosted;

  /// No description provided for @specLocation.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuv'**
  String get specLocation;

  /// No description provided for @specValue.
  ///
  /// In uz, this message translates to:
  /// **'Taxminiy qiymat'**
  String get specValue;

  /// No description provided for @authTitle.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamingiz'**
  String get authTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Kirish uchun SMS kod yuboramiz.'**
  String get authSubtitle;

  /// No description provided for @authPhoneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqam'**
  String get authPhoneLabel;

  /// No description provided for @authSendCode.
  ///
  /// In uz, this message translates to:
  /// **'Kod yuborish'**
  String get authSendCode;

  /// No description provided for @authCodeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kodni kiriting'**
  String get authCodeTitle;

  /// No description provided for @authCodeSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{phone} raqamiga yuborilgan 6 xonali kod.'**
  String authCodeSubtitle(String phone);

  /// No description provided for @authVerify.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get authVerify;

  /// No description provided for @authInvalidPhone.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni +998 bilan to‘liq kiriting.'**
  String get authInvalidPhone;

  /// No description provided for @authSignedOut.
  ///
  /// In uz, this message translates to:
  /// **'Hisobga kirmagansiz'**
  String get authSignedOut;

  /// No description provided for @authSignIn.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get authSignIn;

  /// No description provided for @authSignOut.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get authSignOut;

  /// No description provided for @authChangeNumber.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni o‘zgartirish'**
  String get authChangeNumber;

  /// No description provided for @authOtpDebug.
  ///
  /// In uz, this message translates to:
  /// **'SMS provayderi hali ulanmagan. Sinov kodi: {code}'**
  String authOtpDebug(String code);

  /// No description provided for @authResend.
  ///
  /// In uz, this message translates to:
  /// **'Kodni qayta yuborish'**
  String get authResend;

  /// No description provided for @profileTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileTrustLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ishonch darajasi'**
  String get profileTrustLabel;

  /// No description provided for @profileStatActive.
  ///
  /// In uz, this message translates to:
  /// **'Faol e’lon'**
  String get profileStatActive;

  /// No description provided for @profileStatCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan savdo'**
  String get profileStatCompleted;

  /// No description provided for @profileStatCompletion.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan ulush'**
  String get profileStatCompletion;

  /// No description provided for @profileLanguage.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get profileLanguage;

  /// No description provided for @profileMyListings.
  ///
  /// In uz, this message translates to:
  /// **'E’lonlarim'**
  String get profileMyListings;

  /// No description provided for @profileReviews.
  ///
  /// In uz, this message translates to:
  /// **'Sharhlar'**
  String get profileReviews;

  /// No description provided for @profileNoReviews.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha sharhlar yo‘q.'**
  String get profileNoReviews;

  /// No description provided for @traderVerified.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlari tasdiqlangan'**
  String get traderVerified;

  /// No description provided for @traderUnverified.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlanmagan hisob'**
  String get traderUnverified;

  /// No description provided for @traderListings.
  ///
  /// In uz, this message translates to:
  /// **'Faol e’lonlari'**
  String get traderListings;

  /// No description provided for @traderListingsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha faol e’lon yo‘q.'**
  String get traderListingsEmpty;

  /// No description provided for @traderReviews.
  ///
  /// In uz, this message translates to:
  /// **'Sherik baholari'**
  String get traderReviews;

  /// No description provided for @traderReviewsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha sherik baholari yo‘q.'**
  String get traderReviewsEmpty;

  /// No description provided for @traderMemberSince.
  ///
  /// In uz, this message translates to:
  /// **'A’zo bo‘lgan'**
  String get traderMemberSince;

  /// No description provided for @traderRating.
  ///
  /// In uz, this message translates to:
  /// **'Reyting'**
  String get traderRating;

  /// No description provided for @traderDeals.
  ///
  /// In uz, this message translates to:
  /// **'Yopilgan savdo'**
  String get traderDeals;

  /// No description provided for @traderCompletion.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan ulush'**
  String get traderCompletion;

  /// No description provided for @traderMessage.
  ///
  /// In uz, this message translates to:
  /// **'Xabar yozish'**
  String get traderMessage;

  /// No description provided for @traderOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn'**
  String get traderOnline;

  /// No description provided for @errorNetwork.
  ///
  /// In uz, this message translates to:
  /// **'Serverga ulanib bo‘lmadi. Internetni tekshiring.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In uz, this message translates to:
  /// **'Nimadir noto‘g‘ri ketdi.'**
  String get errorGeneric;

  /// No description provided for @comingSoon.
  ///
  /// In uz, this message translates to:
  /// **'Bu bo‘lim keyingi bosqichda ulanadi.'**
  String get comingSoon;

  /// No description provided for @offerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savdo taklif qilish'**
  String get offerTitle;

  /// No description provided for @offerYouWant.
  ///
  /// In uz, this message translates to:
  /// **'Sizga kerak'**
  String get offerYouWant;

  /// No description provided for @offerSelectItems.
  ///
  /// In uz, this message translates to:
  /// **'Taklif qilish uchun e’loningizni tanlang'**
  String get offerSelectItems;

  /// No description provided for @offerAddCash.
  ///
  /// In uz, this message translates to:
  /// **'Pul qo‘shish'**
  String get offerAddCash;

  /// No description provided for @offerAddCashHint.
  ///
  /// In uz, this message translates to:
  /// **'savdoni tenglashtirish uchun'**
  String get offerAddCashHint;

  /// No description provided for @offerSend.
  ///
  /// In uz, this message translates to:
  /// **'Taklifni yuborish'**
  String get offerSend;

  /// No description provided for @offerNoItems.
  ///
  /// In uz, this message translates to:
  /// **'Avval o‘z e’loningizni joylang.'**
  String get offerNoItems;

  /// No description provided for @offerSent.
  ///
  /// In uz, this message translates to:
  /// **'Taklif yuborildi'**
  String get offerSent;

  /// No description provided for @inboxTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xabarlar'**
  String get inboxTitle;

  /// No description provided for @inboxEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha suhbat yo‘q.'**
  String get inboxEmpty;

  /// No description provided for @inboxUnread.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta o‘qilmagan'**
  String inboxUnread(int count);

  /// No description provided for @chatPlaceholder.
  ///
  /// In uz, this message translates to:
  /// **'Xabar yozing…'**
  String get chatPlaceholder;

  /// No description provided for @chatSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get chatSend;

  /// No description provided for @chatTyping.
  ///
  /// In uz, this message translates to:
  /// **'yozmoqda…'**
  String get chatTyping;

  /// No description provided for @dealPending.
  ///
  /// In uz, this message translates to:
  /// **'Kutilayotgan savdo'**
  String get dealPending;

  /// No description provided for @dealAccept.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish'**
  String get dealAccept;

  /// No description provided for @dealDecline.
  ///
  /// In uz, this message translates to:
  /// **'Rad etish'**
  String get dealDecline;

  /// No description provided for @dealCounter.
  ///
  /// In uz, this message translates to:
  /// **'Qarshi taklif'**
  String get dealCounter;

  /// No description provided for @dealComplete.
  ///
  /// In uz, this message translates to:
  /// **'Savdoni yakunlash'**
  String get dealComplete;

  /// No description provided for @dealCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Savdo yakunlandi'**
  String get dealCompleted;

  /// No description provided for @dealDeclined.
  ///
  /// In uz, this message translates to:
  /// **'Rad etilgan'**
  String get dealDeclined;

  /// No description provided for @dealAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilingan'**
  String get dealAccepted;

  /// No description provided for @dealTalking.
  ///
  /// In uz, this message translates to:
  /// **'Muhokamada'**
  String get dealTalking;

  /// No description provided for @dealExpired.
  ///
  /// In uz, this message translates to:
  /// **'Muddati tugagan'**
  String get dealExpired;

  /// No description provided for @matchesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Aqlli mosliklar'**
  String get matchesTitle;

  /// No description provided for @matchesLede.
  ///
  /// In uz, this message translates to:
  /// **'Sizning e’lonlaringiz va boshqalarning so‘rovlari o‘rtasidagi mosliklar.'**
  String get matchesLede;

  /// No description provided for @matchesEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha moslik yo‘q. E’lon joylasangiz paydo bo‘ladi.'**
  String get matchesEmpty;

  /// No description provided for @matchesYours.
  ///
  /// In uz, this message translates to:
  /// **'Sizniki'**
  String get matchesYours;

  /// No description provided for @matchesTheirs.
  ///
  /// In uz, this message translates to:
  /// **'Ularniki'**
  String get matchesTheirs;

  /// No description provided for @matchesSkip.
  ///
  /// In uz, this message translates to:
  /// **'O‘tkazib yuborish'**
  String get matchesSkip;

  /// No description provided for @matchesOffer.
  ///
  /// In uz, this message translates to:
  /// **'Taklif yuborish'**
  String get matchesOffer;

  /// No description provided for @notificationsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Yangi bildirishnoma yo‘q.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAll.
  ///
  /// In uz, this message translates to:
  /// **'Hammasini o‘qilgan qilish'**
  String get notificationsMarkAll;

  /// No description provided for @createTitle.
  ///
  /// In uz, this message translates to:
  /// **'Barter yaratish'**
  String get createTitle;

  /// No description provided for @createGive.
  ///
  /// In uz, this message translates to:
  /// **'Nima beraman'**
  String get createGive;

  /// No description provided for @createTake.
  ///
  /// In uz, this message translates to:
  /// **'Nima olmoqchiman'**
  String get createTake;

  /// No description provided for @createFieldTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sarlavha'**
  String get createFieldTitle;

  /// No description provided for @createFieldDesc.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif'**
  String get createFieldDesc;

  /// No description provided for @createFieldCategory.
  ///
  /// In uz, this message translates to:
  /// **'Toifa'**
  String get createFieldCategory;

  /// No description provided for @createFieldValue.
  ///
  /// In uz, this message translates to:
  /// **'Taxminiy qiymat'**
  String get createFieldValue;

  /// No description provided for @createFieldCondition.
  ///
  /// In uz, this message translates to:
  /// **'Holati'**
  String get createFieldCondition;

  /// No description provided for @createFieldQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Miqdori'**
  String get createFieldQuantity;

  /// No description provided for @createFieldWants.
  ///
  /// In uz, this message translates to:
  /// **'Nimaga almashtirasiz'**
  String get createFieldWants;

  /// No description provided for @createPhotos.
  ///
  /// In uz, this message translates to:
  /// **'Rasmlar (URL, har qatorda bittadan)'**
  String get createPhotos;

  /// No description provided for @createPublish.
  ///
  /// In uz, this message translates to:
  /// **'E’lonni joylash'**
  String get createPublish;

  /// No description provided for @createLangHint.
  ///
  /// In uz, this message translates to:
  /// **'Uch tilda ham to‘ldiring — bittasi bo‘sh qolsa joylab bo‘lmaydi.'**
  String get createLangHint;

  /// No description provided for @createRequired.
  ///
  /// In uz, this message translates to:
  /// **'Bu maydon bo‘sh bo‘lmasligi kerak'**
  String get createRequired;

  /// No description provided for @createPublished.
  ///
  /// In uz, this message translates to:
  /// **'E’lon joylandi'**
  String get createPublished;

  /// No description provided for @verifyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xavfsizlik va tasdiqlash'**
  String get verifyTitle;

  /// No description provided for @verifyLevel.
  ///
  /// In uz, this message translates to:
  /// **'Ishonch darajasi'**
  String get verifyLevel;

  /// No description provided for @verifySteps.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash bosqichlari'**
  String get verifySteps;

  /// No description provided for @verifySubmit.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get verifySubmit;

  /// No description provided for @verifyDone.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan'**
  String get verifyDone;

  /// No description provided for @verifyPending.
  ///
  /// In uz, this message translates to:
  /// **'Tekshiruvda'**
  String get verifyPending;

  /// No description provided for @verifyTodo.
  ///
  /// In uz, this message translates to:
  /// **'Boshlanmagan'**
  String get verifyTodo;

  /// No description provided for @paymentsTitle.
  ///
  /// In uz, this message translates to:
  /// **'To‘lov usullari'**
  String get paymentsTitle;

  /// No description provided for @paymentsPrimary.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy'**
  String get paymentsPrimary;

  /// No description provided for @paymentsMakePrimary.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy qilish'**
  String get paymentsMakePrimary;

  /// No description provided for @paymentsRemove.
  ///
  /// In uz, this message translates to:
  /// **'O‘chirish'**
  String get paymentsRemove;

  /// No description provided for @paymentsHistory.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi to‘lovlar'**
  String get paymentsHistory;

  /// No description provided for @paymentsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali to‘lov qilinmagan.'**
  String get paymentsEmpty;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'ru':
      return LRu();
    case 'uz':
      return LUz();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
