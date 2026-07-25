import 'package:get_storage/get_storage.dart';

/// Lightweight saved Xtream/M3U logins for multi-account switching on TV.
class SavedAccount {
  final String id;
  final String label;
  final String username;
  final String password;
  final String domain;
  final bool isM3u;
  final String? playlistUrl;

  const SavedAccount({
    required this.id,
    required this.label,
    required this.username,
    required this.password,
    required this.domain,
    this.isM3u = false,
    this.playlistUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'username': username,
        'password': password,
        'domain': domain,
        'isM3u': isM3u,
        'playlistUrl': playlistUrl,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Account',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      isM3u: json['isM3u'] == true,
      playlistUrl: json['playlistUrl']?.toString(),
    );
  }
}

class SavedAccountsService {
  static const _key = 'saved_accounts';
  static final _box = GetStorage('preferences');

  static List<SavedAccount> list() {
    try {
      final raw = _box.read(_key);
      if (raw is! List) return [];
      return raw
          .map((e) => SavedAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((a) => a.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsertXtream({
    required String username,
    required String password,
    required String domain,
  }) async {
    final accounts = list();
    final id = 'xtream:${domain.trim().toLowerCase()}:${username.trim().toLowerCase()}';
    final label = username.trim().isEmpty ? domain : username.trim();
    accounts.removeWhere((a) => a.id == id);
    accounts.insert(
      0,
      SavedAccount(
        id: id,
        label: label,
        username: username,
        password: password,
        domain: domain,
      ),
    );
    if (accounts.length > 8) {
      accounts.removeRange(8, accounts.length);
    }
    await _box.write(_key, accounts.map((a) => a.toJson()).toList());
  }

  static Future<void> upsertM3u({required String playlistUrl}) async {
    final accounts = list();
    final id = 'm3u:${playlistUrl.trim()}';
    accounts.removeWhere((a) => a.id == id);
    accounts.insert(
      0,
      SavedAccount(
        id: id,
        label: 'M3U Playlist',
        username: '',
        password: '',
        domain: '',
        isM3u: true,
        playlistUrl: playlistUrl,
      ),
    );
    if (accounts.length > 8) {
      accounts.removeRange(8, accounts.length);
    }
    await _box.write(_key, accounts.map((a) => a.toJson()).toList());
  }

  static Future<void> remove(String id) async {
    final accounts = list()..removeWhere((a) => a.id == id);
    await _box.write(_key, accounts.map((a) => a.toJson()).toList());
  }
}
