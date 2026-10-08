import 'package:barter_app/core/share/listing_link.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _listing = ListingCard(
  id: 'abc',
  tag: ListingTag.electronics,
  title: 'MacBook Pro 14',
  imageAlt: 'Noutbuk',
  wantsSummary: 'Telefon',
  value: const Money(minor: 1850000000, currency: 'UZS'),
  cashOk: true,
  isPremium: false,
  postedAt: DateTime.utc(2026, 10, 6),
  owner: const TraderBrief(id: 'o', name: 'Aziz', isVerified: true),
);

void main() {
  test('short link under the configured web address', () {
    expect(
      listingShareUri('abc', base: 'https://barter.example.uz').toString(),
      'https://barter.example.uz/l/abc',
    );
    expect(
      listingShareUri('abc', base: 'https://barter.example.uz/app/').toString(),
      'https://barter.example.uz/app/l/abc',
    );
  });

  test('no link at all rather than a broken one', () {
    expect(listingShareUri('abc', base: ''), isNull);
    expect(listingShareUri('abc', base: 'not a url'), isNull);
  });

  test('share text: title, price, wish, link', () {
    final text = listingShareText(
      _listing,
      'uz',
      base: 'https://barter.example.uz',
    );
    final lines = text.split('\n');
    expect(lines.first, 'MacBook Pro 14');
    expect(lines[1], contains('so‘m'));
    expect(lines, contains('⇄ Telefon'));
    expect(lines.last, 'https://barter.example.uz/l/abc');

    expect(listingShareText(_listing, 'uz', base: ''), isNot(contains('http')));
  });
}
