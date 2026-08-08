// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'BarterApp';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Try again';

  @override
  String get clear => 'Clear';

  @override
  String get introTitle1 => 'Don\'t sell — swap';

  @override
  String get introBody1 =>
      '\"I have spare X, I need Y.\" No cash to raise — goods for goods.';

  @override
  String get introTitle2 => 'We find the right person for you';

  @override
  String get introBody2 =>
      'Tell us what you\'re offering and what you\'re after. We\'ll show traders that fit on value, region and rating.';

  @override
  String get introTitle3 => 'Trade with confidence';

  @override
  String get introBody3 =>
      'Verified profiles, real reviews and a deal panel. Every swap stays in the open.';

  @override
  String get introSkip => 'Skip';

  @override
  String get introNext => 'Next';

  @override
  String get introStart => 'Get started';

  @override
  String get navHome => 'Home';

  @override
  String get navMatches => 'Matches';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get navCreate => 'Create a barter listing';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSecurity => 'Security and payments';

  @override
  String get feedTradingIn => 'Trading in';

  @override
  String get feedSearchHint => 'Search goods, services, machinery…';

  @override
  String get feedHeading => 'Open for barter';

  @override
  String feedNearby(int count) {
    return '$count nearby';
  }

  @override
  String feedResults(int count) {
    return '$count listings found';
  }

  @override
  String get feedEmpty => 'Nothing found';

  @override
  String get feedEmptyHint => 'Try another word or clear the filter.';

  @override
  String get feedPremium => 'Premium';

  @override
  String get feedLookingFor => 'Looking for:';

  @override
  String get feedEstValue => 'est. value';

  @override
  String get feedRegionAny => 'All of Uzbekistan';

  @override
  String get feedCategories => 'What are you looking for?';

  @override
  String get feedLoadMore => 'Load more';

  @override
  String get feedEnd => 'That\'s everything';

  @override
  String get feedPostedAt => 'Posted';

  @override
  String get feedNotifications => 'Notifications';

  @override
  String get filterAll => 'All';

  @override
  String get filterAgri => 'Agriculture';

  @override
  String get filterLivestock => 'Livestock';

  @override
  String get filterMachinery => 'Machinery';

  @override
  String get filterTransport => 'Transport';

  @override
  String get filterElectronics => 'Electronics';

  @override
  String get filterConstruction => 'Construction';

  @override
  String get listingGives => 'Owner gives';

  @override
  String get listingWants => 'Wants in return';

  @override
  String get listingAbout => 'Description';

  @override
  String get listingSpecs => 'Details';

  @override
  String get listingOwner => 'Listed by';

  @override
  String get listingSimilar => 'Similar listings';

  @override
  String get listingMessage => 'Message';

  @override
  String get listingOffer => 'Send an offer';

  @override
  String get listingSave => 'Save';

  @override
  String get listingSaved => 'Saved';

  @override
  String get listingCashOk => 'Open to added cash';

  @override
  String get listingCashNo => 'Goods-for-goods only';

  @override
  String get listingSafety =>
      'Inspect the goods before hand-over and route any added cash through escrow.';

  @override
  String listingTrades(int count) {
    return '$count trades';
  }

  @override
  String get specCategory => 'Category';

  @override
  String get specCondition => 'Condition';

  @override
  String get specQuantity => 'Quantity';

  @override
  String get specPosted => 'Posted';

  @override
  String get specLocation => 'Location';

  @override
  String get specValue => 'Estimated value';

  @override
  String get authTitle => 'Your phone number';

  @override
  String get authSubtitle => 'We will send an SMS code to sign you in.';

  @override
  String get authPhoneLabel => 'Phone number';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authCodeTitle => 'Enter the code';

  @override
  String authCodeSubtitle(String phone) {
    return 'The 6-digit code sent to $phone.';
  }

  @override
  String get authVerify => 'Verify';

  @override
  String get authInvalidPhone => 'Enter the full number starting with +998.';

  @override
  String get authSignedOut => 'You are not signed in';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authChangeNumber => 'Change number';

  @override
  String authOtpDebug(String code) {
    return 'No SMS provider yet. Test code: $code';
  }

  @override
  String get authResend => 'Send the code again';

  @override
  String get profileSetupTitle => 'About you';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileSetupLede =>
      'Your name appears on every listing and offer. Your region helps us find traders nearby.';

  @override
  String get profileFirstName => 'First name';

  @override
  String get profileLastName => 'Last name';

  @override
  String get profileHandle => 'Company name';

  @override
  String get profileHandleHint => 'Optional — for business accounts';

  @override
  String get profileRegion => 'Region';

  @override
  String get profileRegionHint => 'Region is 30% of a match score';

  @override
  String get profilePhoto => 'Photo';

  @override
  String get profilePhotoPick => 'Choose a photo';

  @override
  String get profilePhotoChange => 'Replace photo';

  @override
  String get profileSave => 'Save';

  @override
  String get profileRequired => 'This field is required';

  @override
  String get uploading => 'Uploading…';

  @override
  String get photoCamera => 'Camera';

  @override
  String get photoGallery => 'Gallery';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileTrustLabel => 'Trust level';

  @override
  String get profileStatActive => 'Active listings';

  @override
  String get profileStatCompleted => 'Completed trades';

  @override
  String get profileStatCompletion => 'Completion rate';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileMyListings => 'My listings';

  @override
  String get profileReviews => 'Reviews';

  @override
  String get profileNoReviews => 'No reviews yet.';

  @override
  String get traderVerified => 'Documents verified';

  @override
  String get traderUnverified => 'Unverified account';

  @override
  String get traderListings => 'Active listings';

  @override
  String get traderListingsEmpty => 'No active listings right now.';

  @override
  String get traderReviews => 'Partner reviews';

  @override
  String get traderReviewsEmpty => 'No partner reviews yet.';

  @override
  String get traderMemberSince => 'Member since';

  @override
  String get traderRating => 'Rating';

  @override
  String get traderDeals => 'Deals closed';

  @override
  String get traderCompletion => 'Completion rate';

  @override
  String get traderMessage => 'Send a message';

  @override
  String get traderOnline => 'Online';

  @override
  String get errorNetwork =>
      'Could not reach the server. Check your connection.';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get comingSoon => 'This section arrives in the next milestone.';

  @override
  String get offerTitle => 'Propose a trade';

  @override
  String get offerYouWant => 'You want';

  @override
  String get offerSelectItems => 'Choose one of your listings to offer';

  @override
  String get offerAddCash => 'Add cash';

  @override
  String get offerAddCashHint => 'to even out the trade';

  @override
  String get offerSend => 'Send offer';

  @override
  String get offerNoItems => 'Publish a listing of your own first.';

  @override
  String get offerSent => 'Offer sent';

  @override
  String get offerMessage => 'Message';

  @override
  String get offerMessageHint => 'Add a note to your offer — optional';

  @override
  String get offerYouGive => 'You give';

  @override
  String get offerCreateFirst => 'Post a listing first';

  @override
  String get confirmRemoveCard => 'Remove this card?';

  @override
  String get notFound => 'Not found';

  @override
  String get inboxTitle => 'Messages';

  @override
  String get inboxEmpty => 'No conversations yet.';

  @override
  String inboxUnread(int count) {
    return '$count unread';
  }

  @override
  String get chatPlaceholder => 'Write a message…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatTyping => 'typing…';

  @override
  String chatExpiresIn(int hours) {
    return 'Expires in ${hours}h';
  }

  @override
  String get chatExpiresSoon => 'Less than an hour left';

  @override
  String get dealCounterTitle => 'Counter-offer';

  @override
  String get dealCounterCash => 'Cash on top';

  @override
  String get dealCounterSend => 'Send counter-offer';

  @override
  String get dealCounterHint =>
      'Once sent, it is the other side\'s turn to answer.';

  @override
  String get dealYouGive => 'You give';

  @override
  String get dealYouGet => 'You get';

  @override
  String get dealPending => 'Pending deal';

  @override
  String get dealAccept => 'Accept';

  @override
  String get dealDecline => 'Decline';

  @override
  String get dealCounter => 'Counter offer';

  @override
  String get dealComplete => 'Complete the trade';

  @override
  String get dealCompleted => 'Trade completed';

  @override
  String get reviewTitle => 'How did the trade go?';

  @override
  String reviewLede(String name) {
    return 'Your trade with $name is done. Your review is what lets the next person trust them.';
  }

  @override
  String get reviewBody => 'What would you say?';

  @override
  String get reviewSend => 'Leave a review';

  @override
  String get reviewLater => 'Later';

  @override
  String get reviewThanks => 'Thanks for the review';

  @override
  String get reviewDone => 'You left a review';

  @override
  String get dealDeclined => 'Declined';

  @override
  String get dealAccepted => 'Accepted';

  @override
  String get dealTalking => 'Talking';

  @override
  String get dealExpired => 'Expired';

  @override
  String get matchesTitle => 'Smart matches';

  @override
  String get matchesLede =>
      'Fits found between your listings and what others are asking for.';

  @override
  String get matchesEmpty =>
      'No matches yet. They appear once you publish a listing.';

  @override
  String get matchesYours => 'Yours';

  @override
  String get matchesTheirs => 'Theirs';

  @override
  String get matchesSkip => 'Skip';

  @override
  String get matchesOffer => 'Make offer';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Nothing new right now.';

  @override
  String get notificationsMarkAll => 'Mark all as read';

  @override
  String get createTitle => 'Create barter';

  @override
  String get createGive => 'What I offer';

  @override
  String get createTake => 'What I want in return';

  @override
  String get createFieldTitle => 'Title';

  @override
  String get createFieldDesc => 'Description';

  @override
  String get createFieldCategory => 'Category';

  @override
  String get createFieldValue => 'Estimated value';

  @override
  String get createFieldCondition => 'Condition';

  @override
  String get createFieldQuantity => 'Quantity';

  @override
  String get createFieldWants => 'What you will accept';

  @override
  String get createPhotos => 'Photos (URL, one per line)';

  @override
  String get createPublish => 'Publish listing';

  @override
  String get createLangHint =>
      'Fill in all three languages — a listing cannot go up with one missing.';

  @override
  String get createRequired => 'This field cannot be empty';

  @override
  String get createPublished => 'Listing published';

  @override
  String get createStepPhotos => 'Photos';

  @override
  String get createStepGive => 'What are you offering?';

  @override
  String get createStepTake => 'What do you need?';

  @override
  String get createStepValue => 'Value';

  @override
  String get createNext => 'Next';

  @override
  String get createBack => 'Back';

  @override
  String get createPhotosHint =>
      'The first photo is the one the feed shows. At least one is needed.';

  @override
  String get createGiveHint =>
      'Fill in all three languages — so a Russian reader does not meet a broken app.';

  @override
  String get createTakeHint =>
      'What do you want in return? This is what finds your matches.';

  @override
  String get createValueHint =>
      'An estimated value is how equal swaps find each other.';

  @override
  String get createFieldDescription => 'Description';

  @override
  String get createFieldTag => 'Section';

  @override
  String get createWantCategory => 'From which section?';

  @override
  String get createWantAny => 'Doesn\'t matter';

  @override
  String get createCashAdd => 'I can add cash';

  @override
  String get createCashWant => 'I need cash on top';

  @override
  String get createQuotaTitle => 'Free listings used up';

  @override
  String get createQuotaBody =>
      'Choose a plan or switch to a business account to continue.';

  @override
  String get createQuotaOk => 'Got it';

  @override
  String get verifyTitle => 'Safety & verification';

  @override
  String get verifyLevel => 'Trust level';

  @override
  String get verifySteps => 'Verification steps';

  @override
  String get verifySubmit => 'Submit';

  @override
  String get verifyDone => 'Verified';

  @override
  String get verifyPending => 'In review';

  @override
  String get verifyTodo => 'Not started';

  @override
  String get paymentsTitle => 'Payment methods';

  @override
  String get paymentsPrimary => 'Primary';

  @override
  String get paymentsMakePrimary => 'Make primary';

  @override
  String get paymentsRemove => 'Remove';

  @override
  String get paymentsHistory => 'Recent settlements';

  @override
  String get paymentsEmpty => 'No settlements yet.';
}
