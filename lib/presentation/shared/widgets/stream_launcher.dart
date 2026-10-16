import 'package:flutter/material.dart';
import '../../../helpers/helpers.dart';
import '../../../repository/api/cast_media_service.dart';
import '../../screens/screens.dart';
import 'branded_connecting_overlay.dart';

class StreamLauncher {
  /// Launches the branded connecting overlay to safely check health and launch the player cleanly.
  /// While a Cast session is active (phone), the stream plays on the TV
  /// instead; if the TV can't play it, it falls back to the phone.
  static void openStreamWithBrandedLoading({
    required BuildContext context,
    required String streamUrl,
    Widget Function()? playerBuilder,
    VoidCallback? onSuccess,
  }) {
    if (supportsCasting() && CastMediaService().isCasting) {
      _castInstead(
        context: context,
        streamUrl: streamUrl,
        playerBuilder: playerBuilder,
        onSuccess: onSuccess,
      );
      return;
    }
    _openLocal(context, streamUrl, playerBuilder, onSuccess);
  }

  static void _openLocal(
    BuildContext context,
    String streamUrl,
    Widget Function()? playerBuilder,
    VoidCallback? onSuccess,
  ) {
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

  static String _titleOf(Widget Function()? playerBuilder) {
    if (playerBuilder == null) return 'TV Parser';
    final w = playerBuilder();
    if (w is MoviePlayerScreen) return w.title;
    if (w is LivePlayerScreen) return w.title;
    return 'TV Parser';
  }

  static Future<void> _castInstead({
    required BuildContext context,
    required String streamUrl,
    Widget Function()? playerBuilder,
    VoidCallback? onSuccess,
  }) async {
    final cast = CastMediaService();
    final device = cast.connectedDevice.value ?? 'your TV';
    final title = _titleOf(playerBuilder);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Starting "$title" on $device…'),
        duration: const Duration(seconds: 3),
      ),
    );
    final lower = streamUrl.toLowerCase();
    final vod = lower.contains('/movie/') || lower.contains('/series/');
    final ok = await cast.castStream(
      streamUrl,
      title: title,
      streamType: vod ? 'BUFFERED' : 'LIVE',
    );
    if (ok) {
      onSuccess?.call();
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Playing on $device'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('$device couldn\'t play this stream — playing on your phone.'),
        duration: const Duration(seconds: 4),
      ),
    );
    if (context.mounted) {
      _openLocal(context, streamUrl, playerBuilder, onSuccess);
    }
  }
}
