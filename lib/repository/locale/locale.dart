part of '../api/api.dart';

class LocaleApi {
  static Future<bool> saveUser(UserModel user) async {
    try {
      await locale.write("user", user.toJson());
      return true;
    } catch (e) {
      debugPrint("Error save User: $e");
      return false;
    }
  }

  static Future<UserModel?> getUser() async {
    try {
      final user = await locale.read("user");

      if (user != null) {
        return UserModel.fromJson(user, user['server_info']['server_url']);
      }
      return null;
    } catch (e) {
      debugPrint("Error save User: $e");
      return null;
    }
  }

  static Future<bool> logOut() async {
    try {
      await locale.remove("user");
      await locale.remove("m3u_categories");
      await locale.remove("m3u_channels");

      return true;
    } catch (e) {
      debugPrint("Error LogOut User: $e");
      return false;
    }
  }

  static Future<bool> saveM3uCategories(List<CategoryModel> categories) async {
    try {
      await locale.write(
        "m3u_categories",
        categories.map((e) => e.toJson()).toList(),
      );
      return true;
    } catch (e) {
      debugPrint("Error save M3U Categories: $e");
      return false;
    }
  }

  static List<CategoryModel> getM3uCategories() {
    try {
      final List<dynamic>? raw = locale.read("m3u_categories");
      if (raw != null) {
        return raw
            .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint("Error get M3U Categories: $e");
    }
    return [];
  }

  static Future<bool> saveM3uChannels(List<ChannelLive> channels) async {
    try {
      await locale.write(
        "m3u_channels",
        channels.map((e) => e.toJson()).toList(),
      );
      return true;
    } catch (e) {
      debugPrint("Error save M3U Channels: $e");
      return false;
    }
  }

  static List<ChannelLive> getM3uChannels() {
    try {
      final List<dynamic>? raw = locale.read("m3u_channels");
      if (raw != null) {
        return raw
            .map((e) => ChannelLive.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint("Error get M3U Channels: $e");
    }
    return [];
  }
}
