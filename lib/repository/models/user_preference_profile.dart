import 'dart:convert';
import 'package:get_storage/get_storage.dart';

class UserPreferenceProfile {
  final String? country;
  final String? region;
  final String? language;
  final List<String> preferredGenres;
  final List<String> preferredCategories;
  final List<String> favorites;
  final List<String> recentWatchHistory;
  final List<String> lastSearches;

  // Onboarding Curation Preferences
  final bool prefersSports;
  final bool prefersNews;
  final bool prefersKids;
  final bool hideAdultContent;

  // Location Permission & Memory Compliance System
  final bool hasSeenLocationExplainer;
  final bool hasAcceptedLocationPersonalization;
  final bool locationFeatureEnabled;
  final String lastPermissionStatus;
  final String? lastKnownRegionLabel;
  final DateTime? lastKnownRegionUpdatedAt;

  // Behavioral Learning Logs
  final Map<String, int> categoryClicks;
  final Map<String, int> playDurationMap; // itemId -> total play seconds
  final Map<String, List<int>> timeOfDayUsage; // categoryId -> list of hours [0-23]

  UserPreferenceProfile({
    this.country,
    this.region,
    this.language,
    this.preferredGenres = const [],
    this.preferredCategories = const [],
    this.favorites = const [],
    this.recentWatchHistory = const [],
    this.lastSearches = const [],
    this.prefersSports = false,
    this.prefersNews = false,
    this.prefersKids = false,
    this.hideAdultContent = true,
    this.hasSeenLocationExplainer = false,
    this.hasAcceptedLocationPersonalization = false,
    this.locationFeatureEnabled = true,
    this.lastPermissionStatus = 'undetermined',
    this.lastKnownRegionLabel,
    this.lastKnownRegionUpdatedAt,
    this.categoryClicks = const {},
    this.playDurationMap = const {},
    this.timeOfDayUsage = const {},
  });

  Map<String, dynamic> toJson() => {
        'country': country,
        'region': region,
        'language': language,
        'preferredGenres': preferredGenres,
        'preferredCategories': preferredCategories,
        'favorites': favorites,
        'recentWatchHistory': recentWatchHistory,
        'lastSearches': lastSearches,
        'prefersSports': prefersSports,
        'prefersNews': prefersNews,
        'prefersKids': prefersKids,
        'hideAdultContent': hideAdultContent,
        'hasSeenLocationExplainer': hasSeenLocationExplainer,
        'hasAcceptedLocationPersonalization': hasAcceptedLocationPersonalization,
        'locationFeatureEnabled': locationFeatureEnabled,
        'lastPermissionStatus': lastPermissionStatus,
        'lastKnownRegionLabel': lastKnownRegionLabel,
        'lastKnownRegionUpdatedAt': lastKnownRegionUpdatedAt?.toIso8601String(),
        'categoryClicks': categoryClicks,
        'playDurationMap': playDurationMap,
        'timeOfDayUsage': timeOfDayUsage.map((k, v) => MapEntry(k, v)),
      };

  factory UserPreferenceProfile.fromJson(Map<String, dynamic> json) {
    // Safely parse maps
    Map<String, int> clicks = {};
    if (json['categoryClicks'] != null) {
      try {
        final rawClicks = Map<String, dynamic>.from(json['categoryClicks']);
        rawClicks.forEach((k, v) {
          clicks[k] = int.tryParse(v.toString()) ?? 0;
        });
      } catch (_) {}
    }

    Map<String, int> playDurations = {};
    if (json['playDurationMap'] != null) {
      try {
        final rawDurations = Map<String, dynamic>.from(json['playDurationMap']);
        rawDurations.forEach((k, v) {
          playDurations[k] = int.tryParse(v.toString()) ?? 0;
        });
      } catch (_) {}
    }

    Map<String, List<int>> usages = {};
    if (json['timeOfDayUsage'] != null) {
      try {
        final rawUsages = Map<String, dynamic>.from(json['timeOfDayUsage']);
        rawUsages.forEach((k, v) {
          if (v is List) {
            usages[k] = v.map((item) => int.tryParse(item.toString()) ?? 0).toList();
          }
        });
      } catch (_) {}
    }

    DateTime? regionUpdatedAt;
    if (json['lastKnownRegionUpdatedAt'] != null) {
      try {
        regionUpdatedAt = DateTime.parse(json['lastKnownRegionUpdatedAt'].toString());
      } catch (_) {}
    }

    return UserPreferenceProfile(
      country: json['country']?.toString(),
      region: json['region']?.toString(),
      language: json['language']?.toString(),
      preferredGenres: List<String>.from(json['preferredGenres'] ?? []),
      preferredCategories: List<String>.from(json['preferredCategories'] ?? []),
      favorites: List<String>.from(json['favorites'] ?? []),
      recentWatchHistory: List<String>.from(json['recentWatchHistory'] ?? []),
      lastSearches: List<String>.from(json['lastSearches'] ?? []),
      prefersSports: json['prefersSports'] == true,
      prefersNews: json['prefersNews'] == true,
      prefersKids: json['prefersKids'] == true,
      hideAdultContent: json['hideAdultContent'] ?? true,
      hasSeenLocationExplainer: json['hasSeenLocationExplainer'] == true,
      hasAcceptedLocationPersonalization: json['hasAcceptedLocationPersonalization'] == true,
      locationFeatureEnabled: json['locationFeatureEnabled'] ?? true,
      lastPermissionStatus: json['lastPermissionStatus']?.toString() ?? 'undetermined',
      lastKnownRegionLabel: json['lastKnownRegionLabel']?.toString(),
      lastKnownRegionUpdatedAt: regionUpdatedAt,
      categoryClicks: clicks,
      playDurationMap: playDurations,
      timeOfDayUsage: usages,
    );
  }

  static UserPreferenceProfile load() {
    final box = GetStorage("preferences");
    final data = box.read("profile");
    if (data == null) {
      return UserPreferenceProfile();
    }
    try {
      final Map<String, dynamic> decoded =
          data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
      return UserPreferenceProfile.fromJson(decoded);
    } catch (_) {
      return UserPreferenceProfile();
    }
  }

  Future<void> save() async {
    final box = GetStorage("preferences");
    await box.write("profile", toJson());
  }

  UserPreferenceProfile copyWith({
    String? country,
    String? region,
    String? language,
    List<String>? preferredGenres,
    List<String>? preferredCategories,
    List<String>? favorites,
    List<String>? recentWatchHistory,
    List<String>? lastSearches,
    bool? prefersSports,
    bool? prefersNews,
    bool? prefersKids,
    bool? hideAdultContent,
    bool? hasSeenLocationExplainer,
    bool? hasAcceptedLocationPersonalization,
    bool? locationFeatureEnabled,
    String? lastPermissionStatus,
    String? lastKnownRegionLabel,
    DateTime? lastKnownRegionUpdatedAt,
    Map<String, int>? categoryClicks,
    Map<String, int>? playDurationMap,
    Map<String, List<int>>? timeOfDayUsage,
  }) {
    return UserPreferenceProfile(
      country: country ?? this.country,
      region: region ?? this.region,
      language: language ?? this.language,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      favorites: favorites ?? this.favorites,
      recentWatchHistory: recentWatchHistory ?? this.recentWatchHistory,
      lastSearches: lastSearches ?? this.lastSearches,
      prefersSports: prefersSports ?? this.prefersSports,
      prefersNews: prefersNews ?? this.prefersNews,
      prefersKids: prefersKids ?? this.prefersKids,
      hideAdultContent: hideAdultContent ?? this.hideAdultContent,
      hasSeenLocationExplainer: hasSeenLocationExplainer ?? this.hasSeenLocationExplainer,
      hasAcceptedLocationPersonalization: hasAcceptedLocationPersonalization ?? this.hasAcceptedLocationPersonalization,
      locationFeatureEnabled: locationFeatureEnabled ?? this.locationFeatureEnabled,
      lastPermissionStatus: lastPermissionStatus ?? this.lastPermissionStatus,
      lastKnownRegionLabel: lastKnownRegionLabel ?? this.lastKnownRegionLabel,
      lastKnownRegionUpdatedAt: lastKnownRegionUpdatedAt ?? this.lastKnownRegionUpdatedAt,
      categoryClicks: categoryClicks ?? this.categoryClicks,
      playDurationMap: playDurationMap ?? this.playDurationMap,
      timeOfDayUsage: timeOfDayUsage ?? this.timeOfDayUsage,
    );
  }
}
