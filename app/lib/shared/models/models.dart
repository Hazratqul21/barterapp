import 'package:intl/intl.dart';

/// Money arrives as an integer plus a currency, never as a formatted string —
/// so "$5,000", "5 000 ₽" and "5 000 so'm" are all one number, formatted here.
class Money {
  const Money({required this.minor, required this.currency});

  final int minor;
  final String currency;

  factory Money.fromJson(Map<String, dynamic> json) => Money(
    minor: json['minor'] as int,
    currency: json['currency'] as String,
  );

  /// How the currency is written in each language.
  ///
  /// `intl` answers "so'm" for UZS whatever the locale, so a Russian screen
  /// read "1 486 800 so'm" — the number grouped in Russian, the unit in Uzbek.
  static const _units = {
    'UZS': {'uz': 'so‘m', 'ru': 'сум', 'en': 'UZS'},
    'USD': {'uz': '\$', 'ru': '\$', 'en': '\$'},
  };

  String format(String locale) {
    final grouped = NumberFormat.decimalPattern(locale).format(minor ~/ 100);
    final unit = _units[currency]?[locale] ?? currency;
    return '$grouped $unit';
  }
}

/// How a trader looks anywhere they are mentioned. Every screen renders this
/// same object, so a feed card and a chat header cannot disagree.
class TraderBrief {
  const TraderBrief({
    required this.id,
    required this.name,
    required this.isVerified,
    this.handle,
    this.avatarUrl,
    this.rating,
    this.deals = 0,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String? handle;
  final String? avatarUrl;
  final bool isVerified;
  final double? rating;
  final int deals;
  final bool isOnline;

  factory TraderBrief.fromJson(Map<String, dynamic> json) => TraderBrief(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    isVerified: json['is_verified'] as bool? ?? false,
    rating: (json['rating'] as num?)?.toDouble(),
    deals: json['deals'] as int? ?? 0,
    isOnline: json['is_online'] as bool? ?? false,
  );

  /// The person's name, with their business line only as a suffix. Never the
  /// business alone: that is how a trader ends up nameless on a card.
  String get displayName => handle == null ? name : '$name · $handle';
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? imageUrl;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }
}

enum ListingTag {
  agri,
  livestock,
  machinery,
  transport,
  electronics,
  construction;

  static ListingTag parse(String raw) =>
      ListingTag.values.firstWhere((t) => t.name == raw, orElse: () => agri);
}

class ListingCard {
  const ListingCard({
    required this.id,
    required this.tag,
    required this.title,
    required this.imageAlt,
    required this.wantsSummary,
    required this.value,
    required this.cashOk,
    required this.isPremium,
    required this.postedAt,
    required this.owner,
    this.imageUrl,
    this.distanceKm,
  });

  final String id;
  final ListingTag tag;
  final String title;
  final String? imageUrl;
  final String imageAlt;
  final String wantsSummary;
  final Money value;
  final double? distanceKm;
  final bool cashOk;
  final bool isPremium;
  final DateTime postedAt;
  final TraderBrief owner;

  factory ListingCard.fromJson(Map<String, dynamic> json) => ListingCard(
    id: json['id'] as String,
    tag: ListingTag.parse(json['tag'] as String),
    title: json['title'] as String,
    imageUrl: json['image_url'] as String?,
    imageAlt: json['image_alt'] as String,
    wantsSummary: json['wants_summary'] as String,
    value: Money.fromJson(json['value'] as Map<String, dynamic>),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    cashOk: json['cash_ok'] as bool,
    isPremium: json['is_premium'] as bool,
    postedAt: DateTime.parse(json['posted_at'] as String),
    owner: TraderBrief.fromJson(json['owner'] as Map<String, dynamic>),
  );
}

class ListingDetail extends ListingCard {
  const ListingDetail({
    required super.id,
    required super.tag,
    required super.title,
    required super.imageAlt,
    required super.wantsSummary,
    required super.value,
    required super.cashOk,
    required super.isPremium,
    required super.postedAt,
    required super.owner,
    required this.description,
    required this.category,
    required this.condition,
    required this.quantity,
    required this.gallery,
    required this.wants,
    super.imageUrl,
    super.distanceKm,
  });

  final String description;
  final String category;
  final String condition;
  final String quantity;
  final List<String> gallery;
  final List<String> wants;

  factory ListingDetail.fromJson(Map<String, dynamic> json) {
    final card = ListingCard.fromJson(json);
    return ListingDetail(
      id: card.id,
      tag: card.tag,
      title: card.title,
      imageUrl: card.imageUrl,
      imageAlt: card.imageAlt,
      wantsSummary: card.wantsSummary,
      value: card.value,
      distanceKm: card.distanceKm,
      cashOk: card.cashOk,
      isPremium: card.isPremium,
      postedAt: card.postedAt,
      owner: card.owner,
      description: json['description'] as String,
      category: json['category'] as String,
      condition: json['condition'] as String,
      quantity: json['quantity'] as String,
      gallery: (json['gallery'] as List).cast<String>(),
      wants: (json['wants'] as List).cast<String>(),
    );
  }
}

/// Cursor pages, not offsets: the feed reorders constantly.
class Page<T> {
  const Page({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) => Page(
    items: (json['items'] as List)
        .map((e) => parse(e as Map<String, dynamic>))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
  );
}

class Me {
  const Me({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.trustScore,
    required this.activeListings,
    required this.completedTrades,
    this.handle,
    this.avatarUrl,
    this.rating,
    this.reviewCount = 0,
    this.completionRate,
    this.region,
    this.district,
    this.locale = 'uz',
  });

  final String id;

  /// First and last joined, as everyone else in the app sees you.
  final String name;

  /// The two halves, because that is what the profile form edits and what the
  /// server stores. Sending a single `name` field is silently ignored.
  final String firstName;
  final String lastName;

  final String? handle;
  final String phone;
  final String? avatarUrl;
  final double? rating;
  final int reviewCount;
  final int trustScore;
  final int activeListings;
  final int completedTrades;
  final int? completionRate;

  /// Choosing a region is also what puts the account on the map — distance is
  /// 30% of a match score.
  final String? region;
  final String? district;

  final String locale;

  /// A new account has no name until the profile form is filled in, and a
  /// nameless trader is invisible on every card. Screens use this to send
  /// people to `/onboarding` rather than showing a blank.
  bool get isIncomplete => firstName.trim().isEmpty && lastName.trim().isEmpty;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    id: json['id'] as String,
    name: json['name'] as String,
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    handle: json['handle'] as String?,
    phone: json['phone'] as String,
    avatarUrl: json['avatar_url'] as String?,
    rating: (json['rating'] as num?)?.toDouble(),
    reviewCount: json['review_count'] as int? ?? 0,
    trustScore: json['trust_score'] as int? ?? 0,
    activeListings: json['active_listings'] as int? ?? 0,
    completedTrades: json['completed_trades'] as int? ?? 0,
    completionRate: json['completion_rate'] as int?,
    region: json['region'] as String?,
    district: json['district'] as String?,
    locale: json['locale'] as String? ?? 'uz',
  );
}

enum OfferStatus {
  draft, pending, talking, accepted, declined, expired, completed, disputed, refunded;

  static OfferStatus parse(String raw) =>
      OfferStatus.values.firstWhere((s) => s.name == raw, orElse: () => pending);

  bool get isLive => this == pending || this == talking || this == accepted;
}

class Offer {
  const Offer({
    required this.id,
    required this.status,
    required this.cashDeltaMinor,
    required this.currency,
    required this.createdAt,
    required this.isMine,
    required this.counterparty,
    required this.wanted,
    required this.offered,
    this.expiresAt,
    this.conversationId,
  });

  final String id;
  final OfferStatus status;
  final int cashDeltaMinor;
  final String currency;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// True when I sent it — decides which actions the deal panel offers.
  final bool isMine;
  final TraderBrief counterparty;
  final ListingCard wanted;
  final List<ListingCard> offered;
  final String? conversationId;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: json['id'] as String,
    status: OfferStatus.parse(json['status'] as String),
    cashDeltaMinor: json['cash_delta_minor'] as int? ?? 0,
    currency: json['currency'] as String? ?? 'USD',
    createdAt: DateTime.parse(json['created_at'] as String),
    expiresAt: json['expires_at'] == null
        ? null
        : DateTime.parse(json['expires_at'] as String),
    isMine: json['is_mine'] as bool? ?? false,
    counterparty: TraderBrief.fromJson(
      json['counterparty'] as Map<String, dynamic>,
    ),
    wanted: ListingCard.fromJson(json['wanted'] as Map<String, dynamic>),
    offered: (json['offered'] as List? ?? [])
        .map((e) => ListingCard.fromJson(e as Map<String, dynamic>))
        .toList(),
    conversationId: json['conversation_id'] as String?,
  );

  Money get cash => Money(minor: cashDeltaMinor, currency: currency);
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.senderId,
    required this.isMine,
    this.photoUrl,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String senderId;
  final bool isMine;
  final String? photoUrl;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    senderId: json['sender_id'] as String,
    isMine: json['is_mine'] as bool? ?? false,
    photoUrl: json['photo_url'] as String?,
  );
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.peer,
    required this.offerId,
    required this.offerStatus,
    required this.dealSummary,
    required this.gives,
    required this.receives,
    required this.cash,
    this.lastMessage,
    this.lastMessageAt,
    this.unread = 0,
  });

  final String id;
  final TraderBrief peer;
  final String offerId;
  final OfferStatus offerStatus;
  /// Titles joined with a middle dot, for anywhere that needs one string.
  final String dealSummary;

  /// The same two halves, unjoined, so a row can draw the swap as an icon.
  /// Neither shipped typeface carries U+2194 — an arrow inside a string came
  /// out as an empty box.
  final String gives;
  final String receives;

  /// The top-up that goes with the deal, formatted by the row that shows it.
  final Money cash;

  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        peer: TraderBrief.fromJson(json['peer'] as Map<String, dynamic>),
        offerId: json['offer_id'] as String,
        offerStatus: OfferStatus.parse(json['offer_status'] as String),
        dealSummary: json['deal_summary'] as String,
        gives: json['gives'] as String? ?? '',
        receives: json['receives'] as String? ?? '',
        cash: Money.fromJson(json['cash'] as Map<String, dynamic>),
        lastMessage: json['last_message'] as String?,
        lastMessageAt: json['last_message_at'] == null
            ? null
            : DateTime.parse(json['last_message_at'] as String),
        unread: json['unread'] as int? ?? 0,
      );
}

class ConversationDetail {
  const ConversationDetail({
    required this.summary,
    required this.offer,
    required this.messages,
  });

  final ConversationSummary summary;
  final Offer offer;
  final List<ChatMessage> messages;

  factory ConversationDetail.fromJson(Map<String, dynamic> json) =>
      ConversationDetail(
        summary: ConversationSummary.fromJson(json),
        offer: Offer.fromJson(json['offer'] as Map<String, dynamic>),
        messages: (json['messages'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum NotifyTargetType { chat, matches, verification, listing }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isUnread,
    required this.targetType,
    this.targetId,
    this.avatarUrl,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isUnread;

  /// Where tapping lands. Carried by the row, never guessed from `kind`.
  final NotifyTargetType targetType;
  final String? targetId;
  final String? avatarUrl;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    kind: json['kind'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    isUnread: json['is_unread'] as bool? ?? false,
    targetType: NotifyTargetType.values.firstWhere(
      (t) => t.name == json['target_type'],
      orElse: () => NotifyTargetType.listing,
    ),
    targetId: json['target_id'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class TradeMatch {
  const TradeMatch({
    required this.id,
    required this.score,
    required this.reason,
    required this.mine,
    required this.theirs,
    required this.owner,
  });

  final String id;
  final int score;
  final String reason;
  final ListingCard mine;
  final ListingCard theirs;
  final TraderBrief owner;

  factory TradeMatch.fromJson(Map<String, dynamic> json) => TradeMatch(
    id: json['id'] as String,
    score: json['score'] as int,
    reason: json['reason'] as String,
    mine: ListingCard.fromJson(json['mine'] as Map<String, dynamic>),
    theirs: ListingCard.fromJson(json['theirs'] as Map<String, dynamic>),
    owner: TraderBrief.fromJson(json['owner'] as Map<String, dynamic>),
  );
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.authorName,
    this.authorAvatarUrl,
  });

  final String id;
  final int rating;
  final String body;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatarUrl;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    rating: json['rating'] as int,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    authorName: json['author_name'] as String,
    authorAvatarUrl: json['author_avatar_url'] as String?,
  );
}

class TraderProfile {
  const TraderProfile({
    required this.brief,
    required this.joinedAt,
    this.bio,
    this.location,
    this.coverUrl,
    this.completionRate,
    this.reviewCount = 0,
  });

  final TraderBrief brief;
  final DateTime joinedAt;
  final String? bio;
  final String? location;
  final String? coverUrl;
  final int? completionRate;
  final int reviewCount;

  factory TraderProfile.fromJson(Map<String, dynamic> json) => TraderProfile(
    brief: TraderBrief.fromJson(json),
    joinedAt: DateTime.parse(json['joined_at'] as String),
    bio: json['bio'] as String?,
    location: json['location'] as String?,
    coverUrl: json['cover_url'] as String?,
    completionRate: json['completion_rate'] as int?,
    reviewCount: json['review_count'] as int? ?? 0,
  );
}

class VerificationStep {
  const VerificationStep({
    required this.step,
    required this.state,
    required this.weight,
    this.hint,
  });

  final String step;
  final String state;
  final int weight;
  final String? hint;

  factory VerificationStep.fromJson(Map<String, dynamic> json) =>
      VerificationStep(
        step: json['step'] as String,
        state: json['state'] as String,
        weight: json['weight'] as int,
        hint: json['hint'] as String?,
      );
}

class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.brand,
    required this.label,
    required this.last4,
    required this.expires,
    required this.isPrimary,
  });

  final String id;
  final String brand;
  final String label;
  final String last4;
  final String expires;
  final bool isPrimary;

  factory PaymentCard.fromJson(Map<String, dynamic> json) => PaymentCard(
    id: json['id'] as String,
    brand: json['brand'] as String,
    label: json['label'] as String,
    last4: json['last4'] as String,
    expires: json['expires'] as String,
    isPrimary: json['is_primary'] as bool,
  );
}

class Settlement {
  const Settlement({
    required this.offerId,
    required this.amount,
    required this.counterpartyName,
    required this.settledAt,
    required this.outgoing,
  });

  final String offerId;
  final Money amount;
  final String counterpartyName;
  final DateTime settledAt;
  final bool outgoing;

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
    offerId: json['offer_id'] as String,
    amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
    counterpartyName: json['counterparty_name'] as String,
    settledAt: DateTime.parse(json['settled_at'] as String),
    outgoing: json['outgoing'] as bool,
  );
}
