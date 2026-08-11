part of '../screens.dart';

class CastSelectionDialog extends StatefulWidget {
  const CastSelectionDialog({
    super.key,
    required this.controller,
    this.currentCastDevice,
    this.onCastSelected,
  });

  final VlcPlayerController controller;
  final String? currentCastDevice;
  final ValueChanged<String?>? onCastSelected;

  @override
  State<CastSelectionDialog> createState() => _CastSelectionDialogState();
}

class _CastSelectionDialogState extends State<CastSelectionDialog> {
  List<CastDevice> _devices = [];
  bool _isScanning = true;
  bool _showDiagnostics = false;
  final _focusNode = FocusNode();
  int _focusedIdx = 0;

  @override
  void initState() {
    super.initState();
    // TV gate: Cast dialog should never appear on leanback devices.
    if (!supportsCasting()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _startScanning();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    try {
      final devices = await CastMediaService().discoverDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      CastDiagnosticsService.logError('Scan failed: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  int get _totalButtons {
    int count = _devices.length;
    if (widget.currentCastDevice != null && widget.currentCastDevice!.isNotEmpty) {
      count += 1; // Disconnect button
    }
    count += 1; // Close button
    return count;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    final total = _totalButtons;
    if (total == 0) return KeyEventResult.ignored;

    if (k == LogicalKeyboardKey.arrowUp) {
      if (_focusedIdx > 0) {
        setState(() => _focusedIdx--);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      if (_focusedIdx < total - 1) {
        setState(() => _focusedIdx++);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.gameButtonA) {
      _activateFocused();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activateFocused() {
    final hasDisconnect = widget.currentCastDevice != null && widget.currentCastDevice!.isNotEmpty;

    if (_focusedIdx < _devices.length) {
      final device = _devices[_focusedIdx];
      _selectDevice(device);
    } else if (hasDisconnect && _focusedIdx == _devices.length) {
      _disconnectCast();
    } else {
      Get.back();
    }
  }

  Future<void> _selectDevice(CastDevice device) async {
    final streamUrl = widget.controller.dataSource;
    final compat = CastCompatibilityService.checkCompatibility(streamUrl);

    if (compat.status == CastCompatibilityStatus.unsupportedLikely) {
      // Show warning/blocking alert and do not cast
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF131314),
          title: const Text("Casting Unsupported", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(compat.userMessage, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("OK", style: TextStyle(color: Color(0xFFFFC107))),
            ),
          ],
        ),
      );
      return;
    }

    if (compat.status == CastCompatibilityStatus.risky) {
      // Show confirmation dialog before casting
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF131314),
          title: const Text("Risky Stream Format", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(compat.userMessage, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text("Cast Anyway"),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    Get.back();

    Get.snackbar(
      'Casting',
      'Connecting to Cast device...',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xE0101018),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
    );

    try {
      final success = await CastMediaService().connectToDevice(device);
      if (success) {
        // Pause local player playback while casting
        widget.controller.pause();

        // Start casting stream
        await CastMediaService().castStream(
          streamUrl,
          title: "TV Stream",
          streamType: (streamUrl.contains('/movie/') || streamUrl.contains('/series/')) ? 'BUFFERED' : 'LIVE',
        );

        if (widget.onCastSelected != null) {
          widget.onCastSelected!(device.name);
        }

        Get.snackbar(
          'Casting Successful',
          'Streaming to ${device.name}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xE0101018),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          borderRadius: 8,
          margin: const EdgeInsets.all(16),
        );
      } else {
        throw Exception("Connection failed");
      }
    } catch (e) {
      CastDiagnosticsService.logError('Casting failed: $e');
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF131314),
          title: const Text("Casting Failed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text("Failed to stream to Chromecast. Play locally or try another device.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text("OK", style: TextStyle(color: Color(0xFFFFC107))),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _disconnectCast() async {
    try {
      await CastMediaService().disconnect();
      if (widget.onCastSelected != null) {
        widget.onCastSelected!(null);
      }
      Get.back();
      Get.snackbar(
        'Casting Stopped',
        'Returned playback to mobile device.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xE0101018),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final streamUrl = widget.controller.dataSource;
    final compat = CastCompatibilityService.checkCompatibility(streamUrl);

    final hasDisconnect = widget.currentCastDevice != null && widget.currentCastDevice!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 24),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Container(
          width: 380,
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header (Tap or long press triggers diagnostics) ────
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDiagnostics = !_showDiagnostics;
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      _showDiagnostics = !_showDiagnostics;
                    });
                  },
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                kColorPrimary.withOpacity(0.18),
                                kColorPrimaryDark.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: kColorPrimary.withOpacity(0.35),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cast_connected_rounded,
                                size: 12,
                                color: kColorPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'CAST TO TV',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Select Casting Device',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: Get.back,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Diagnostics Overlay (Hidden unless activated) ──────
                if (_showDiagnostics)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    color: const Color(0xFF14141E),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CAST DIAGNOSTICS & TELEMETRY",
                            style: TextStyle(color: Colors.amber.shade400, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Text("Classification: ${compat.status.name}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          Text("MIME Content-Type: ${compat.contentType}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          Text("Headers Required: ${compat.requiresHeaders}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          const Divider(color: Colors.white12),
                          ...CastDiagnosticsService.history.map((log) => Text(
                                log,
                                style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace'),
                              )),
                        ],
                      ),
                    ),
                  ),

                // ── Device List Content ──────────────────────────────
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _isScanning
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(kColorPrimary),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Searching for local Cast devices...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Ensure your TV and phone are on the same Wi-Fi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _devices.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cast_rounded, size: 28, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No devices found',
                                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap header for diagnostics / connection logs',
                                    style: TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _devices.length,
                              itemBuilder: (_, i) {
                                final device = _devices[i];
                                final isFocused = _focusedIdx == i;
                                final isCurrent = widget.currentCastDevice == device.name;

                                return GestureDetector(
                                  onTap: () => _selectDevice(device),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? kColorPrimary.withOpacity(0.25)
                                          : isCurrent
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isFocused
                                            ? kColorFocus
                                            : isCurrent
                                                ? kColorPrimary.withOpacity(0.4)
                                                : Colors.white.withOpacity(0.05),
                                        width: isFocused ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.tv_rounded,
                                          size: 14,
                                          color: isFocused
                                              ? Colors.white
                                              : isCurrent
                                                  ? kColorPrimary
                                                  : Colors.white54,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            device.name,
                                            style: TextStyle(
                                              color: isFocused ? Colors.white : Colors.white70,
                                              fontSize: 13,
                                              fontWeight: isFocused || isCurrent
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 14,
                                            color: kColorPrimary,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // ── Footer buttons ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.06)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasDisconnect) ...[
                        _CastDialogActionBtn(
                          icon: Icons.link_off_rounded,
                          label: 'Disconnect',
                          isFocused: _focusedIdx == _devices.length,
                          isPrimary: false,
                          onTap: _disconnectCast,
                        ),
                        const SizedBox(width: 10),
                      ],
                      _CastDialogActionBtn(
                        icon: Icons.close_rounded,
                        label: 'Close',
                        isFocused: _focusedIdx == (hasDisconnect ? _devices.length + 1 : _devices.length),
                        isPrimary: true,
                        onTap: Get.back,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CastDialogActionBtn extends StatelessWidget {
  const _CastDialogActionBtn({
    required this.icon,
    required this.label,
    required this.isFocused,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isFocused;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? kColorPrimary : Colors.white38;
    final focusColor = isPrimary ? kColorFocus : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isFocused
              ? (isPrimary ? kColorPrimary : Colors.white.withOpacity(0.12))
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? focusColor : Colors.white.withOpacity(0.08),
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: focusColor.withOpacity(0.25), blurRadius: 6)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isFocused ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isFocused ? Colors.white : color,
                fontSize: 11,
                fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
