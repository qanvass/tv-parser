part of '../screens.dart';

enum _TvSettingsSection {
  sources,
  playback,
  local,
  diagnostics,
  account,
  about,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _appbarActive = false;
  int _appbarIdx = 0;
  static const int _appbarBtnMax = 0;

  // Mobile flat action list
  int _actionIdx = 0;
  bool _actionPanelActive = false;

  // TV sectioned IA
  int _sectionIdx = 0;
  int _detailIdx = 0;
  bool _sectionPanelActive = true;
  bool _detailPanelActive = false;

  final _navFocus = FocusNode();
  String _currentQualityMode = "Balanced";
  bool _locationPersonalizationEnabled = false;
  String _activeMarketName = "None";
  String _subtitleSize = "Medium";
  bool _hideAdult = true;
  List<SavedAccount> _savedAccounts = [];

  static const _tvSections = <_TvSettingsSection>[
    _TvSettingsSection.sources,
    _TvSettingsSection.playback,
    _TvSettingsSection.local,
    _TvSettingsSection.diagnostics,
    _TvSettingsSection.account,
    _TvSettingsSection.about,
  ];

  @override
  void initState() {
    super.initState();
    final box = GetStorage("preferences");
    _currentQualityMode = box.read("stream_quality") ?? "Balanced";
    _subtitleSize = box.read("subtitle_size") ?? "Medium";
    final profile = UserPreferenceProfile.load();
    _locationPersonalizationEnabled = profile.locationFeatureEnabled;
    _hideAdult = profile.hideAdultContent;
    final activeMarket = LocalMarketService.getActiveMarket();
    _activeMarketName = activeMarket?.displayName ?? "None";
    _savedAccounts = SavedAccountsService.list();
  }

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navFocus.requestFocus();
    });
  }

  String _sectionLabel(_TvSettingsSection s) {
    switch (s) {
      case _TvSettingsSection.sources:
        return 'Sources';
      case _TvSettingsSection.playback:
        return 'Playback';
      case _TvSettingsSection.local:
        return 'Local';
      case _TvSettingsSection.diagnostics:
        return 'Diagnostics';
      case _TvSettingsSection.account:
        return 'Account';
      case _TvSettingsSection.about:
        return 'About';
    }
  }

  IconData _sectionIcon(_TvSettingsSection s) {
    switch (s) {
      case _TvSettingsSection.sources:
        return FontAwesomeIcons.server.data;
      case _TvSettingsSection.playback:
        return FontAwesomeIcons.sliders.data;
      case _TvSettingsSection.local:
        return FontAwesomeIcons.locationDot.data;
      case _TvSettingsSection.diagnostics:
        return FontAwesomeIcons.circleNodes.data;
      case _TvSettingsSection.account:
        return FontAwesomeIcons.user.data;
      case _TvSettingsSection.about:
        return FontAwesomeIcons.circleInfo.data;
    }
  }

  int _detailCountFor(_TvSettingsSection section) {
    switch (section) {
      case _TvSettingsSection.sources:
        return 2 + _savedAccounts.length; // refresh + add + saved
      case _TvSettingsSection.playback:
        return 1; // quality
      case _TvSettingsSection.local:
        return 3; // toggle + market + reset
      case _TvSettingsSection.diagnostics:
        return 1;
      case _TvSettingsSection.account:
        return 2; // add / logout
      case _TvSettingsSection.about:
        return 3; // parental stub + subtitle stub + brand
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (_appbarActive) {
      if (k == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _appbarActive = false;
          if (isTvDevice()) {
            _sectionPanelActive = true;
            _detailPanelActive = false;
            _sectionIdx = 0;
          } else {
            _actionPanelActive = true;
            _actionIdx = 0;
          }
        });
      } else if (k == LogicalKeyboardKey.arrowLeft) {
        if (_appbarIdx > 0) setState(() => _appbarIdx--);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        if (_appbarIdx < _appbarBtnMax) setState(() => _appbarIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        if (_appbarIdx == 0) Get.back();
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.goBack) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    if (isTvDevice()) {
      return _onTvKey(k);
    }
    return _onMobileKey(k);
  }

  KeyEventResult _onTvKey(LogicalKeyboardKey k) {
    final section = _tvSections[_sectionIdx];
    final detailMax = _detailCountFor(section) - 1;

    if (_sectionPanelActive) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_sectionIdx > 0) {
          setState(() => _sectionIdx--);
        } else {
          setState(() {
            _sectionPanelActive = false;
            _appbarActive = true;
            _appbarIdx = 0;
          });
        }
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_sectionIdx < _tvSections.length - 1) {
          setState(() => _sectionIdx++);
        }
      } else if (k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        setState(() {
          _sectionPanelActive = false;
          _detailPanelActive = true;
          _detailIdx = 0;
        });
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.goBack) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    if (_detailPanelActive) {
      if (k == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          _detailPanelActive = false;
          _sectionPanelActive = true;
        });
      } else if (k == LogicalKeyboardKey.arrowUp) {
        if (_detailIdx > 0) {
          setState(() => _detailIdx--);
        } else {
          setState(() {
            _detailPanelActive = false;
            _appbarActive = true;
          });
        }
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (_detailIdx < detailMax) setState(() => _detailIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _handleTvDetailAction(section, _detailIdx);
      } else if (k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.goBack) {
        setState(() {
          _detailPanelActive = false;
          _sectionPanelActive = true;
        });
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _sectionPanelActive = true;
        _sectionIdx = 0;
      });
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onMobileKey(LogicalKeyboardKey k) {
    if (_actionPanelActive) {
      if (k == LogicalKeyboardKey.arrowUp) {
        if (_actionIdx > 0) {
          setState(() => _actionIdx--);
        } else {
          setState(() {
            _actionPanelActive = false;
            _appbarActive = true;
            _appbarIdx = 0;
          });
        }
      } else if (k == LogicalKeyboardKey.arrowDown) {
        final maxIdx = 8;
        if (_actionIdx < maxIdx) setState(() => _actionIdx++);
      } else if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.gameButtonA) {
        _handleMobileAction(_actionIdx);
      } else if (k == LogicalKeyboardKey.escape) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _actionPanelActive = true;
        _actionIdx = 0;
      });
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Get.back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleTvDetailAction(_TvSettingsSection section, int idx) {
    switch (section) {
      case _TvSettingsSection.sources:
        if (idx == 0) {
          context.read<LiveCatyBloc>().add(GetLiveCategories());
          context.read<MovieCatyBloc>().add(GetMovieCategories());
          context.read<SeriesCatyBloc>().add(GetSeriesCategories());
          Get.back();
        } else if (idx == 1) {
          context.read<AuthBloc>().add(AuthLogOut());
          Get.offAllNamed('/');
        } else {
          final accountIdx = idx - 2;
          if (accountIdx >= 0 && accountIdx < _savedAccounts.length) {
            _switchToSavedAccount(_savedAccounts[accountIdx]);
          }
        }
        break;
      case _TvSettingsSection.playback:
        _showQualityModeSelection();
        break;
      case _TvSettingsSection.local:
        if (idx == 0) {
          setState(() {
            _locationPersonalizationEnabled = !_locationPersonalizationEnabled;
          });
          LocationPreferenceService.setLocationFeatureEnabled(
            _locationPersonalizationEnabled,
          );
          _snack(
            "Local personalization ${_locationPersonalizationEnabled ? 'enabled' : 'disabled'}",
          );
        } else if (idx == 1) {
          _showMarketSelectionDialog();
        } else {
          LocationPreferenceService.resetLocationPreferences();
          LocalMarketService.resetActiveMarket();
          setState(() => _activeMarketName = "None");
          _snack("Location preferences reset.");
        }
        break;
      case _TvSettingsSection.diagnostics:
        Get.toNamed(screenConnectionTest)?.then((_) => _restoreFocus());
        break;
      case _TvSettingsSection.account:
        if (idx == 0) {
          context.read<AuthBloc>().add(AuthLogOut());
          Get.offAllNamed('/');
        } else {
          context.read<SettingsCubit>().updateStatusAccount(false);
          context.read<AuthBloc>().add(AuthLogOut());
          Get.offAllNamed('/');
          Get.reload();
        }
        break;
      case _TvSettingsSection.about:
        if (idx == 0) {
          _showParentalPinStub();
        } else if (idx == 1) {
          _cycleSubtitleSize();
        } else {
          _snack("TV Parser · tvparser.com");
        }
        break;
    }
  }

  void _handleMobileAction(int idx) {
    int effectiveIdx = idx;
    if (idx >= 6) {
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
        LocationPreferenceService.setLocationFeatureEnabled(
          _locationPersonalizationEnabled,
        );
        _snack(
          "Local personalization ${_locationPersonalizationEnabled ? 'enabled' : 'disabled'}",
        );
        break;
      case 4:
        _showMarketSelectionDialog();
        break;
      case 5:
        LocationPreferenceService.resetLocationPreferences();
        LocalMarketService.resetActiveMarket();
        setState(() => _activeMarketName = "None");
        _snack("Location preferences reset.");
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

  Future<void> _switchToSavedAccount(SavedAccount account) async {
    context.read<AuthBloc>().add(AuthLogOut());
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    if (account.isM3u && account.playlistUrl != null) {
      context.read<AuthBloc>().add(AuthLoadM3u(account.playlistUrl!));
    } else {
      context.read<AuthBloc>().add(
            AuthRegister(account.username, account.password, account.domain),
          );
    }
    Get.offAllNamed('/');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.amber.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _cycleSubtitleSize() {
    const sizes = ['Small', 'Medium', 'Large'];
    final next = sizes[(_subtitleSize == 'Small'
            ? 1
            : _subtitleSize == 'Medium'
                ? 2
                : 0)];
    final box = GetStorage("preferences");
    box.write("subtitle_size", next);
    setState(() => _subtitleSize = next);
    _snack("Subtitle size: $next (applies when subtitles are available)");
    _restoreFocus();
  }

  void _showParentalPinStub() {
    final box = GetStorage("preferences");
    final controller = TextEditingController(
      text: box.read("parental_pin")?.toString() ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Parental PIN",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Set a PIN used to unlock restricted playlist categories. Leave blank to clear.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "4–6 digits",
                  hintStyle: TextStyle(color: Colors.white38),
                  counterStyle: TextStyle(color: Colors.white30),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Hide restricted categories by default",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                value: _hideAdult,
                activeColor: Colors.amber,
                onChanged: (v) {
                  setState(() => _hideAdult = v);
                  final profile = UserPreferenceProfile.load();
                  profile.copyWith(hideAdultContent: v).save();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _restoreFocus();
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (pin.isEmpty) {
                  box.remove("parental_pin");
                } else {
                  box.write("parental_pin", pin);
                }
                Navigator.of(ctx).pop();
                _snack(pin.isEmpty ? "Parental PIN cleared" : "Parental PIN saved");
                _restoreFocus();
              },
              child: const Text(
                "Save",
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) => _restoreFocus());
  }

  void _showMarketSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Change Local TV Market",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
                    style: TextStyle(
                      color: isSelected ? Colors.amber : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.amber)
                      : null,
                  onTap: () {
                    LocalMarketService.setActiveMarket(market.id);
                    setState(() {
                      _activeMarketName = market.displayName;
                    });
                    Navigator.of(context).pop();
                    _snack("Market changed to ${market.displayName}");
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Close",
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) => _restoreFocus());
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
                    child: isTvDevice()
                        ? _buildTvBody(userInfo, serverInfo)
                        : _buildMobileBody(userInfo, serverInfo),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTvBody(dynamic userInfo, dynamic serverInfo) {
    final section = _tvSections[_sectionIdx];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),
            itemCount: _tvSections.length,
            itemBuilder: (context, i) {
              final s = _tvSections[i];
              final focused = _sectionPanelActive && _sectionIdx == i;
              final selected = _sectionIdx == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SettingsAction(
                  icon: _sectionIcon(s),
                  label: _sectionLabel(s),
                  subtitle: selected ? 'Selected' : 'Open section',
                  isFocused: focused,
                  onTap: () {
                    setState(() {
                      _sectionIdx = i;
                      _sectionPanelActive = false;
                      _detailPanelActive = true;
                      _detailIdx = 0;
                    });
                  },
                ),
              );
            },
          ),
        ),
        Container(width: 1, color: kColorCardLight),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildTvDetail(section, userInfo, serverInfo),
          ),
        ),
      ],
    );
  }

  Widget _buildTvDetail(
    _TvSettingsSection section,
    dynamic userInfo,
    dynamic serverInfo,
  ) {
    switch (section) {
      case _TvSettingsSection.sources:
        return ListView(
          children: [
            _sectionTitle('Sources'),
            _SettingsAction(
              icon: FontAwesomeIcons.arrowsRotate.data,
              label: 'Refresh Playlist Data',
              subtitle: 'Reload channels & categories',
              isFocused: _detailPanelActive && _detailIdx == 0,
              onTap: () => _handleTvDetailAction(section, 0),
            ),
            const SizedBox(height: 8),
            _SettingsAction(
              icon: FontAwesomeIcons.userPlus.data,
              label: 'Add / Switch Account',
              subtitle: 'Sign in with another source',
              isFocused: _detailPanelActive && _detailIdx == 1,
              onTap: () => _handleTvDetailAction(section, 1),
            ),
            if (_savedAccounts.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'SAVED LOGINS',
                style: Get.textTheme.bodySmall!.copyWith(
                  color: kColorHint,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _savedAccounts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SettingsAction(
                    icon: _savedAccounts[i].isM3u
                        ? FontAwesomeIcons.fileLines.data
                        : FontAwesomeIcons.server.data,
                    label: _savedAccounts[i].label,
                    subtitle: _savedAccounts[i].isM3u
                        ? 'M3U playlist'
                        : _savedAccounts[i].domain,
                    isFocused: _detailPanelActive && _detailIdx == i + 2,
                    onTap: () => _handleTvDetailAction(section, i + 2),
                  ),
                ),
            ],
          ],
        );
      case _TvSettingsSection.playback:
        return ListView(
          children: [
            _sectionTitle('Playback'),
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
            _SettingsAction(
              icon: FontAwesomeIcons.sliders.data,
              label: 'Change Quality Mode',
              subtitle: 'Fast Start · Balanced · Smooth Playback',
              isFocused: _detailPanelActive && _detailIdx == 0,
              onTap: () => _handleTvDetailAction(section, 0),
            ),
          ],
        );
      case _TvSettingsSection.local:
        return ListView(
          children: [
            _sectionTitle('Local / Personalization'),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingsAction(
              icon: FontAwesomeIcons.locationDot.data,
              label: 'Local Personalization',
              subtitle: _locationPersonalizationEnabled
                  ? 'Using location for local suggestions'
                  : 'Location suggestions are disabled',
              isFocused: _detailPanelActive && _detailIdx == 0,
              onTap: () => _handleTvDetailAction(section, 0),
              trailing: Switch(
                value: _locationPersonalizationEnabled,
                activeColor: Colors.amber,
                focusNode: FocusNode(canRequestFocus: false),
                onChanged: (_) => _handleTvDetailAction(section, 0),
              ),
            ),
            const SizedBox(height: 8),
            _SettingsAction(
              icon: FontAwesomeIcons.map.data,
              label: 'Change Local TV Market',
              subtitle: 'Manually override detected market',
              isFocused: _detailPanelActive && _detailIdx == 1,
              onTap: () => _handleTvDetailAction(section, 1),
            ),
            const SizedBox(height: 8),
            _SettingsAction(
              icon: FontAwesomeIcons.rotateLeft.data,
              label: 'Reset Location Preferences',
              subtitle: 'Reset onboarding and permission cache',
              isFocused: _detailPanelActive && _detailIdx == 2,
              onTap: () => _handleTvDetailAction(section, 2),
            ),
          ],
        );
      case _TvSettingsSection.diagnostics:
        return ListView(
          children: [
            _sectionTitle('Diagnostics'),
            _SettingsAction(
              icon: FontAwesomeIcons.circleNodes.data,
              label: 'Connection Diagnostics',
              subtitle: 'Verify latency, streams, speed & CDN',
              isFocused: _detailPanelActive && _detailIdx == 0,
              onTap: () => _handleTvDetailAction(section, 0),
            ),
          ],
        );
      case _TvSettingsSection.account:
        return ListView(
          children: [
            _sectionTitle('Account'),
            _InfoCard(
              icon: FontAwesomeIcons.idCard.data,
              title: 'Subscription',
              children: [
                _InfoRow(
                  label: 'Username',
                  value: userInfo?.username ?? '—',
                  icon: FontAwesomeIcons.user.data,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Server',
                  value: serverInfo?.serverUrl ?? '—',
                  icon: FontAwesomeIcons.server.data,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Expires',
                  value: expirationDate(userInfo?.expDate),
                  icon: FontAwesomeIcons.hourglass.data,
                  valueColor: _expiryColor(userInfo?.expDate),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingsAction(
              icon: FontAwesomeIcons.userPlus.data,
              label: 'Add New Account',
              subtitle: 'Switch to a different account',
              isFocused: _detailPanelActive && _detailIdx == 0,
              onTap: () => _handleTvDetailAction(section, 0),
            ),
            const SizedBox(height: 8),
            _SettingsAction(
              icon: FontAwesomeIcons.rightFromBracket.data,
              label: 'Log Out',
              subtitle: 'Sign out and clear session',
              isFocused: _detailPanelActive && _detailIdx == 1,
              isDestructive: true,
              onTap: () => _handleTvDetailAction(section, 1),
            ),
          ],
        );
      case _TvSettingsSection.about:
        return ListView(
          children: [
            _sectionTitle('About'),
            _SettingsAction(
              icon: FontAwesomeIcons.lock.data,
              label: 'Parental PIN',
              subtitle: 'Manage restricted-content unlock PIN',
              isFocused: _detailPanelActive && _detailIdx == 0,
              onTap: () => _handleTvDetailAction(section, 0),
            ),
            const SizedBox(height: 8),
            _SettingsAction(
              icon: FontAwesomeIcons.closedCaptioning.data,
              label: 'Subtitle Size',
              subtitle: 'Current: $_subtitleSize',
              isFocused: _detailPanelActive && _detailIdx == 1,
              onTap: () => _handleTvDetailAction(section, 1),
            ),
            const SizedBox(height: 8),
            _SettingsAction(
              icon: FontAwesomeIcons.circleInfo.data,
              label: 'TV Parser',
              subtitle: 'Neutral media player · tvparser.com',
              isFocused: _detailPanelActive && _detailIdx == 2,
              onTap: () => _handleTvDetailAction(section, 2),
            ),
          ],
        );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title.toUpperCase(),
        style: Get.textTheme.bodySmall!.copyWith(
          color: kColorHint,
          letterSpacing: 1.1,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMobileBody(dynamic userInfo, dynamic serverInfo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                      value: userInfo?.password != null ? '••••••••' : '—',
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
                  onTap: () => _handleMobileAction(0),
                ),
                SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.circleNodes.data,
                  label: 'Connection Diagnostics',
                  subtitle: 'Verify latency, streams, speed & CDN',
                  isFocused: _actionPanelActive && _actionIdx == 1,
                  onTap: () => _handleMobileAction(1),
                ),
                SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.sliders.data,
                  label: 'Change Quality Mode',
                  subtitle: 'Select buffer sizes for streams',
                  isFocused: _actionPanelActive && _actionIdx == 2,
                  onTap: () => _handleMobileAction(2),
                ),
                const SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.locationDot.data,
                  label: 'Local Personalization',
                  subtitle: _locationPersonalizationEnabled
                      ? 'Using location to recommend local channels'
                      : 'Location suggestions are disabled',
                  isFocused: _actionPanelActive && _actionIdx == 3,
                  onTap: () => _handleMobileAction(3),
                  trailing: Switch(
                    value: _locationPersonalizationEnabled,
                    activeColor: Colors.amber,
                    focusNode: FocusNode(canRequestFocus: false),
                    onChanged: (val) => _handleMobileAction(3),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.map.data,
                  label: 'Change Local TV Market',
                  subtitle: 'Manually override detected market',
                  isFocused: _actionPanelActive && _actionIdx == 4,
                  onTap: () => _handleMobileAction(4),
                ),
                const SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.rotateLeft.data,
                  label: 'Reset Location Preferences',
                  subtitle: 'Reset onboarding and permission cache',
                  isFocused: _actionPanelActive && _actionIdx == 5,
                  onTap: () => _handleMobileAction(5),
                ),
                const SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.mobileScreenButton.data,
                  label: 'Allow Landscape Mode',
                  subtitle:
                      'Let TV Parser rotate into landscape while browsing. The app will still start in portrait.',
                  isFocused: _actionPanelActive && _actionIdx == 6,
                  onTap: () => _handleMobileAction(6),
                  trailing: Switch(
                    value: OrientationGuard.allowMobileLandscape,
                    activeColor: Colors.amber,
                    focusNode: FocusNode(canRequestFocus: false),
                    onChanged: (val) => _handleMobileAction(6),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.userPlus.data,
                  label: 'Add New Account',
                  subtitle: 'Switch to a different account',
                  isFocused: _actionPanelActive && _actionIdx == 7,
                  onTap: () => _handleMobileAction(7),
                ),
                const SizedBox(height: 8),
                _SettingsAction(
                  icon: FontAwesomeIcons.rightFromBracket.data,
                  label: 'Log Out',
                  subtitle: 'Sign out and clear session',
                  isFocused: _actionPanelActive && _actionIdx == 8,
                  isDestructive: true,
                  onTap: () => _handleMobileAction(8),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    'TV Parser • tvparser.com',
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
        ),
      ],
    );
  }

  Color _expiryColor(String? expDate) {
    if (expDate == null) return kColorHint;
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(expDate) * 1000,
      );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              const Text(
                "Stream Quality Mode",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQualityOption("Fast Start", "Live 1500ms / VOD 4000ms"),
              const SizedBox(height: 10),
              _buildQualityOption(
                "Balanced",
                "Live 2500ms / VOD 6000ms (Recommended)",
              ),
              const SizedBox(height: 10),
              _buildQualityOption(
                "Smooth Playback",
                "Live 3500ms / VOD 8000ms",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Close",
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) => _restoreFocus());
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
        _snack("Quality profile set to $mode");
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.06)
              : Colors.transparent,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kColorPrimary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
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
          color: isFocused ? accent.withValues(alpha: 0.18) : kColorCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFocused
                ? focusColor
                : Colors.white.withValues(alpha: 0.07),
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: focusColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
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
            trailing ??
                Icon(
                  FontAwesomeIcons.chevronRight.data,
                  size: 11,
                  color: isFocused
                      ? accent
                      : Colors.white.withValues(alpha: 0.2),
                ),
          ],
        ),
      ),
    );
  }
}
