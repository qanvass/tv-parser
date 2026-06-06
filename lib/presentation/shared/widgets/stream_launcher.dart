import 'package:flutter/material.dart';
import 'branded_connecting_overlay.dart';

class StreamLauncher {
  /// Launches the branded connecting overlay to safely check health and launch the player cleanly.
  static void openStreamWithBrandedLoading({
    required BuildContext context,
    required String streamUrl,
    Widget Function()? playerBuilder,
    VoidCallback? onSuccess,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrandedConnectingOverlay(
          streamUrl: streamUrl,
          playerBuilder: playerBuilder,
          onSuccess: onSuccess,
        ),
      ),
    );
  }
}
