import 'package:flutter_test/flutter_test.dart';
import 'package:mbark_iptv/repository/api/provider_curation_rules.dart';

void main() {
  test('adult unlock PIN', () {
    expect(ProviderCurationRules.adultUnlockPin, '4321');
  });

  test('XXX and X-rated groups are adult (locked behind the PIN)', () {
    for (final name in [
      'XXX',
      'XXX Movies',
      'X Rated',
      'X-Rated Cinema',
      'XRated',
      'Rated X',
      'x_rated',
    ]) {
      expect(ProviderCurationRules.isAdultCategory(name), isTrue, reason: name);
    }
  });

  test('ordinary names are not adult', () {
    for (final name in ['X Factor', 'Max Rated Movies', 'Xbox Live', 'US Local']) {
      expect(ProviderCurationRules.isAdultCategory(name), isFalse, reason: name);
    }
  });
}
