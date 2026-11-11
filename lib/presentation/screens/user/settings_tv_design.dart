part of '../screens.dart';

/// Screenshot-matched 16:9 Android TV settings skin.
/// All controls delegate to the real SettingsScreen state/actions.
extension _TvSettingsVisual on _SettingsScreenState {
  static const _ink = Color(0xFF03142F);
  static const _purple = Color(0xFFAE24FF);
  static const _blue = Color(0xFF13A7FF);
  static const _white = Color(0xFFF9FAFF);

  Widget _buildTvSettingsRedesign(dynamic userInfo, dynamic serverInfo) {
    return LayoutBuilder(
      builder: (context, bounds) => Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1672,
            height: 941,
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _TvSettingsBackdrop())),
                Positioned(
                  top: 22,
                  left: 56,
                  right: 55,
                  height: 68,
                  child: _tvSettingsTopNavigation(),
                ),
                Positioned(
                  top: 214,
                  left: 28,
                  width: 418,
                  bottom: 108,
                  child: _tvSettingsSidebar(),
                ),
                Positioned(
                  left: 469,
                  top: 208,
                  bottom: 56,
                  width: 1.2,
                  child: ColoredBox(color: Color(0xFF264DB0)),
                ),
                Positioned(
                  top: 107,
                  left: 496,
                  right: 51,
                  bottom: 35,
                  child: _tvSettingsMainPanel(userInfo, serverInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tvSettingsTopNavigation() {
    final labels = ['Home', 'Live TV', 'Movies', 'Series', 'Favourites', 'Settings'];
    final icons = [
      Icons.home_rounded,
      Icons.sensors_rounded,
      Icons.movie_outlined,
      Icons.movie_filter_outlined,
      Icons.star_border_rounded,
      Icons.settings_rounded,
    ];
    final widths = [140.0, 159.0, 158.0, 154.0, 199.0, 211.0];
    return Row(
      children: [
        SizedBox(
          width: 370,
          child: Row(
            children: [
              Container(
                width: 70,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFF1C89FF), Color(0xFF755CFF)]),
                  border: Border.all(color: const Color(0xFF98C5FF), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66297CFF), blurRadius: 16),
                  ],
                ),
                child: const Icon(Icons.smart_display_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Text('TV Parser', style: TextStyle(
                color: _white, fontSize: 43, fontWeight: FontWeight.w900, letterSpacing: -1.8,
              )),
            ],
          ),
        ),
        const SizedBox(width: 25),
        for (var i = 0; i < labels.length; i++) ...[
          _tvSettingsTopTab(i, labels[i], icons[i], widths[i]),
          if (i != labels.length - 1) const SizedBox(width: 26),
        ],
      ],
    );
  }

  Widget _tvSettingsTopTab(int idx, String title, IconData icon, double width) {
    final selected = idx == 5;
    final focused = _appbarActive && _appbarIdx == idx;
    return _TvSettingsNeonTile(
      width: width,
      height: 60,
      focused: focused,
      selected: selected,
      violet: selected,
      radius: 19,
      onTap: () => _tvSettingsOpenTopTab(idx),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 33, color: _white),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(
            fontSize: 23, color: Colors.white,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          )),
        ],
      ),
    );
  }

  void _tvSettingsOpenTopTab(int idx) {
    if (idx == 5) {
      setState(() {
        _appbarActive = false;
        _sectionPanelActive = true;
        _detailPanelActive = false;
      });
      _restoreFocus();
      return;
    }
    if (idx == 4) {
      Get.offNamed(screenFavourite);
      return;
    }
    // The existing TV dashboard owns its tabs. Ask it to switch when Settings pops.
    final box = GetStorage('preferences');
    box.write('settings_return_tab', idx == 0 ? 0 : idx - 1);
    _popToShell();
  }

  Widget _tvSettingsSidebar() {
    const labels = [
      ['Sources', 'Manage playlists & content'],
      ['Playback', 'Player, audio & subtitle'],
      ['Local', 'Storage & downloads'],
      ['Diagnostics', 'Check & fix issues'],
      ['Account', 'Login, sync & devices'],
      ['About', 'App info, updates & support'],
    ];
    const icons = [
      Icons.dns_rounded,
      Icons.play_circle_outline_rounded,
      Icons.folder_open_outlined,
      Icons.monitor_heart_outlined,
      Icons.person_outline_rounded,
      Icons.info_outline_rounded,
    ];
    return Column(
      children: [
        for (var i = 0; i < _tvSections.length; i++) ...[
          _TvSettingsNeonTile(
            width: 418,
            height: 92,
            selected: _sectionIdx == i,
            focused: _sectionPanelActive && _sectionIdx == i,
            radius: 21,
            violet: _sectionIdx == i,
            onTap: () {
              setState(() {
                _sectionIdx = i;
                _sectionPanelActive = true;
                _detailPanelActive = false;
                _detailIdx = 0;
                _appbarActive = false;
              });
              _restoreFocus();
            },
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Icon(icons[i], size: 45, color: Colors.white),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(labels[i][0], style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 25,
                      )),
                      const SizedBox(height: 4),
                      Text(labels[i][1], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFDAE6FF), fontSize: 17)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 37, color: Colors.white),
              ],
            ),
          ),
          if (i < _tvSections.length - 1) const SizedBox(height: 11),
        ],
      ],
    );
  }

  Widget _tvSettingsMainPanel(dynamic userInfo, dynamic serverInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.settings_rounded, color: Color(0xFFA9CBFF), size: 80),
            const SizedBox(width: 20),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: TextStyle(
                  fontSize: 55, fontWeight: FontWeight.w900, color: Colors.white, height: 1.03,
                )),
                SizedBox(height: 8),
                Text('Manage your TV Parser experience', style: TextStyle(
                  color: Color(0xFFD9E4FF), fontSize: 23, height: 1.05,
                )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 19),
        Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF112D75), _purple, Color(0xFF04A1FF), Color(0x002F3088)]),
            boxShadow: [BoxShadow(color: Color(0xBB8C22FF), blurRadius: 9)],
          ),
        ),
        const SizedBox(height: 26),
        Expanded(child: _sectionIdx == 0
          ? _tvSettingsSourcePanel(userInfo, serverInfo)
          : _tvSettingsOtherPanel(userInfo, serverInfo)),
      ],
    );
  }

  Widget _tvSettingsSectionBar(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFBBD6FF), size: 33),
        const SizedBox(width: 16),
        Text(title, style: const TextStyle(
          color: _white, fontSize: 31, fontWeight: FontWeight.w800,
        )),
        const SizedBox(width: 15),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF003E8F), Color(0xFF7C16D6), Color(0x116F13FF)]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tvSettingsSourcePanel(dynamic userInfo, dynamic serverInfo) {
    final savedStart = 2;
    final quickStart = 2 + _savedAccounts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tvSettingsSectionBar('Sources', Icons.settings_suggest_rounded),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _tvSettingsWideAction(
              icon: Icons.link_rounded,
              title: 'Refresh Playlist Data',
              subtitle: 'Reload channels, movies & series',
              idx: 0,
              onTap: () => _handleTvDetailAction(_TvSettingsSection.sources, 0),
            )),
            const SizedBox(width: 28),
            Expanded(child: _tvSettingsWideAction(
              icon: Icons.person_add_alt_rounded,
              title: 'Add / Switch Account',
              subtitle: 'Sign in with another source',
              idx: 1,
              onTap: () => _handleTvDetailAction(_TvSettingsSection.sources, 1),
            )),
          ],
        ),
        const SizedBox(height: 22),
        _tvSettingsSectionBar('Saved Logins', Icons.lock_rounded),
        const SizedBox(height: 15),
        SizedBox(
          height: 95,
          child: _savedAccounts.isEmpty
            ? _TvSettingsNeonTile(
                height: 95, selected: false, focused: false, onTap: () {},
                child: const Center(child: Text('No saved accounts yet — add a source to get started.',
                  style: TextStyle(color: Color(0xFFE2E8FF), fontSize: 20))),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _savedAccounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final account = _savedAccounts[i];
                  final server = serverInfo?.serverUrl?.toString() ?? '';
                  final active = account.isM3u
                    ? m3uPlaylistUrlFromServerUrl(server) == account.playlistUrl
                    : (userInfo?.username?.toString() == account.username &&
                        server == account.domain);
                  return _TvSettingsNeonTile(
                    width: 1100,
                    height: 94,
                    selected: active,
                    focused: _detailPanelActive && _detailIdx == savedStart + i,
                    violet: active,
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    onTap: () => _handleTvDetailAction(_TvSettingsSection.sources, savedStart + i),
                    child: Row(
                      children: [
                        Icon(account.isM3u ? Icons.description_outlined : Icons.dns_outlined,
                          color: Colors.white, size: 48),
                        const SizedBox(width: 34),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(account.label, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(account.isM3u ? 'Your saved playlist' : 'Saved service account',
                                style: const TextStyle(color: Color(0xFFD2DEFF), fontSize: 19)),
                            ],
                          ),
                        ),
                        if (active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00834A),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFF00C974)),
                            ),
                            child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                          ),
                        const SizedBox(width: 15),
                        const Icon(Icons.chevron_right_rounded, size: 35, color: Colors.white),
                      ],
                    ),
                  );
                },
              ),
        ),
        const Spacer(),
        _tvSettingsSectionBar('Quick Tools', Icons.build_rounded),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _tvSettingsQuickCard(
              Icons.cleaning_services_rounded, 'Clear Cache', 'Free up space', quickStart,
            )),
            const SizedBox(width: 25),
            Expanded(child: _tvSettingsQuickCard(
              Icons.storage_rounded, 'Rebuild Data', 'Refresh channels', quickStart + 1,
            )),
            const SizedBox(width: 25),
            Expanded(child: _tvSettingsQuickCard(
              Icons.download_rounded, 'Check for Updates', 'Get the latest version', quickStart + 2,
            )),
            const SizedBox(width: 25),
            Expanded(child: _tvSettingsQuickCard(
              Icons.info_outline_rounded, 'System Info', 'App & device details', quickStart + 3,
            )),
          ],
        ),
        const SizedBox(height: 42),
      ],
    );
  }

  Widget _tvSettingsWideAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required int idx,
    required VoidCallback onTap,
  }) {
    return _TvSettingsNeonTile(
      height: 111,
      focused: _detailPanelActive && _detailIdx == idx,
      selected: true,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 56, color: const Color(0xFFD0E1FF)),
          const SizedBox(width: 30),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFD1E0FF), fontSize: 19)),
            ],
          )),
          const Icon(Icons.chevron_right_rounded, size: 37, color: Colors.white),
        ],
      ),
    );
  }

  Widget _tvSettingsQuickCard(IconData icon, String title, String subtitle, int idx) {
    return _TvSettingsNeonTile(
      height: 185,
      selected: true,
      focused: _detailPanelActive && _detailIdx == idx,
      violet: idx.isOdd,
      radius: 22,
      onTap: () => _handleTvDetailAction(_TvSettingsSection.sources, idx),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 65, color: Colors.white),
          const SizedBox(height: 13),
          Text(title, textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 18)),
        ],
      ),
    );
  }

  Widget _tvSettingsOtherPanel(dynamic userInfo, dynamic serverInfo) {
    final selected = _tvSections[_sectionIdx];
    final entries = <_TvSettingsActionData>[];
    String heading = _sectionLabel(selected);
    String subhead = '';
    switch (selected) {
      case _TvSettingsSection.sources:
        return _tvSettingsSourcePanel(userInfo, serverInfo);
      case _TvSettingsSection.playback:
        subhead = 'Current quality: ' + _currentQualityMode + '    •    Preview: ' + CinematicPrefs.label(_heroPreviewMode);
        entries.addAll([
          const _TvSettingsActionData(Icons.tune_rounded, 'Stream Quality Mode', 'Tune buffer sizes for your connection.'),
          const _TvSettingsActionData(Icons.live_tv_rounded, 'Hero Preview', 'Control the preview experience while browsing.'),
        ]);
      case _TvSettingsSection.local:
        subhead = 'Market: ' + _activeMarketName;
        entries.addAll([
          _TvSettingsActionData(Icons.location_on_outlined, 'Local Personalization',
            _locationPersonalizationEnabled ? 'On — recommend relevant nearby channels' : 'Off — local recommendations disabled'),
          const _TvSettingsActionData(Icons.map_outlined, 'Change Local TV Market', 'Choose the market used for local channels.'),
          const _TvSettingsActionData(Icons.restart_alt_rounded, 'Reset Location Preferences', 'Clear location preferences and market.'),
        ]);
      case _TvSettingsSection.diagnostics:
        subhead = 'Test network latency, stream reachability and download speed';
        entries.add(const _TvSettingsActionData(Icons.monitor_heart_rounded,
          'Connection Diagnostics', 'Run the existing network and streaming diagnostic suite.'));
      case _TvSettingsSection.account:
        subhead = 'Account: ' + (userInfo?.username?.toString() ?? 'Playlist user');
        entries.addAll([
          const _TvSettingsActionData(Icons.person_add_alt_rounded, 'Add New Account', 'Log in with another playlist or service.'),
          const _TvSettingsActionData(Icons.logout_rounded, 'Log Out', 'Sign out of the current source.'),
        ]);
      case _TvSettingsSection.about:
        subhead = 'App details, controls and content credits';
        entries.addAll([
          const _TvSettingsActionData(Icons.lock_outline_rounded, 'Parental PIN', 'Control access to restricted categories.'),
          _TvSettingsActionData(Icons.closed_caption_rounded, 'Subtitle Size', 'Current size: ' + _subtitleSize),
          const _TvSettingsActionData(Icons.info_outline_rounded, 'TV Parser', 'Media player information and support.'),
          const _TvSettingsActionData(Icons.photo_library_outlined, 'Artwork Credit', 'Read third-party artwork attribution.'),
        ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tvSettingsSectionBar(heading, _sectionIcon(selected)),
        const SizedBox(height: 12),
        Text(subhead, style: const TextStyle(fontSize: 20, color: Color(0xFFD3E3FF))),
        const SizedBox(height: 28),
        Expanded(child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: _tvSettingsWideAction(
              icon: entries[i].icon,
              title: entries[i].title,
              subtitle: entries[i].subtitle,
              idx: i,
              onTap: () => _handleTvDetailAction(selected, i),
            ),
          ),
        )),
      ],
    );
  }

  void _tvSettingsQuickTool(int tool) {
    switch (tool) {
      case 0:
        unawaited(_tvSettingsClearCache());
      case 1:
        unawaited(_tvSettingsRebuildData());
      case 2:
        unawaited(_tvSettingsCheckUpdates());
      case 3:
        unawaited(_tvSettingsSystemInfo());
    }
  }

  Future<bool> _tvSettingsConfirm(String title, String detail) async {
    return (await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _ink,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(detail, style: const TextStyle(color: Color(0xFFDCE6FF))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue')),
        ],
      ),
    )) == true;
  }

  void _tvSettingsRefreshPlaylist() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthSuccess) {
      final url = m3uPlaylistUrlFromServerUrl(auth.user.serverInfo?.serverUrl);
      if (url != null && url.isNotEmpty) {
        context.read<AuthBloc>().add(AuthLoadM3u(url));
        Get.offAllNamed('/');
        return;
      }
    }
    context.read<LiveCatyBloc>().add(GetLiveCategories());
    context.read<MovieCatyBloc>().add(GetMovieCategories());
    context.read<SeriesCatyBloc>().add(GetSeriesCategories());
    _snack('Refreshing your channel categories.');
    _popToShell();
  }

  Future<void> _tvSettingsClearCache() async {
    if (!await _tvSettingsConfirm('Clear temporary cache?',
      'Clear cached artwork and trailer metadata without deleting saved accounts, playlists, or preferences.')) {
      _restoreFocus();
      return;
    }
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final temp = await getTemporaryDirectory();
      // Only the image-cache subtree owned by the image cache manager is removed.
      // Keep user-auth and durable M3U library files intact.
      final imageDir = Directory(temp.path + '/libCachedImageData');
      if (await imageDir.exists()) {
        await imageDir.delete(recursive: true);
      }
      await GetStorage('youtube_trailer_cache').erase();
      if (!mounted) return;
      _snack('Temporary image and trailer cache cleared.');
    } catch (e) {
      if (mounted) _snack('Unable to clear some temporary cache files: ' + e.toString());
    }
    _restoreFocus();
  }

  Future<void> _tvSettingsRebuildData() async {
    if (!await _tvSettingsConfirm('Rebuild channel data?',
      'Reload your current playlist from the provider and rebuild catalog data. Your saved account remains available.')) {
      _restoreFocus();
      return;
    }
    try {
      await XmlTvRepository.instance.clear();
      if (!mounted) return;
      _tvSettingsRefreshPlaylist();
    } catch (e) {
      if (mounted) _snack('Could not rebuild the guide: ' + e.toString());
      _restoreFocus();
    }
  }

  Future<void> _tvSettingsCheckUpdates() async {
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;
    String message = 'Installed version: ' + pkg.version + ' (build ' + pkg.buildNumber + ').';
    try {
      final res = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6))).get(
          'https://api.github.com/repos/qanvass/tv-parser/releases/latest',
          options: Options(headers: {'Accept': 'application/vnd.github+json'}),
        );
      final data = res.data;
      if (data is Map && data['tag_name'] != null) {
        final latest = data['tag_name'].toString();
        message += '\nLatest published GitHub release: ' + latest +
          '.\nCheck the release notes to determine whether an update is available for your device.';
      } else {
        message += '\nNo published GitHub release was found.';
      }
    } catch (_) {
      message += '\nCould not check the latest GitHub release. Check again when connected.';
    }
    if (!mounted) return;
    await _tvSettingsInfoDialog('Check for Updates', message +
      '\n\nReleases: github.com/qanvass/tv-parser/releases');
    _restoreFocus();
  }

  Future<void> _tvSettingsSystemInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final auth = context.read<AuthBloc>().state;
    final source = auth is AuthSuccess
      ? (m3uPlaylistUrlFromServerUrl(auth.user.serverInfo?.serverUrl) != null ? 'M3U Playlist' : 'Xtream')
      : 'Signed out';
    final msg = 'TV Parser ' + pkg.version + ' (build ' + pkg.buildNumber + ')' +
      '\nOperating system: ' + Platform.operatingSystem +
      '\nForm factor: Android TV' +
      '\nSource type: ' + source +
      '\nBuffer profile: ' + _currentQualityMode +
      '\nCached live channels: ' + LocaleApi.getM3uChannels().length.toString() +
      '\nSaved logins: ' + _savedAccounts.length.toString();
    await _tvSettingsInfoDialog('System Info', msg);
    _restoreFocus();
  }

  Future<void> _tvSettingsInfoDialog(String title, String detail) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: SelectableText(detail, style: const TextStyle(color: Color(0xFFD8E4FF), fontSize: 16, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Done'))],
      ),
    );
  }
}

class _TvSettingsActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TvSettingsActionData(this.icon, this.title, this.subtitle);
}

/// Separate paint-only surface; never opens streams or performs IO.
class _TvSettingsBackdrop extends CustomPainter {
  const _TvSettingsBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF001331), Color(0xFF00071B), Color(0xFF11073C)],
    ).createShader(all));

    final sky = Rect.fromLTWH(770, 0, 902, 235);
    canvas.drawRect(sky, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF07184A), Color(0xFF32216C), Color(0xFFC14A77), Color(0xFF030C26)],
    ).createShader(sky));
    canvas.drawRect(Rect.fromLTWH(770, 199, 902, 50),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xAAFF8848), Color(0x0000091A)],
      ).createShader(Rect.fromLTWH(770, 199, 902, 50)));

    // Skyline silhouettes, aerials and small illuminated office windows.
    const heights = [66, 89, 51, 106, 71, 92, 132, 80, 67, 117, 145, 96,
      121, 79, 57, 112, 69, 84, 128, 96, 142, 91, 74, 110, 63, 87, 104,
      71, 90, 129, 79, 112, 60, 77, 97, 124, 76, 66, 105];
    for (var i = 0; i < heights.length; i++) {
      final x = 800.0 + i * 23.0;
      final h = heights[i].toDouble();
      final y = 218 - h;
      final w = (i % 4 == 0) ? 31.0 : 23.0;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = const Color(0xFF030C21));
      if (i % 5 == 0) {
        canvas.drawRect(Rect.fromLTWH(x + w / 2, y - 24, 1.5, 24),
          Paint()..color = const Color(0xFFFFBC82));
      }
      final winPaint = Paint()..color = const Color(0xFFFFB85F);
      for (var col = 0; col < 3; col++) {
        for (var row = 0; row < 9; row++) {
          if ((i * 7 + col * 13 + row * 11) % 5 != 0) {
            canvas.drawRect(Rect.fromLTWH(x + 4 + col * 7, y + 9 + row * 10, 2, 3),
              winPaint..color = row.isEven ? const Color(0xFFFFB96C) : const Color(0xFF5574CC));
          }
        }
      }
    }
    canvas.drawRect(Rect.fromLTWH(772, 216, 900, 21),
      Paint()..color = const Color(0xE9000A21));

    final glowLeft = Paint()
      ..shader = const RadialGradient(colors: [Color(0x330064FF), Color(0x000064FF)])
        .createShader(const Rect.fromLTWH(-250, 80, 780, 880));
    canvas.drawRect(all, glowLeft);

    final corner = Paint()..shader = const RadialGradient(
      colors: [Color(0x887100B8), Color(0x005E00AA)],
    ).createShader(const Rect.fromLTWH(1050, 500, 800, 700));
    canvas.drawRect(all, corner);

    // Neon ribbons on the left and bottom, as in the supplied reference.
    final ribbon = Path()
      ..moveTo(-25, 168)
      ..cubicTo(112, 113, 128, 148, 215, 125)
      ..cubicTo(303, 92, 371, 108, 470, 245);
    canvas.drawPath(ribbon, Paint()..color = const Color(0xFF0086FF)
      ..style = PaintingStyle.stroke ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final bottom = Path()
      ..moveTo(-30, 808)
      ..cubicTo(82, 945, 208, 866, 295, 862)
      ..cubicTo(391, 839, 408, 865, 492, 917);
    canvas.drawPath(bottom, Paint()..color = const Color(0xFF9E29FF)
      ..style = PaintingStyle.stroke ..strokeWidth = 2.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(bottom, Paint()..color = const Color(0xFF5922FF)
      ..style = PaintingStyle.stroke ..strokeWidth = 1.5);

    canvas.drawLine(const Offset(28, 202), const Offset(438, 202),
      Paint()..color = const Color(0x550E66FF) ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _TvSettingsBackdrop oldDelegate) => false;
}

class _TvSettingsNeonTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool focused;
  final bool selected;
  final bool violet;
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry padding;

  const _TvSettingsNeonTile({
    required this.child,
    required this.onTap,
    required this.focused,
    required this.selected,
    this.violet = false,
    this.width,
    this.height = 90,
    this.radius = 19,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final hot = selected || focused;
    final edge = focused ? const Color(0xFFFFAEFF) :
      hot ? (violet ? const Color(0xFFCE60FF) : const Color(0xFF4CC1FF)) :
      const Color(0xFF697EBB);
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: hot
              ? (violet
                ? const [Color(0xFF1845C9), Color(0xFF261255), Color(0xFF790EC1)]
                : const [Color(0xFF0566BF), Color(0xFF052F6A), Color(0xFF2833A6)])
              : const [Color(0xFF203E76), Color(0xFF111F42), Color(0xFF16244F)],
          ),
          border: Border.all(color: edge, width: focused ? 3 : 1.8),
          boxShadow: hot ? [
            BoxShadow(color: edge.withValues(alpha: focused ? 0.72 : 0.36), blurRadius: focused ? 23 : 14, spreadRadius: focused ? 2 : 0),
            const BoxShadow(color: Color(0x44085DF6), blurRadius: 22, offset: Offset(0, 3)),
          ] : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
