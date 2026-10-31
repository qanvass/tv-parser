import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/local_market_service.dart';
import 'package:mbark_iptv/repository/api/local_proximity.dart';

void main() {
  test('US Local orders Atlanta first, then nearest states', () {
    final atlanta = LocalMarketService.findMarketById('atlanta_ga')!;
    final names = [
      'Scripps Sports Las Vegas US',
      'ABC (KABC) Los Angeles CA',
      'ABC (KAKE) Wichita KS',
      'NBC (WXIA) Atlanta GA',
      'CBS (WRDW) Augusta GA',
      'Some Random Channel',
      'ABC (WSB) Atlanta GA',
      'FOX (WBRC) Birmingham AL',
    ];
    final sorted = LocalProximity.sortNearest(names, atlanta, (n) => n);
    expect(sorted.take(2), ['ABC (WSB) Atlanta GA', 'NBC (WXIA) Atlanta GA']);
    expect(sorted[2], 'CBS (WRDW) Augusta GA');
    expect(sorted[3], 'FOX (WBRC) Birmingham AL');
    expect(
      sorted.indexOf('ABC (KAKE) Wichita KS'),
      lessThan(sorted.indexOf('ABC (KABC) Los Angeles CA')),
    );
    expect(sorted.last, 'Some Random Channel');
  });

  test('nearbyOnly drops spelled-out far states, keeps Atlanta', () {
    final atlanta = LocalMarketService.findMarketById('atlanta_ga')!;
    final kept = LocalProximity.nearbyOnly(
      [
        'FOX (WAGA) Atlanta GA',
        'FOX 5 Plus (District of Columbia)',
        'PBS Georgia',
        'ESPN',
      ],
      atlanta,
      (n) => n,
    );
    expect(kept, ['FOX (WAGA) Atlanta GA', 'PBS Georgia', 'ESPN']);
  });

  test('isLocalCategory', () {
    expect(LocalProximity.isLocalCategory('US Local'), isTrue);
    expect(LocalProximity.isLocalCategory('Sports'), isFalse);
  });
}
