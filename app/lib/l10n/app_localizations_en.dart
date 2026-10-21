// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MAB';

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
  String get bannerVerifyTitle => 'Raise your trust score';

  @override
  String get bannerVerifyBody =>
      'A verified profile gets twice as many replies to an offer.';

  @override
  String get bannerVerifyAction => 'Get verified';

  @override
  String get bannerCreateTitle => 'Something spare at home?';

  @override
  String get bannerCreateBody =>
      'Post a listing — we\'ll find the traders that fit.';

  @override
  String get bannerCreateAction => 'Post a listing';

  @override
  String get bannerDismiss => 'Dismiss';

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
  String get authChangePhone => 'Change number';

  @override
  String get authResend => 'Send the code again';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get splashTagline => 'Trade. Trust.';

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
  String get authWithApple => 'Continue with Apple';

  @override
  String get authWithGoogle => 'Continue with Google';

  @override
  String get authWithFacebook => 'Continue with Facebook';

  @override
  String get authOrPhone => 'Or use your phone number';

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
  String get matchesScore => 'match';

  @override
  String get matchesEmptyHint =>
      'Post a listing — we\'ll find the traders that fit.';

  @override
  String get matchesCreate => 'Post a listing';

  @override
  String get inboxEmptyHint =>
      'A conversation starts with an offer. Send one on a listing you like.';

  @override
  String get inboxPickThread => 'Pick a conversation on the left.';

  @override
  String get inboxSignIn => 'Sign in to see your conversations.';

  @override
  String get accountSignIn =>
      'This section belongs to your account. Sign in to continue.';

  @override
  String get matchesSignIn =>
      'Matches are found from your own listings — sign in first.';

  @override
  String get agoNow => 'now';

  @override
  String agoMinutes(int count) {
    return '${count}m';
  }

  @override
  String agoHours(int count) {
    return '${count}h';
  }

  @override
  String agoDays(int count) {
    return '${count}d';
  }

  @override
  String get matchesOffer => 'Make offer';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Nothing new right now.';

  @override
  String get notifyToday => 'Today';

  @override
  String get notifyEarlier => 'Earlier';

  @override
  String get notificationsEmptyHint =>
      'Offers, matches and messages show up here.';

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
      'Write in whichever language suits you — readers of other languages see your text too.';

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
  String get cancel => 'Cancel';

  @override
  String get aiTitle => 'AI listing writer';

  @override
  String get aiIntro =>
      'What do you want to trade? Write a line — the AI fills in the rest.';

  @override
  String get aiHint =>
      'For example: I have an iPhone 13 Pro in good condition. Trading it for a bicycle.';

  @override
  String get aiGenerate => 'Write it';

  @override
  String get aiDone =>
      'Draft ready. Read it over and change anything that is off.';

  @override
  String get aiFailed =>
      'The AI did not answer. You can fill the fields in yourself.';

  @override
  String get verifyTitle => 'Safety & verification';

  @override
  String get verifyLevel => 'Trust level';

  @override
  String get verifySteps => 'Verification steps';

  @override
  String get verifyStepPhone => 'Phone number';

  @override
  String get verifyStepPhoneHint => 'Confirmed by SMS';

  @override
  String get verifyStepPassport => 'Passport';

  @override
  String get verifyStepPassportHint => 'Passport or PINFL';

  @override
  String get verifyStepBusiness => 'Business';

  @override
  String get verifyStepBusinessHint => 'Company documents';

  @override
  String get verifyStepBank => 'Bank account';

  @override
  String get verifyStepBankHint => 'For escrow payments';

  @override
  String get verifyStepVideo => 'Video selfie';

  @override
  String get verifyStepVideoHint => 'A 30-second selfie video';

  @override
  String verifyProgress(int score) {
    return '$score of 100';
  }

  @override
  String get verifyHeadline => 'Your trust level';

  @override
  String get verifyIntro =>
      'Every confirmed step raises your trust score — the higher it is, the more often people answer your offers.';

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

  @override
  String get paymentsCards => 'Cards';

  @override
  String get paymentsNoCards => 'No card linked';

  @override
  String get paymentsNoCardsHint =>
      'A card is needed for escrow and cash top-ups.';

  @override
  String get paymentsEmptyHint =>
      'Money movement shows up here once a deal completes.';

  @override
  String get paymentsIn => 'In';

  @override
  String get paymentsOut => 'Outgoing';

  @override
  String get settingsDarkMode => 'Dark Mode';

  @override
  String get errorLoadingCategories => 'Error loading categories';

  @override
  String get matchLabel => 'MATCH';

  @override
  String get okLabel => 'OK';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get pushNotificationsDesc => 'Receive alerts for matches and messages';

  @override
  String get editListing => 'Edit Listing';

  @override
  String get deleteListing => 'Delete Listing';

  @override
  String get savedListings => 'Saved Listings';

  @override
  String get reportUser => 'Report User';

  @override
  String get blockUser => 'Block User';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get filterTitle => 'Filters';

  @override
  String get filterMinPrice => 'Min price (sum)';

  @override
  String get filterMaxPrice => 'Max price (sum)';

  @override
  String get filterRegion => 'Region';

  @override
  String get filterApply => 'Apply';

  @override
  String get filterClear => 'Clear';

  @override
  String get errorNoImage => 'No image available';

  @override
  String get errorCategoryLoad => 'Error loading categories';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionOk => 'OK';

  @override
  String get actionDeleteListing => 'Delete Listing';

  @override
  String get actionReportUser => 'Report User';

  @override
  String get actionBlockUser => 'Block User';

  @override
  String get actionDeleteAccount => 'Delete Account';

  @override
  String get actionDarkMode => 'Dark Mode';

  @override
  String get emptyMyListings => 'No listings yet';

  @override
  String get blockedTitle => 'Blocked Users';

  @override
  String get blockedEmpty => 'No blocked users';

  @override
  String get blockedUnblock => 'Unblock';

  @override
  String get notifOffers => 'Offers';

  @override
  String get notifOffersDesc => 'Notification on new offer';

  @override
  String get notifMatches => 'Matches';

  @override
  String get notifMatchesDesc => 'Notification when looking item is found';

  @override
  String get notifMessages => 'Messages';

  @override
  String get notifMessagesDesc => 'Notification on new message';

  @override
  String get notifSystem => 'System messages';

  @override
  String get notifSystemDesc => 'Important system notifications';

  @override
  String get notifQuietHours => 'Quiet hours';

  @override
  String get notifOff => 'Disabled';

  @override
  String get notifQuietHoursStart => 'Quiet hours start';

  @override
  String get notifQuietHoursEnd => 'Quiet hours end';

  @override
  String get notifQuietHoursDisable => 'Disable quiet hours';

  @override
  String get favSavedListings => 'Saved Listings';

  @override
  String get favNoSavedListings => 'No saved listings yet';

  @override
  String get legalTitle => 'LEGAL';

  @override
  String get legalPrivacy => 'Privacy Policy';

  @override
  String get legalTerms => 'Terms of Use';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to delete your account? This action cannot be undone and your data will be permanently deleted.';

  @override
  String get profileVerifyAccount => 'Verify your account';

  @override
  String get profileVerifyDesc => 'Verify your identity to increase trust.';

  @override
  String get actionReportReasonInappropriate => 'Inappropriate';

  @override
  String get actionDeleteListingConfirm =>
      'Are you sure you want to delete this listing?';

  @override
  String get createPreferredCategory => 'Preferred Category (Optional)';

  @override
  String get createPreferCash => 'I prefer cash for this item';

  @override
  String get currencySom => 'so‘m';

  @override
  String get filterSort => 'Sort by';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortCheapest => 'Value: low to high';

  @override
  String get sortExpensive => 'Value: high to low';

  @override
  String get filterInvalidPrice => 'Enter a valid, non-negative value';

  @override
  String get filterInvalidRange =>
      'Minimum value must not exceed maximum value.';

  @override
  String get navPost => 'Post';

  @override
  String get reportSent => 'Your report was sent to moderation';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get draftFoundTitle => 'Draft found';

  @override
  String get draftFoundBody =>
      'Your unfinished listing was saved. Continue where you left off?';

  @override
  String get draftContinue => 'Continue';

  @override
  String get draftDiscard => 'Start over';

  @override
  String get draftPhotosExpired =>
      'The draft’s photos have expired — please add them again.';

  @override
  String get photoCover => 'Cover';

  @override
  String get photoUploadFailed => 'Upload failed';

  @override
  String get photoReorderHint =>
      'Press and drag a photo to reorder. The first one is shown in the feed.';

  @override
  String get createShortPhotos => 'Photos';

  @override
  String get createShortGive => 'Give';

  @override
  String get createShortTake => 'Get';

  @override
  String get createShortValue => 'Value';

  @override
  String get createPreviewTitle => 'How it looks in the feed';

  @override
  String get traderNew => 'New member';

  @override
  String get matchMutual => 'Mutual match';

  @override
  String get matchMutualHint =>
      'They want what you have, too — you can swap directly.';

  @override
  String get matchReasonNamedCategory => 'Category you asked for';

  @override
  String get matchReasonValueClose => 'Similar value';

  @override
  String get matchReasonNearby => 'Nearby';

  @override
  String get matchReasonVerified => 'Verified trader';

  @override
  String get createFieldDistrict => 'District (optional)';

  @override
  String get specRegion => 'Location';

  @override
  String get inboxArchive => 'Archive';

  @override
  String get inboxArchived => 'Archived';

  @override
  String get inboxArchivedDone => 'Chat archived';

  @override
  String get inboxUndo => 'Undo';

  @override
  String get inboxUnarchive => 'Unarchive';

  @override
  String get inboxArchivedEmpty => 'No archived chats';

  @override
  String get inboxArchivedHint =>
      'A new message in an archived chat brings it back to the inbox.';

  @override
  String get dealConfirm => 'Handed over & received';

  @override
  String get dealProblem => 'Something’s wrong';

  @override
  String get dealDisputed => 'Disputed';

  @override
  String get dealCancelled => 'Cancelled';

  @override
  String get dealDisputedOperator =>
      'Dispute opened — an operator is reviewing it. The items stay reserved.';

  @override
  String get dealCancelledInfo =>
      'The deal was cancelled — the items are back on sale.';

  @override
  String get dealResolvedComplete => 'Dispute resolved: the deal stands.';

  @override
  String get disputeTitle => 'What happened?';

  @override
  String get disputeNoShow => 'The other side didn’t show up';

  @override
  String get disputeNotReceived => 'I gave mine but got nothing';

  @override
  String get disputeNotAsDescribed => 'Not as described';

  @override
  String get disputeOther => 'Something else';

  @override
  String get disputeNote => 'Note (optional)';

  @override
  String get disputeSend => 'Open dispute';

  @override
  String get disputeHint =>
      'Small deals are settled by a rule right away; larger ones go to an operator.';

  @override
  String dealReservedUntil(String date) {
    return 'Items reserved until $date';
  }

  @override
  String dealWaitingPeer(String name) {
    return 'You confirmed. Waiting for $name.';
  }

  @override
  String get listingShare => 'Share';

  @override
  String get listingGoneTitle => 'This listing is no longer available';

  @override
  String get listingGoneHint =>
      'The owner removed it or the trade is done. The feed has similar ones.';

  @override
  String get listingGoneBack => 'Back to the feed';

  @override
  String get timelineOffered => 'Offered';

  @override
  String get timelineAgreed => 'Agreed';

  @override
  String get timelineHandedOver => 'Handed over';

  @override
  String get timelineDone => 'Done';

  @override
  String timelineSemantics(int step, int total, String name) {
    return 'Deal: step $step of $total, $name';
  }

  @override
  String get billingTitle => 'Plans and payments';

  @override
  String get billingSubtitle => 'Listing packs and boosts';

  @override
  String billingFreeLeft(int count) {
    return '$count free listings left';
  }

  @override
  String get billingFreeUnlimited =>
      'Posting listings is free and unlimited for now';

  @override
  String get billingPacks => 'LISTING PACKS';

  @override
  String get billingBoostSection => 'BOOSTS';

  @override
  String get billingBoostHint => 'Tap “Boost” on one of your active listings.';

  @override
  String billingListings(int count) {
    return '$count listings';
  }

  @override
  String billingDays(int count) {
    return '$count days on top';
  }

  @override
  String billingDiscountUntil(String date) {
    return 'Discount until $date';
  }

  @override
  String get billingPayBefore => 'Pay with';

  @override
  String get billingPayAfter => '';

  @override
  String get billingSecureNote =>
      'Card number, expiry date and the SMS code are entered on the Payme page. MAB never sees them.';

  @override
  String get billingEmpty => 'No plans yet';

  @override
  String get billingEmptyHint => 'Prices will be announced soon.';

  @override
  String get billingUnavailable =>
      'Payments are not connected yet. Please try again later.';

  @override
  String get billingHistory => 'PAYMENT HISTORY';

  @override
  String get billingNoOrders => 'No payments yet';

  @override
  String get billingOpenFailed => 'Could not open the Payme page';

  @override
  String get orderTitle => 'Payment';

  @override
  String get orderPending => 'Waiting for payment';

  @override
  String get orderPendingHint =>
      'Finish paying on the Payme page. This screen updates by itself.';

  @override
  String get orderPaid => 'Payment received';

  @override
  String orderPaidPack(int count) {
    return '$count listings were added to your account.';
  }

  @override
  String orderPaidBoost(int count) {
    return 'Your listing stays on top for $count days.';
  }

  @override
  String get orderCancelled => 'Payment cancelled';

  @override
  String get orderCancelledHint => 'You were not charged. You can try again.';

  @override
  String get orderOpenPayme => 'Open the Payme page';

  @override
  String get orderDone => 'Done';

  @override
  String get boostAction => 'Boost';

  @override
  String get boostSheetTitle => 'Boost this listing';

  @override
  String get boostSheetHint =>
      'Your listing shows higher in the feed with a Premium badge.';

  @override
  String get quotaTitle => 'Free listings used up';

  @override
  String get quotaBody => 'Pick a listing pack to publish. Your draft is kept.';

  @override
  String get quotaAction => 'See plans';

  @override
  String get authPassword => 'Sign in with password';

  @override
  String get authIdentifier => 'Phone number or email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authCurrentPassword => 'Current password (if already set)';

  @override
  String get authNewPassword => 'New password — at least 12 characters';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authPasswordMismatch =>
      'Passwords must match and contain at least 12 characters.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authManagePassword => 'Set or change password';

  @override
  String get authPasswordSaved =>
      'Password saved. Other sessions can no longer refresh.';

  @override
  String get authPhoneUnavailable =>
      'SMS sign-in and password recovery are currently unavailable.';

  @override
  String get authMethodsUnavailable =>
      'Could not load sign-in methods. Please retry.';

  @override
  String get authSetupPending =>
      'New account registration is temporarily unavailable while sign-in services are configured.';

  @override
  String get authPasswordHelp =>
      'Set a password in Settings after signing in. For a Google account, you can sign in again with Google.';

  @override
  String get authSavePassword => 'Save password';

  @override
  String get authShowPassword => 'Show/hide password';
}
