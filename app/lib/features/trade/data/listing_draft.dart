import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

/// A new listing the person started and has not published yet.
///
/// Four steps and three languages is a lot to type on a phone; an incoming
/// call or a closed app used to throw all of it away. Only finished uploads
/// are kept — a photo still in flight has no URL to come back to.
class ListingDraft {
  const ListingDraft({
    required this.savedAt,
    this.step = 0,
    this.photos = const [],
    this.tag,
    this.fields = const {},
    this.value = '',
    this.wantTag,
    this.cashOk = false,
    this.wantsCash = false,
  });

  /// The server deletes uploads no listing points at after six hours
  /// (`api/app/services/media.py`). Older draft photos are dropped on restore
  /// instead of showing as broken images; an hour of margin for clock skew.
  static const photoLifetime = Duration(hours: 5);

  final DateTime savedAt;
  final int step;

  /// Uploaded photo URLs, cover first.
  final List<String> photos;

  /// `ListingTag.name`, kept as text so an enum rename cannot crash a restore.
  final String? tag;

  /// Field name → locale → text, e.g. `{'title': {'uz': ..., 'ru': ...}}`.
  final Map<String, Map<String, String>> fields;

  final String value;
  final String? wantTag;
  final bool cashOk;
  final bool wantsCash;

  bool get isEmpty =>
      photos.isEmpty &&
      tag == null &&
      wantTag == null &&
      value.trim().isEmpty &&
      fields.values.every(
        (byLocale) => byLocale.values.every((text) => text.trim().isEmpty),
      );

  bool photosExpired(DateTime now) =>
      photos.isNotEmpty && now.difference(savedAt) > photoLifetime;

  ListingDraft withoutPhotos() => ListingDraft(
    savedAt: savedAt,
    step: 0,
    tag: tag,
    fields: fields,
    value: value,
    wantTag: wantTag,
    cashOk: cashOk,
    wantsCash: wantsCash,
  );

  Map<String, dynamic> toJson() => {
    'saved_at': savedAt.toUtc().toIso8601String(),
    'step': step,
    'photos': photos,
    'tag': tag,
    'fields': fields,
    'value': value,
    'want_tag': wantTag,
    'cash_ok': cashOk,
    'wants_cash': wantsCash,
  };

  /// Null for anything that does not look like a draft this version wrote.
  static ListingDraft? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return ListingDraft(
        savedAt: DateTime.parse(json['saved_at'] as String),
        step: json['step'] as int? ?? 0,
        photos: (json['photos'] as List? ?? const []).cast<String>(),
        tag: json['tag'] as String?,
        fields: {
          for (final e in (json['fields'] as Map? ?? const {}).entries)
            e.key as String: (e.value as Map).cast<String, String>(),
        },
        value: json['value'] as String? ?? '',
        wantTag: json['want_tag'] as String?,
        cashOk: json['cash_ok'] as bool? ?? false,
        wantsCash: json['wants_cash'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// One draft per device, in shared preferences.
///
/// Cleared on sign-out so the next person on a shared phone does not open
/// somebody else's half-written listing.
class ListingDraftStore {
  ListingDraftStore(this._prefs);

  static const key = 'listing_draft_v1';

  final SharedPreferences _prefs;

  ListingDraft? load() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final draft = ListingDraft.fromJson(jsonDecode(raw));
      return draft == null || draft.isEmpty ? null : draft;
    } on FormatException {
      return null;
    }
  }

  /// An empty draft removes the stored one rather than saving nothing.
  Future<void> save(ListingDraft draft) => draft.isEmpty
      ? clear()
      : _prefs.setString(key, jsonEncode(draft.toJson()));

  Future<void> clear() => _prefs.remove(key);
}

final listingDraftStoreProvider = Provider<ListingDraftStore>(
  (ref) => ListingDraftStore(ref.watch(sharedPreferencesProvider)),
);
