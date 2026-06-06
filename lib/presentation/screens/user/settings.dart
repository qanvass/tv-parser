part of '../screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // panel: 0 = appbar, 1 = actions
  bool _appbarActive = false;
  int _appbarIdx = 0;
  static const int _appbarBtnMax = 0;

  // focused action button index (0=Refresh, 1=Diagnostics, 2=Quality, 3=Location suggestions, 4=Change market, 5=Reset suggestions, 6=Add User, 7=Logout)
  int _actionIdx = 0;
  bool _actionPanelActive = false;

  final _navFocus = FocusNode();
  String _currentQualityMode = "Balanced";
  bool _locationPersonalizationEnabled = false;
  String _activeMarketName = "None";

  @override
  void initState() {
    super.initState();
    final box = GetStorage("preferences");
    _currentQualityMode = box.read("stream_quality") ?? "Balanced";
    final profile = UserPreferenceProfile.load();
    _locationPersonalizationEnabled = profile.locationFeatureEnabled;
    final activeMarket = LocalMarketService.getActiveMarket();
    _activeMarketName = activeMarket?.displayName ?? "None";
  }

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // ── Appbar ─────────────────────────────────────────────────────────────
    if (_appbarActive) {
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() { _appbarActive = false; _actionPanelActive = true; _actionIdx = 0; });
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        if (_appbarIdx > 0) setState(() => _appbarIdx--);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        if (_appbarIdx < _appbarBtnMax) setState(() => _appbarIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        if (_appbarIdx == 0) Get.back();
      } else if (k == LogicalKeyboardKey.escape) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    // ── Action buttons ─────────────────────────────────────────────────────
    if (_actionPanelActive) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_actionIdx > 0) {
          setState(() => _actionIdx--);
        } else {
          setState(() { _actionPanelActive = false; _appbarActive = true; _appbarIdx = 0; });
        }
      } else if (k == LogicalKeyboardKey.arrowDown) {
        final maxIdx = isTvDevice() ? 7 : 8;
        if (_actionIdx < maxIdx) setState(() => _actionIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _handleAction(_actionIdx);
      } else if (k == LogicalKeyboardKey.escape) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    // initial entry
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      setState(() { _actionPanelActive = true; _actionIdx = 0; });
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) { Get.back(); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  void _handleAction(int idx) {
    int effectiveIdx = idx;
    if (!isTvDevice() && idx >= 6) {
      if (idx == 6) {
        final current = OrientationGuard.allowMobileLandscape;
        OrientationGuard.setAllowLandscape(!current);
        setState(() {});
        return;
      }
      effectiveIdx = idx - 1;
    }

    switch (effectiveIdx) {
      case 0:
        context.read<LiveCatyBloc>().add(GetLiveCategories());
        context.read<MovieCatyBloc>().add(GetMovieCategories());
        context.read<SeriesCatyBloc>().add(GetSeriesCategories());
        Get.back();
        break;
      case 1:
        Get.toNamed(screenConnectionTest);
        break;
      case 2:
        _showQualityModeSelection();
        break;
      case 3:
        setState(() {
          _locationPersonalizationEnabled = !_locationPersonalizationEnabled;
        });
        LocationPreferenceService.setLocationFeatureEnabled(_locationPersonalizationEnabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Local personalization ${_locationPersonalizationEnabled ? 'enabled' : 'disabled'}"),
            backgroundColor: Colors.amber.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 4:
        _showMarketSelectionDialog();
        break;
      case 5:
        LocationPreferenceService.resetLocationPreferences();
        LocalMarketService.resetActiveMarket();
        setState(() {
          _activeMarketName = "None";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Location preferences reset. Onboarding will display on next run."),
            backgroundColor: Colors.amber.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case 6:
        context.read<AuthBloc>().add(AuthLogOut());
        Get.offAllNamed('/');
        break;
      case 7:
        context.read<SettingsCubit>().updateStatusAccount(false);
        context.read<AuthBloc>().add(AuthLogOut());
        Get.offAllNamed('/');
        Get.reload();
        break;
    }
  }

  void _showMarketSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Change Local TV Market",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: LocalMarketService.supportedMarkets.length,
              itemBuilder: (context, index) {
                final market = LocalMarketService.supportedMarkets[index];
                final isSelected = market.displayName == _activeMarketName;
                return ListTile(
                  title: Text(
                    market.displayName,
                    style: TextStyle(color: isSelected ? Colors.amber : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.amber) : null,
                  onTap: () {
                    LocalMarketService.setActiveMarket(market.id);
                    setState(() {
                      _activeMarketName = market.displayName;
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Market changed to ${market.displayName}"),
                        backgroundColor: Colors.amber.shade900,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _navFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Ink(
          decoration: kDecorBackground,
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              final user = authState is AuthSuccess ? authState.user : null;
              final userInfo = user?.userInfo;
              final serverInfo = user?.serverInfo;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 56,
                      child: IptvAppBar(
                        title: 'Settings',
                        icon: FontAwesomeIcons.gear.data,
                        onBack: Get.back,
                        focusedIndex: _appbarActive ? _appbarIdx : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Info panels ──────────────────────────────────
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Subscription card
                                _InfoCard(
                                  icon: FontAwesomeIcons.idCard.data,
                                  title: 'Subscription',
                                  children: [
                                    _InfoRow(
                                      label: 'Username',
                                      value: userInfo?.username ?? '—',
                                      icon: FontAwesomeIcons.user.data,
                                    ),
                                    SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Password',
                                      value: userInfo?.password != null
                                          ? '••••••••'
                                          : '—',
                                      icon: FontAwesomeIcons.lock.data,
                                    ),
                                    SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Server',
                                      value: serverInfo?.serverUrl ?? '—',
                                      icon: FontAwesomeIcons.server.data,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                // Status card
                                _InfoCard(
                                  icon: FontAwesomeIcons.circleInfo.data,
                                  title: 'Account Status',
                                  children: [
                                    _InfoRow(
                                      label: 'Date',
                                      value: dateNowWelcome(),
                                      icon: FontAwesomeIcons.calendarDay.data,
                                    ),
                                    SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Expires',
                                      value: expirationDate(userInfo?.expDate),
                                      icon: FontAwesomeIcons.hourglass.data,
                                      valueColor: _expiryColor(userInfo?.expDate),
                                    ),
                                    SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Status',
                                      value: userInfo?.status ?? '—',
                                      icon: FontAwesomeIcons.circleCheck.data,
                                      valueColor: userInfo?.status == 'Active'
                                          ? Colors.greenAccent
                                          : kColorHint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Stream Quality Mode card
                                _InfoCard(
                                  icon: FontAwesomeIcons.sliders.data,
                                  title: 'Stream Quality Mode',
                                  children: [
                                    _InfoRow(
                                      label: 'Active Profile',
                                      value: _currentQualityMode,
                                      icon: FontAwesomeIcons.gaugeHigh.data,
                                      valueColor: Colors.amberAccent,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _getQualityModeDescription(_currentQualityMode),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Local TV Market card
                                _InfoCard(
                                  icon: FontAwesomeIcons.locationDot.data,
                                  title: 'Local TV Market',
                                  children: [
                                    _InfoRow(
                                      label: 'Current Market',
                                      value: _activeMarketName,
                                      icon: FontAwesomeIcons.mapPin.data,
                                      valueColor: Colors.amberAccent,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Suggestions: ${_locationPersonalizationEnabled ? 'Enabled' : 'Disabled'}",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        Container(width: 1, color: kColorCardLight),

                        // ── Actions ──────────────────────────────────────
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'ACTIONS',
                                    style: Get.textTheme.bodySmall!.copyWith(
                                      color: kColorHint,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.arrowsRotate.data,
                                  label: 'Refresh All Data',
                                  subtitle: 'Reload channels & categories',
                                  isFocused: _actionPanelActive && _actionIdx == 0,
                                  onTap: () => _handleAction(0),
                                ),
                                SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.circleNodes.data,
                                  label: 'Connection Diagnostics',
                                  subtitle: 'Verify latency, streams, speed & CDN',
                                  isFocused: _actionPanelActive && _actionIdx == 1,
                                  onTap: () => _handleAction(1),
                                ),
                                SizedBox(height: 8),
                                 _SettingsAction(
                                  icon: FontAwesomeIcons.sliders.data,
                                  label: 'Change Quality Mode',
                                  subtitle: 'Select buffer sizes for streams',
                                  isFocused: _actionPanelActive && _actionIdx == 2,
                                  onTap: () => _handleAction(2),
                                ),
                                const SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.locationDot.data,
                                  label: 'Local Personalization',
                                  subtitle: _locationPersonalizationEnabled
                                      ? 'Using location to recommend local channels'
                                      : 'Location suggestions are disabled',
                                  isFocused: _actionPanelActive && _actionIdx == 3,
                                  onTap: () => _handleAction(3),
                                  trailing: Switch(
                                    value: _locationPersonalizationEnabled,
                                    activeColor: Colors.amber,
                                    focusNode: FocusNode(canRequestFocus: false),
                                    onChanged: (val) => _handleAction(3),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.map.data,
                                  label: 'Change Local TV Market',
                                  subtitle: 'Manually override detected market',
                                  isFocused: _actionPanelActive && _actionIdx == 4,
                                  onTap: () => _handleAction(4),
                                ),
                                const SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.rotateLeft.data,
                                  label: 'Reset Location Preferences',
                                  subtitle: 'Reset onboarding and permission cache',
                                  isFocused: _actionPanelActive && _actionIdx == 5,
                                  onTap: () => _handleAction(5),
                                ),
                                const SizedBox(height: 8),
                                if (!isTvDevice()) ...[
                                  _SettingsAction(
                                    icon: FontAwesomeIcons.mobileScreenButton.data,
                                    label: 'Allow Landscape Mode',
                                    subtitle: 'Let TV Parser rotate into landscape while browsing. The app will still start in portrait.',
                                    isFocused: _actionPanelActive && _actionIdx == 6,
                                    onTap: () => _handleAction(6),
                                    trailing: Switch(
                                      value: OrientationGuard.allowMobileLandscape,
                                      activeColor: Colors.amber,
                                      focusNode: FocusNode(canRequestFocus: false),
                                      onChanged: (val) => _handleAction(6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                _SettingsAction(
                                  icon: FontAwesomeIcons.userPlus.data,
                                  label: 'Add New Account',
                                  subtitle: 'Switch to a different account',
                                  isFocused: _actionPanelActive && _actionIdx == (isTvDevice() ? 6 : 7),
                                  onTap: () => _handleAction(isTvDevice() ? 6 : 7),
                                ),
                                const SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.rightFromBracket.data,
                                  label: 'Log Out',
                                  subtitle: 'Sign out and clear session',
                                  isFocused: _actionPanelActive && _actionIdx == (isTvDevice() ? 7 : 8),
                                  isDestructive: true,
                                  onTap: () => _handleAction(isTvDevice() ? 7 : 8),
                                ),
                                const Spacer(),
                                // Footer
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Created by ',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          fontSize: 11,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => launchUrlString(
                                          'https://mouadzizi.me',
                                          mode: LaunchMode.externalApplication,
                                        ),
                                        child: Text(
                                          '@Azul Mouad',
                                          style: TextStyle(
                                            color: kColorPrimary.withValues(alpha: 0.8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _expiryColor(String? expDate) {
    if (expDate == null) return kColorHint;
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(expDate) * 1000);
      final diff = date.difference(DateTime.now()).inDays;
      if (diff < 7) return Colors.redAccent;
      if (diff < 30) return Colors.orangeAccent;
      return Colors.greenAccent;
    } catch (_) {
      return kColorHint;
    }
  }

  String _getQualityModeDescription(String mode) {
    switch (mode) {
      case "Fast Start":
        return "Buffers: Live 1.5s / VOD 4.0s. Starts streams extremely fast, best for high-speed connections.";
      case "Smooth Playback":
        return "Buffers: Live 3.5s / VOD 8.0s. High buffer sizes to prevent stuttering on unstable networks.";
      case "Balanced":
      default:
        return "Buffers: Live 2.5s / VOD 6.0s. Optimizes speed and playback stability (Recommended).";
    }
  }

  void _showQualityModeSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              const Text(
                "Stream Quality Mode",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQualityOption("Fast Start", "Live 1500ms / VOD 4000ms"),
              const SizedBox(height: 10),
              _buildQualityOption("Balanced", "Live 2500ms / VOD 6000ms (Recommended)"),
              const SizedBox(height: 10),
              _buildQualityOption("Smooth Playback", "Live 3500ms / VOD 8000ms"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQualityOption(String mode, String subtitle) {
    final isSelected = _currentQualityMode == mode;
    return InkWell(
      onTap: () {
        final box = GetStorage("preferences");
        box.write("stream_quality", mode);
        setState(() {
          _currentQualityMode = mode;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Quality profile set to $mode"),
            backgroundColor: Colors.amber.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.amber : Colors.white30,
              size: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kColorCardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kColorPrimary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 13, color: kColorPrimary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: kColorPrimary.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Settings action button ────────────────────────────────────────────────────

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isFocused,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isFocused;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? Colors.redAccent : kColorPrimary;
    final focusColor = isDestructive ? Colors.redAccent : kColorFocus;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isFocused
              ? accent.withValues(alpha: 0.18)
              : kColorCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFocused
                ? focusColor
                : Colors.white.withValues(alpha: 0.07),
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: focusColor.withValues(alpha: 0.25), blurRadius: 10)]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isFocused
                    ? accent.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 14,
                color: isFocused ? accent : Colors.white38,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isFocused ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(
              FontAwesomeIcons.chevronRight.data,
              size: 11,
              color: isFocused ? accent : Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
