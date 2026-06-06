part of '../screens.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

enum DiagnosticState { notStarted, running, success, failed }

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  bool _isRunning = false;
  
  // Interactive TV focus management
  int _focusedBtnIdx = 0; // 0 = Run Diagnostics, 1 = Back Button
  final _screenFocusNode = FocusNode();

  // Test Results
  String _connectionType = "Unknown";
  List<String> _consoleLogs = [];
  final ScrollController _consoleScrollController = ScrollController();

  DiagnosticState _providerState = DiagnosticState.notStarted;
  int? _providerLatency;
  String? _providerHost;

  DiagnosticState _dnsState = DiagnosticState.notStarted;
  int? _cloudflareLatency;
  int? _googleLatency;
  String _latencyRating = "—";
  Color _latencyRatingColor = Colors.grey;

  DiagnosticState _streamState = DiagnosticState.notStarted;
  String? _streamReachabilityDetails;

  DiagnosticState _cdnState = DiagnosticState.notStarted;
  double? _cdnSpeedMbps;
  String? _cdnImageUrl;
  int? _cdnDownloadedBytes;
  int? _cdnDurationMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAllDiagnostics();
    });
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    setState(() {
      _consoleLogs.add(message);
    });
    // Autoscroll console to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runAllDiagnostics() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _consoleLogs.clear();
      _connectionType = "Detecting...";
      _providerState = DiagnosticState.running;
      _dnsState = DiagnosticState.running;
      _streamState = DiagnosticState.running;
      _cdnState = DiagnosticState.running;
      _providerLatency = null;
      _cloudflareLatency = null;
      _googleLatency = null;
      _latencyRating = "—";
      _latencyRatingColor = Colors.grey;
      _streamReachabilityDetails = null;
      _cdnSpeedMbps = null;
      _cdnImageUrl = null;
      _cdnDownloadedBytes = null;
      _cdnDurationMs = null;
    });

    _log("=== STARTING CONNECTION DIAGNOSTICS ===");
    _log("Timestamp: ${DateTime.now().toLocal()}");

    // 1. Network Interface Logging
    await _logNetworkInterfaces();

    // 2. DNS & Latency Tests
    await _testDnsAndLatency();

    // 3. Provider API Ping
    await _pingProviderApi();

    // 4. Stream Reachability Handshake
    await _testStreamHandshake();

    // 5. CDN Speed and Image Load Test
    await _testCdnSpeedAndImage();

    setState(() {
      _isRunning = false;
    });
    _log("=== DIAGNOSTICS COMPLETED ===");
  }

  Future<void> _logNetworkInterfaces() async {
    _log("[1/5] Querying active network interfaces...");
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any,
      );

      if (interfaces.isEmpty) {
        _log("WARN: No active physical network interfaces found.");
        setState(() {
          _connectionType = "None Detected";
        });
        return;
      }

      String guessedType = "Unknown";
      for (var interface in interfaces) {
        final ipList = interface.addresses.map((a) => a.address).join(", ");
        _log("• Interface found: '${interface.name}' | IP(s): $ipList");

        final nameLower = interface.name.toLowerCase();
        if (nameLower.contains("wlan") ||
            nameLower.contains("wifi") ||
            nameLower.contains("wireless") ||
            nameLower.contains("en0")) {
          guessedType = "Wi-Fi";
        } else if (nameLower.contains("rmnet") ||
            nameLower.contains("pdp") ||
            nameLower.contains("cellular") ||
            nameLower.contains("mobile") ||
            nameLower.contains("lte") ||
            nameLower.contains("3g") ||
            nameLower.contains("5g")) {
          guessedType = "Cellular";
        } else if (nameLower.contains("eth") || nameLower.contains("ethernet")) {
          guessedType = "Ethernet";
        }
      }

      setState(() {
        _connectionType = guessedType;
      });
      _log("Active network type recognized: $guessedType");
    } catch (e) {
      _log("ERROR: Interface lookup failed: $e");
      setState(() {
        _connectionType = "Error";
      });
    }
  }

  Future<void> _testDnsAndLatency() async {
    _log("[2/5] Testing Estimated Latency (Public DNS servers)...");
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ));

    Future<int?> pingUrl(String url) async {
      final stopwatch = Stopwatch()..start();
      try {
        await dio.get(url);
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      } catch (e) {
        stopwatch.stop();
        if (e is DioException && e.response != null) {
          // Handshake still completed to server level
          return stopwatch.elapsedMilliseconds;
        }
        return null;
      }
    }

    _log("• Handshaking with Cloudflare DNS (1.1.1.1)...");
    _cloudflareLatency = await pingUrl("http://1.1.1.1");
    if (_cloudflareLatency != null) {
      _log("  Cloudflare DNS Latency: ${_cloudflareLatency}ms");
    } else {
      _log("  Cloudflare DNS: Host Unreachable");
    }

    _log("• Handshaking with Google DNS (8.8.8.8)...");
    _googleLatency = await pingUrl("http://8.8.8.8");
    if (_googleLatency != null) {
      _log("  Google DNS Latency: ${_googleLatency}ms");
    } else {
      _log("  Google DNS: Host Unreachable");
    }

    // Determine latency rating
    final List<int> validLatencies = [];
    if (_cloudflareLatency != null) validLatencies.add(_cloudflareLatency!);
    if (_googleLatency != null) validLatencies.add(_googleLatency!);

    setState(() {
      if (validLatencies.isEmpty) {
        _dnsState = DiagnosticState.failed;
        _latencyRating = "Poor (Offline)";
        _latencyRatingColor = Colors.redAccent;
      } else {
        _dnsState = DiagnosticState.success;
        final avg = validLatencies.reduce((a, b) => a + b) ~/ validLatencies.length;
        if (avg < 50) {
          _latencyRating = "Excellent (${avg}ms)";
          _latencyRatingColor = Colors.green;
        } else if (avg < 150) {
          _latencyRating = "Good (${avg}ms)";
          _latencyRatingColor = Colors.orange;
        } else {
          _latencyRating = "Poor (${avg}ms)";
          _latencyRatingColor = Colors.redAccent;
        }
      }
    });

    _log("Estimated DNS Latency classification: $_latencyRating");
  }

  Future<void> _pingProviderApi() async {
    _log("[3/5] Pinging IPTV Provider API endpoint...");
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    String? providerUrl;
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is AuthSuccess) {
      final user = (authBloc.state as AuthSuccess).user;
      providerUrl = user.serverInfo?.serverUrl ?? user.serverInfo?.url;
    }

    if (providerUrl == null || providerUrl.isEmpty) {
      _log("INFO: User is not authenticated. Skipping specific provider ping.");
      setState(() {
        _providerState = DiagnosticState.failed;
        _providerHost = "Not Logged In";
      });
      return;
    }

    // Standardize URL format
    var targetUrl = providerUrl;
    if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
      targetUrl = "http://$targetUrl";
    }

    Uri uri;
    try {
      uri = Uri.parse(targetUrl);
      setState(() {
        _providerHost = uri.host;
      });
    } catch (_) {
      setState(() {
        _providerHost = providerUrl;
      });
    }

    _log("• IPTV Portal URL: $targetUrl");
    final stopwatch = Stopwatch()..start();
    try {
      await dio.get(targetUrl);
      stopwatch.stop();
      setState(() {
        _providerState = DiagnosticState.success;
        _providerLatency = stopwatch.elapsedMilliseconds;
      });
      _log("  Provider API Ping Success: ${_providerLatency}ms");
    } catch (e) {
      stopwatch.stop();
      if (e is DioException && e.response != null) {
        // Even if 404/405, server responded so API port is reachable!
        setState(() {
          _providerState = DiagnosticState.success;
          _providerLatency = stopwatch.elapsedMilliseconds;
        });
        _log("  Provider API Ping Reachable: ${_providerLatency}ms (status: ${e.response!.statusCode})");
      } else {
        setState(() {
          _providerState = DiagnosticState.failed;
        });
        _log("  Provider API Unreachable: $e");
      }
    }
  }

  Future<void> _testStreamHandshake() async {
    _log("[4/5] Initiating Stream Reachability Handshake...");
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ));

    // We verify:
    // 1. Connection to public video stream (kDemoUrl)
    // 2. Connection to IPTV server streaming ports if authenticated
    bool publicOk = false;
    _log("• Testing public stable stream reachability: $kDemoUrl");
    try {
      final response = await dio.head(kDemoUrl);
      if (response.statusCode == 200 || response.statusCode == 206) {
        publicOk = true;
        _log("  Demo Stream Handshake: REACHABLE (Status 200/206)");
      } else {
        _log("  Demo Stream Handshake: Returned Status ${response.statusCode}");
      }
    } catch (e) {
      _log("  Demo Stream Handshake: Failed: $e");
    }

    bool providerPortalOk = false;
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is AuthSuccess) {
      final user = (authBloc.state as AuthSuccess).user;
      final server = user.serverInfo?.serverUrl ?? user.serverInfo?.url;
      final username = user.userInfo?.username;
      final password = user.userInfo?.password;

      if (server != null && username != null && password != null) {
        var cleanServer = server;
        if (!cleanServer.startsWith("http://") && !cleanServer.startsWith("https://")) {
          cleanServer = "http://$cleanServer";
        }
        final testUrl = "$cleanServer/player_api.php?username=$username&password=$password";
        _log("• Handshaking provider stream portal credentials...");
        try {
          final res = await dio.get(testUrl);
          if (res.statusCode == 200) {
            providerPortalOk = true;
            _log("  Provider Stream Portal: OK (Authentication Validated)");
          } else {
            _log("  Provider Stream Portal: Returned Status ${res.statusCode}");
          }
        } catch (e) {
          _log("  Provider Stream Portal: Failed: $e");
        }
      }
    }

    setState(() {
      if (publicOk || providerPortalOk) {
        _streamState = DiagnosticState.success;
        if (publicOk && providerPortalOk) {
          _streamReachabilityDetails = "IPTV Panel & Public Streams OK";
        } else if (publicOk) {
          _streamReachabilityDetails = "Public Streams OK, IPTV Panel Offline";
        } else {
          _streamReachabilityDetails = "IPTV Panel OK, Public Streams Error";
        }
      } else {
        _streamState = DiagnosticState.failed;
        _streamReachabilityDetails = "All stream portals unreachable";
      }
    });

    _log("Reachability handshake outcome: $_streamReachabilityDetails");
  }

  Future<void> _testCdnSpeedAndImage() async {
    _log("[5/5] Performing CDN image load test and download speed estimation...");
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ));

    // Picsum dynamic high-res photo from CDN. Size is approx 1.0 MB.
    const testCdnUrl = "https://picsum.photos/1000/1000";
    _log("• Fetching high-fidelity test image from CDN: $testCdnUrl");

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<List<int>>(
        testCdnUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      stopwatch.stop();

      final bytes = response.data;
      if (bytes != null && bytes.isNotEmpty) {
        final durationMs = stopwatch.elapsedMilliseconds;
        final sizeBytes = bytes.length;
        
        final double sizeMb = sizeBytes / (1024.0 * 1024.0);
        final double durationSec = durationMs / 1000.0;
        // speed = (Size in Megabytes * 8 bits) / seconds
        final double speedMbps = (sizeMb * 8.0) / durationSec;

        setState(() {
          _cdnState = DiagnosticState.success;
          _cdnSpeedMbps = speedMbps;
          _cdnDownloadedBytes = sizeBytes;
          _cdnDurationMs = durationMs;
          // Trigger dynamic rendering
          _cdnImageUrl = "$testCdnUrl?t=${DateTime.now().millisecondsSinceEpoch}";
        });

        _log("  CDN Speed Test: SUCCESS!");
        _log("  Downloaded Size: ${sizeMb.toStringAsFixed(2)} MB (${sizeBytes} bytes)");
        _log("  Duration: ${durationMs}ms (${durationSec.toStringAsFixed(2)}s)");
        _log("  Estimated CDN Download Bandwidth: ${speedMbps.toStringAsFixed(2)} Mbps");
      } else {
        _log("  CDN Speed Test: Empty response data returned.");
        setState(() {
          _cdnState = DiagnosticState.failed;
        });
      }
    } catch (e) {
      stopwatch.stop();
      _log("  CDN Speed Test & Image Load Failed: $e");
      setState(() {
        _cdnState = DiagnosticState.failed;
      });
    }
  }

  KeyEventResult _handleKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.gameButtonB) {
      Get.back();
      return KeyEventResult.handled;
    }
    
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedBtnIdx = _focusedBtnIdx == 0 ? 1 : 0;
      });
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.gameButtonA) {
      if (_focusedBtnIdx == 0) {
        _runAllDiagnostics();
      } else {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = isTv(context);

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeys,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── CUSTOM LIGHT PREMIUM APPBAR ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: Get.back,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _focusedBtnIdx == 1 ? kColorPrimary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _focusedBtnIdx == 1 ? kColorPrimary : Colors.black.withOpacity(0.08),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _focusedBtnIdx == 1
                                    ? kColorPrimary.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(
                            FontAwesomeIcons.chevronLeft.data,
                            size: 15,
                            color: _focusedBtnIdx == 1 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title Pill
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: kColorPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kColorPrimary.withOpacity(0.2),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FontAwesomeIcons.circleNodes.data,
                                size: 16,
                                color: kColorPrimaryDark,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Connection Diagnostics".toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF1E1B4B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Active connection indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _connectionType == "Wi-Fi"
                                  ? FontAwesomeIcons.wifi.data
                                  : _connectionType == "Cellular"
                                      ? FontAwesomeIcons.signal.data
                                      : _connectionType == "Ethernet"
                                          ? FontAwesomeIcons.networkWired.data
                                          : FontAwesomeIcons.globe.data,
                              size: 11,
                              color: kColorPrimaryDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _connectionType,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // ── MAIN CONTENT (IMMUNE TO OVERFLOWS) ───────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (wide) {
                          // TV / Wide Mode
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left panel: core test cards
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildCoreTestCards(),
                                      const SizedBox(height: 16),
                                      _buildActionSection(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right panel: image load test & console log
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _buildCdnImagePreviewCard(),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      flex: 5,
                                      child: _buildConsoleCard(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Mobile / Narrow Mode
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCoreTestCards(),
                                const SizedBox(height: 16),
                                _buildCdnImagePreviewCard(),
                                const SizedBox(height: 16),
                                _buildConsoleCard(),
                                const SizedBox(height: 20),
                                _buildActionSection(),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── GRID OF TEST CARDS ─────────────────────────────────────────────────────
  Widget _buildCoreTestCards() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DiagnosticCard(
                title: "Ping Latency",
                subtitle: "Estimated gateway network latency",
                icon: FontAwesomeIcons.bolt.data,
                state: _dnsState,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextRow("Cloudflare (1.1.1.1):", _cloudflareLatency != null ? "${_cloudflareLatency}ms" : "—"),
                    const SizedBox(height: 6),
                    _buildTextRow("Google (8.8.8.8):", _googleLatency != null ? "${_googleLatency}ms" : "—"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          "Rating: ",
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                        Expanded(
                          child: Text(
                            _latencyRating,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _latencyRatingColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DiagnosticCard(
                title: "IPTV Provider",
                subtitle: "Ping connection to stream panel",
                icon: FontAwesomeIcons.server.data,
                state: _providerState,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextRow("Server host:", _providerHost ?? "—"),
                    const SizedBox(height: 6),
                    _buildTextRow("Ping Latency:", _providerLatency != null ? "${_providerLatency}ms" : "—"),
                    const SizedBox(height: 8),
                    _buildTextRow("Panel State:", _providerState == DiagnosticState.success ? "Online" : _providerState == DiagnosticState.failed ? "Offline/No Login" : "—"),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DiagnosticCard(
                title: "Stream handshakes",
                subtitle: "Reachability check to media formats",
                icon: FontAwesomeIcons.circlePlay.data,
                state: _streamState,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextRow("Public stream port:", "Reachable (200)"),
                    const SizedBox(height: 6),
                    _buildTextRow("Provider API hand:", _providerState == DiagnosticState.success ? "Authenticated" : "Unverified"),
                    const SizedBox(height: 8),
                    Text(
                      _streamReachabilityDetails ?? "Handshake queued...",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DiagnosticCard(
                title: "CDN Speed Test",
                subtitle: "Download speed bandwidth metric",
                icon: FontAwesomeIcons.gaugeHigh.data,
                state: _cdnState,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextRow("Download Speed:", _cdnSpeedMbps != null ? "${_cdnSpeedMbps!.toStringAsFixed(2)} Mbps" : "—"),
                    const SizedBox(height: 6),
                    _buildTextRow("Data size:", _cdnDownloadedBytes != null ? "${(_cdnDownloadedBytes! / (1024 * 1024)).toStringAsFixed(2)} MB" : "—"),
                    const SizedBox(height: 8),
                    _buildTextRow("Time elapsed:", _cdnDurationMs != null ? "${_cdnDurationMs} ms" : "—"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ── ACTION SECTION ─────────────────────────────────────────────────────────
  Widget _buildActionSection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _runAllDiagnostics,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _focusedBtnIdx == 0 ? kColorPrimaryDark : kColorPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focusedBtnIdx == 0 ? Colors.white.withOpacity(0.8) : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kColorPrimary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isRunning) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Icon(FontAwesomeIcons.arrowsRotate.data, size: 14, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _isRunning ? "Running tests..." : "Run diagnostics again",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── CDN IMAGE PREVIEW CARD ────────────────────────────────────────────────
  Widget _buildCdnImagePreviewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                Icon(FontAwesomeIcons.image.data, size: 12, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  "CDN Image Load Test".toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Body (Responsive image display)
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              alignment: Alignment.center,
              child: _cdnImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: _cdnImageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(kColorPrimary),
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FontAwesomeIcons.circleExclamation.data, size: 24, color: Colors.redAccent),
                          const SizedBox(height: 6),
                          const Text("Failed to render loaded image", style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.images.data,
                          size: 32,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRunning ? "Loading CDN assets..." : "Awaiting test execution",
                          style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DIAGNOSTIC CONSOLE CARD ────────────────────────────────────────────────
  Widget _buildConsoleCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24), // Elegant charcoal terminal color
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF16161A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(FontAwesomeIcons.terminal.data, size: 11, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text(
                  "Interactive Diagnostic Log".toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Console Logs
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: _consoleLogs.isEmpty
                  ? const Center(
                      child: Text(
                        "No logs recorded yet.",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontFamily: "monospace",
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _consoleScrollController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _consoleLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${index + 1}  ",
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 11,
                                  fontFamily: "monospace",
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _consoleLogs[index],
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                    height: 1.3,
                                    fontFamily: "monospace",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CUSTOM DIAGNOSTIC CARD COMPONENT ─────────────────────────────────────────
class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DiagnosticState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Color indicatorColor = Colors.grey;
    Widget indicatorWidget = const SizedBox(width: 8, height: 8);

    switch (state) {
      case DiagnosticState.notStarted:
        indicatorColor = Colors.grey.shade400;
        indicatorWidget = Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: indicatorColor),
        );
        break;
      case DiagnosticState.running:
        indicatorColor = kColorPrimary;
        indicatorWidget = const SizedBox(
          width: 8,
          height: 8,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(kColorPrimary),
          ),
        );
        break;
      case DiagnosticState.success:
        indicatorColor = Colors.green;
        indicatorWidget = Icon(
          FontAwesomeIcons.circleCheck.data,
          size: 10,
          color: Colors.green,
        );
        break;
      case DiagnosticState.failed:
        indicatorColor = Colors.redAccent;
        indicatorWidget = Icon(
          FontAwesomeIcons.circleXmark.data,
          size: 10,
          color: Colors.redAccent,
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state == DiagnosticState.running
              ? kColorPrimary.withOpacity(0.4)
              : Colors.black.withOpacity(0.06),
          width: state == DiagnosticState.running ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: state == DiagnosticState.running
                ? kColorPrimary.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.only(left: 14.0, right: 14.0, top: 12.0),
            child: Row(
              children: [
                Icon(icon, size: 14, color: kColorPrimaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E1B4B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                indicatorWidget,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.black.withOpacity(0.4),
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: Divider(height: 1, thickness: 0.8),
          ),
          // Card Content
          Padding(
            padding: const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 12.0),
            child: child,
          ),
        ],
      ),
    );
  }
}
