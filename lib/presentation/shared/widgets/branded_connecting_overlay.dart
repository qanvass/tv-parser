import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:mbark_iptv/helpers/helpers.dart';
import 'package:mbark_iptv/repository/api/playback_url_builder.dart';
import 'package:mbark_iptv/repository/api/cast_media_service.dart';
import '../../screens/screens.dart';

class BrandedConnectingOverlay extends StatefulWidget {
  final String streamUrl;
  final Widget Function()? playerBuilder;
  final VoidCallback? onSuccess;
  final String logoAssetPath;

  const BrandedConnectingOverlay({
    super.key,
    required this.streamUrl,
    this.playerBuilder,
    this.onSuccess,
    this.logoAssetPath = 'assets/images/tv_parser_logo_transparent.png',
  });

  @override
  State<BrandedConnectingOverlay> createState() => _BrandedConnectingOverlayState();
}

class _BrandedConnectingOverlayState extends State<BrandedConnectingOverlay> {
  int _secondsElapsed = 0;
  Timer? _timer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkStreamHealth();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsElapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  Future<void> _checkStreamHealth() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    debugPrint("[TV_PARSER_PERF] Connecting overlay shown. Instantly launching player route.");

    // TV gate: always play locally on Android TV / Google TV.
    final castService = CastMediaService();
    if (supportsCasting() && castService.isCasting) {
      final uri = Uri.tryParse(widget.streamUrl);
      if (uri != null && uri.pathSegments.length >= 4) {
        final type = uri.pathSegments[0]; // live, movie, series
        final streamIdWithExt = uri.pathSegments[3];
        final parts = streamIdWithExt.split('.');
        final streamId = parts[0];
        final originalExt = parts.length > 1 ? parts[1] : '';

        await _handleCasting(type, streamId, originalExt);
        if (mounted) setState(() => _isChecking = false);
        return;
      }
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() => _isChecking = false);
    _launchLocalPlayer();
  }

  void _launchLocalPlayer() {
    if (widget.onSuccess != null) {
      Navigator.of(context).pop(true);
      widget.onSuccess!();
    } else if (widget.playerBuilder != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.playerBuilder!()),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleCasting(String type, String streamId, String originalExt) async {
    String castUrl = '';
    String title = 'Cast Stream';
    String subtitle = 'TV Parser';
    String streamType = 'BUFFERED';

    if (type == 'live') {
      streamType = 'LIVE';
      title = 'Live Channel';
      castUrl = await PlaybackUrlBuilder.buildLiveUrl(streamId, preferCast: true);
    } else if (type == 'movie') {
      title = 'Movie';
      castUrl = await PlaybackUrlBuilder.buildMovieUrl(streamId, containerExtension: originalExt);
    } else if (type == 'series') {
      title = 'Series Episode';
      castUrl = await PlaybackUrlBuilder.buildSeriesUrl(streamId, containerExtension: originalExt);
    } else {
      castUrl = widget.streamUrl;
    }

    CastDiagnosticsService.log('Casting stream URL constructed: (sensitive URL details hidden)');
    
    // Check reachability
    bool reachable = await _testStreamReachability(castUrl);
    if (!reachable && type == 'live') {
      CastDiagnosticsService.log('Preferred Cast URL (.m3u8) failed reachability. Retrying with fallback .ts format...');
      castUrl = await PlaybackUrlBuilder.buildLiveUrl(streamId, preferCast: true, isFallback: true);
      reachable = await _testStreamReachability(castUrl);
    }

    if (!reachable) {
      CastDiagnosticsService.log('Cast stream unreachable on both preferred HLS and fallback formats.');
      _showCastErrorSnackbar();
      _launchLocalPlayer();
      return;
    }

    // Cast the stream!
    final castService = CastMediaService();
    await castService.castStream(
      castUrl,
      title: title,
      subtitle: subtitle,
      streamType: streamType,
    );

    Get.snackbar(
      'Casting to Device',
      'Streaming "$title" to ${castService.selectedDevice?.name ?? "Chromecast"}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xE0101018),
      colorText: Colors.white,
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _testStreamReachability(String url) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));
    
    try {
      final response = await dio.head(url);
      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {'Range': 'bytes=0-1024'},
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 206) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  void _showCastErrorSnackbar() {
    Get.snackbar(
      'Cast Playback Failed',
      'Device connected, but this stream could not be played on Cast. Try local playback or another stream.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade900,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    String message = "Hold please...";
    String subMessage = "Loading your provider's stream...";
    bool showActions = false;

    if (_secondsElapsed >= 10) {
      message = "Taking longer than expected";
      subMessage = "This may be a provider or network delay.";
      showActions = true;
    } else if (_secondsElapsed >= 4) {
      message = "Still loading stream...";
      subMessage = "Checking provider response";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050509),
      body: Stack(
        children: [
          // Radial Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.3,
                  colors: [
                    const Color(0xFF25112F).withOpacity(0.4),
                    const Color(0xFF08070C),
                    const Color(0xFF030305),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // TV Parser Logo
                  Image.asset(
                    widget.logoAssetPath,
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.live_tv_rounded, size: 72, color: Colors.amber),
                  ),
                  const SizedBox(height: 28),

                  // Rotating sand hourglass timeclock
                  if (!showActions)
                    const SandTimeclock(size: 36),
                  const SizedBox(height: 24),

                  // Debug Cast Test Button (phone only)
                  if (kDebugMode && supportsCasting() && CastMediaService().isCasting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(200, 38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                        ),
                        onPressed: () async {
                          final castService = CastMediaService();
                          await castService.castStream(
                            'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                            title: 'HLS Test (Steel)',
                            streamType: 'BUFFERED',
                          );
                          Get.snackbar('HLS Test Cast', 'Pushed tears-of-steel HLS to receiver');
                        },
                        icon: const Icon(Icons.bug_report_rounded, size: 14),
                        label: const Text("Cast Test (HLS)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  // Message
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Submessage
                  Text(
                    subMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Timeout Action Buttons
                  if (showActions)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          // Try Again
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(180, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            ),
                            onPressed: () {
                              _startTimer();
                              _checkStreamHealth();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text("Try Again", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: 12),

                          // Connection Test
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(180, 44),
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                            ),
                            onPressed: () {
                              // Push connection diagnostics screen cleanly
                              Get.to(() => const ConnectionTestScreen());
                            },
                            icon: const Icon(Icons.network_check_rounded, size: 16),
                            label: const Text("Connection Test", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: 12),

                          // Back
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text("Go Back", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
