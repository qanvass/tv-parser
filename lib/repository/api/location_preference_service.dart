import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_preference_profile.dart';
import 'local_market_service.dart';

class LocationPreferenceService {
  /// Checks whether we should show the one-time onboarding location explanation prompt
  static bool shouldShowExplainer() {
    final profile = UserPreferenceProfile.load();
    return !profile.hasSeenLocationExplainer;
  }

  /// Silently checks if the OS permission is already granted without popping any prompts
  static Future<String> checkPermissionStatusSilently() async {
    if (kIsWeb) {
      // In web, check permission status via JavaScript if possible, or assume undetermined
      return 'undetermined';
    }

    try {
      final status = await Permission.location.status;
      if (status.isGranted) return 'granted';
      if (status.isDenied) return 'denied';
      if (status.isPermanentlyDenied) return 'permanently_denied';
      return 'undetermined';
    } catch (_) {
      return 'undetermined';
    }
  }

  /// Sets permission seen state
  static Future<void> markExplainerSeen(bool accepted) async {
    final profile = UserPreferenceProfile.load();
    final updated = profile.copyWith(
      hasSeenLocationExplainer: true,
      hasAcceptedLocationPersonalization: accepted,
      locationFeatureEnabled: accepted,
    );
    await updated.save();
  }

  /// Request Location Personalization Opt-In and triggers native prompt if allowed
  static Future<bool> requestLocationPersonalization() async {
    await markExplainerSeen(true);

    try {
      if (kIsWeb) {
        // Browser Geolocation prompt
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        await updateRegionFromCoordinates(position.latitude, position.longitude);
        return true;
      }

      // Native Mobile check & prompt
      final status = await Permission.location.request();
      final profile = UserPreferenceProfile.load();
      final updated = profile.copyWith(
        lastPermissionStatus: status.isGranted ? 'granted' : (status.isPermanentlyDenied ? 'permanently_denied' : 'denied'),
      );
      await updated.save();

      if (status.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        await updateRegionFromCoordinates(position.latitude, position.longitude);
        return true;
      }
    } catch (e) {
      debugPrint("Location request failed: $e");
    }
    return false;
  }

  /// Resolves coarse latitude/longitude to a general region label without storing precise GPS
  static Future<void> updateRegionFromCoordinates(double lat, double lon) async {
    String region = "USA";
    String country = "USA";

    final closest = LocalMarketService.findClosestMarket(lat, lon);
    if (closest != null) {
      region = closest.displayName;
      await LocalMarketService.setActiveMarket(closest.id);
    } else {
      if ((lat - 51.5).abs() < 1.5 && (lon - -0.12).abs() < 1.5) {
        region = "London, UK";
        country = "United Kingdom";
      }
    }

    final profile = UserPreferenceProfile.load();
    final updated = profile.copyWith(
      country: country,
      region: region,
      lastKnownRegionLabel: region,
      lastKnownRegionUpdatedAt: DateTime.now(),
    );
    await updated.save();
  }

  /// Toggles location personalization from settings
  static Future<void> setLocationFeatureEnabled(bool enabled) async {
    final profile = UserPreferenceProfile.load();
    final updated = profile.copyWith(
      locationFeatureEnabled: enabled,
      hasAcceptedLocationPersonalization: enabled,
    );
    await updated.save();
  }

  /// Resets all location preferences so the explainer runs again
  static Future<void> resetLocationPreferences() async {
    final profile = UserPreferenceProfile.load();
    final updated = profile.copyWith(
      hasSeenLocationExplainer: false,
      hasAcceptedLocationPersonalization: false,
      locationFeatureEnabled: true,
      lastPermissionStatus: 'undetermined',
      lastKnownRegionLabel: null,
      lastKnownRegionUpdatedAt: null,
    );
    await updated.save();
  }
}
