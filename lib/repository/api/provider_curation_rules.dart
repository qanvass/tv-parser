import 'package:mbark_iptv/repository/models/category.dart';

class ProviderCurationRules {
  static const String adultUnlockPin = '12345';

  /// Determines if a category or channel name is considered Adult/18+.
  static bool isAdultCategory(String name) {
    final lower = name.toLowerCase();
    final adultKeywords = [
      'adult', 'xxx', '18+', 'porn', 'porno', 'nude', 'erotic', 'sex',
      'playboy', 'hustler', 'private', 'mature'
    ];
    return adultKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Determines if a category/channel should be hidden from the normal dashboard or search.
  static bool shouldHideFromNormalDashboard(String name) {
    if (isAdultCategory(name)) return true;
    final lower = name.toLowerCase();
    final hideKeywords = ['backup', 'dead', 'temp', 'test'];
    return hideKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Sorts category models placing USA first, followed by Canada, UK, other English, international, and backups.
  static List<CategoryModel> sortCategoriesForNormalDashboard(List<CategoryModel> categories) {
    final List<CategoryModel> sorted = List<CategoryModel>.from(categories);
    sorted.sort((a, b) {
      final scoreA = getCategoryScore(a.categoryName ?? '');
      final scoreB = getCategoryScore(b.categoryName ?? '');
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Higher score first
      }
      return (a.categoryName ?? '').compareTo(b.categoryName ?? '');
    });
    return sorted;
  }

  /// Assigns a sorting score to a category name.
  static int getCategoryScore(String name) {
    final lower = name.toLowerCase();

    // Hidden or backup categories
    final hideKeywords = ['backup', 'dead', 'temp', 'test'];
    if (hideKeywords.any((keyword) => lower.contains(keyword))) {
      return -100;
    }

    if (isAdultCategory(name)) {
      return -1000;
    }

    // USA prioritizations
    final isUsa = lower.contains('usa') || lower.contains('united states') || RegExp(r'\bus\b').hasMatch(lower);
    if (isUsa) {
      int subScore = 1000;
      if (lower.contains('sports')) subScore += 90;
      if (lower.contains('news')) subScore += 80;
      if (lower.contains('local')) subScore += 70;
      if (lower.contains('entertainment')) subScore += 60;
      if (lower.contains('movies')) subScore += 50;
      if (lower.contains('kids') || lower.contains('family')) subScore += 40;
      if (lower.contains('premium')) subScore += 30;
      if (lower.contains('24/7')) subScore += 20;
      if (lower.contains('ppv') || lower.contains('events')) subScore += 10;
      return subScore;
    }

    // Canada English
    if (lower.contains('canada') && (lower.contains('english') || lower.contains('en') || (!lower.contains('french') && !lower.contains('fr')))) {
      return 800;
    }

    // UK English
    if (lower.contains('uk') || lower.contains('united kingdom')) {
      return 700;
    }

    // Other English
    if (lower.contains('english') || lower.contains('en')) {
      return 600;
    }

    // International categories
    return 100;
  }

  /// Sorts any stream list (Live/Movie/Series) by USA/English priority, genre boosts, and quality.
  static List<T> sortStreamsByEnglishPriority<T>(List<T> streams) {
    final List<T> sorted = List<T>.from(streams);
    sorted.sort((a, b) {
      final nameA = _getStreamName(a);
      final nameB = _getStreamName(b);
      final scoreA = _getStreamScore(nameA);
      final scoreB = _getStreamScore(nameB);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Higher score first
      }
      return nameA.compareTo(nameB);
    });
    return sorted;
  }

  static String _getStreamName(dynamic stream) {
    if (stream == null) return '';
    try {
      return (stream.name ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  static int _getStreamScore(String name) {
    final lower = name.toLowerCase();

    // Backup penalty
    if (lower.contains('backup') || lower.contains('temp') || lower.contains('test') || lower.contains('dead')) {
      return -1000;
    }

    // Adult penalty
    if (isAdultCategory(name)) {
      return -5000;
    }

    int score = 0;

    // USA Boost
    final isUsa = lower.contains('usa') || lower.contains('united states') || RegExp(r'\bus\b').hasMatch(lower);
    if (isUsa) {
      score += 500;
    } else {
      // Canada/UK/English Boost
      final isSecondary = lower.contains('canada') || lower.contains('uk') || lower.contains('united kingdom') || lower.contains('english');
      if (isSecondary) {
        score += 300;
      }
    }

    // Genre boost
    final boostGenres = ['sports', 'news', 'local', 'premium', 'kids', 'movies', '24/7', 'ppv', 'events', 'entertainment'];
    if (boostGenres.any((genre) => lower.contains(genre))) {
      score += 100;
    }

    // Quality hierarchy (4K/FHD > HD > SD)
    if (lower.contains('4k') || lower.contains('uhd') || lower.contains('fhd') || lower.contains('1080p')) {
      score += 50;
    } else if (lower.contains('hd') || lower.contains('720p')) {
      score += 30;
    } else if (lower.contains('sd') || lower.contains('576p') || lower.contains('480p')) {
      score += 10;
    }

    return score;
  }

  /// Returns true if the channel name matches any Atlanta local affiliate.
  static bool isAtlantaLocal(String name) {
    final lower = name.toLowerCase();

    // ABC: WSB, WSB-TV, WSB 2, Channel 2 Atlanta, ABC Atlanta, ABC 2 Atlanta
    if (lower.contains('wsb') ||
        lower.contains('channel 2') ||
        lower.contains('abc atlanta') ||
        lower.contains('abc 2 atlanta')) {
      return true;
    }
    // FOX: WAGA, WAGA-TV, WAGA 5, FOX 5, FOX 5 Atlanta, FOX Atlanta
    if (lower.contains('waga') ||
        lower.contains('fox 5') ||
        lower.contains('fox atlanta')) {
      return true;
    }
    // NBC: WXIA, WXIA-TV, WXIA 11, 11Alive, NBC Atlanta, NBC 11 Atlanta
    if (lower.contains('wxia') ||
        lower.contains('11alive') ||
        lower.contains('nbc atlanta') ||
        lower.contains('nbc 11')) {
      return true;
    }
    // CBS (Current): WUPA, WUPA-TV, WUPA 69, CBS Atlanta, CBS 69 Atlanta
    if (lower.contains('wupa') ||
        lower.contains('cbs atlanta') ||
        lower.contains('cbs 69')) {
      return true;
    }
    // CBS (Legacy / Fallback): WANF, WANF-TV, CBS 46, Atlanta News First, WGCL
    if (lower.contains('wanf') ||
        lower.contains('cbs 46') ||
        lower.contains('atlanta news first') ||
        lower.contains('wgcl')) {
      return true;
    }
    // Independent / Peachtree: WPCH, WPCH-TV, WPCH 17, Peachtree TV, Peachtree Atlanta
    if (lower.contains('wpch') ||
        lower.contains('peachtree')) {
      return true;
    }
    // CW / MyNetwork / Local: CW Atlanta, Atlanta CW, WATL, WATL 36, My ATL, MyNetwork Atlanta
    if (lower.contains('watl') ||
        lower.contains('my atl') ||
        lower.contains('mynetwork atlanta') ||
        lower.contains('cw atlanta') ||
        lower.contains('atlanta cw')) {
      return true;
    }
    // PBS: GPB, Georgia PBS, WGTV, WGTV 8, WPBA, WPBA 30, PBS Atlanta
    if (lower.contains('gpb') ||
        lower.contains('georgia pbs') ||
        lower.contains('wgtv') ||
        lower.contains('wpba') ||
        lower.contains('pbs atlanta')) {
      return true;
    }
    // Spanish local: WUVG, WUVG 34, Univision Atlanta, WKTB, WKTB 47, Telemundo Atlanta
    if (lower.contains('wuvg') ||
        lower.contains('wktb') ||
        lower.contains('univision atlanta') ||
        lower.contains('telemundo atlanta')) {
      return true;
    }

    return false;
  }

  /// Returns a priority weight for sorting Atlanta local channels.
  static int getAtlantaLocalPriority(String name) {
    final lower = name.toLowerCase();

    // 1. WSB / ABC / Channel 2
    if (lower.contains('wsb') ||
        lower.contains('channel 2') ||
        lower.contains('abc atlanta') ||
        lower.contains('abc 2 atlanta')) {
      return 1100;
    }
    // 2. WAGA / FOX 5
    if (lower.contains('waga') ||
        lower.contains('fox 5') ||
        lower.contains('fox atlanta')) {
      return 1000;
    }
    // 3. WXIA / NBC / 11Alive
    if (lower.contains('wxia') ||
        lower.contains('11alive') ||
        lower.contains('nbc atlanta') ||
        lower.contains('nbc 11')) {
      return 900;
    }
    // 4. WUPA / CBS 69 / CBS Atlanta
    if (lower.contains('wupa') ||
        lower.contains('cbs atlanta') ||
        lower.contains('cbs 69')) {
      return 800;
    }
    // 5. WANF / CBS 46 / Atlanta News First (Legacy Fallback)
    if (lower.contains('wanf') ||
        lower.contains('cbs 46') ||
        lower.contains('atlanta news first') ||
        lower.contains('wgcl')) {
      return 700;
    }
    // 6. WPCH / Peachtree TV
    if (lower.contains('wpch') ||
        lower.contains('peachtree')) {
      return 600;
    }
    // 7. WATL
    if (lower.contains('watl') ||
        lower.contains('my atl') ||
        lower.contains('mynetwork atlanta') ||
        lower.contains('cw atlanta') ||
        lower.contains('atlanta cw')) {
      return 500;
    }
    // 8. GPB / WGTV
    if (lower.contains('gpb') ||
        lower.contains('georgia pbs') ||
        lower.contains('wgtv') ||
        lower.contains('pbs atlanta')) {
      return 400;
    }
    // 9. WPBA
    if (lower.contains('wpba')) {
      return 300;
    }
    // 10. WUVG / Univision
    if (lower.contains('wuvg') ||
        lower.contains('univision atlanta')) {
      return 200;
    }
    // 11. WKTB / Telemundo
    if (lower.contains('wktb') ||
        lower.contains('telemundo atlanta')) {
      return 100;
    }

    return 0;
  }
}
