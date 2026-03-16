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

  // focused action button index (0=Refresh, 1=Add User, 2=Logout)
  int _actionIdx = 0;
  bool _actionPanelActive = false;

  final _navFocus = FocusNode();

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
        if (_actionIdx < 2) setState(() => _actionIdx++);
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
    switch (idx) {
      case 0:
        context.read<LiveCatyBloc>().add(GetLiveCategories());
        context.read<MovieCatyBloc>().add(GetMovieCategories());
        context.read<SeriesCatyBloc>().add(GetSeriesCategories());
        Get.back();
      case 1:
        context.read<AuthBloc>().add(AuthLogOut());
        Get.offAllNamed('/');
      case 2:
        context.read<SettingsCubit>().updateStatusAccount(false);
        context.read<AuthBloc>().add(AuthLogOut());
        Get.offAllNamed('/');
        Get.reload();
    }
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
                        icon: FontAwesomeIcons.gear,
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
                                  icon: FontAwesomeIcons.idCard,
                                  title: 'Subscription',
                                  children: [
                                    _InfoRow(
                                      label: 'Username',
                                      value: userInfo?.username ?? '—',
                                      icon: FontAwesomeIcons.user,
                                    ),
                                    const SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Password',
                                      value: userInfo?.password != null
                                          ? '••••••••'
                                          : '—',
                                      icon: FontAwesomeIcons.lock,
                                    ),
                                    const SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Server',
                                      value: serverInfo?.serverUrl ?? '—',
                                      icon: FontAwesomeIcons.server,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Status card
                                _InfoCard(
                                  icon: FontAwesomeIcons.circleInfo,
                                  title: 'Account Status',
                                  children: [
                                    _InfoRow(
                                      label: 'Date',
                                      value: dateNowWelcome(),
                                      icon: FontAwesomeIcons.calendarDay,
                                    ),
                                    const SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Expires',
                                      value: expirationDate(userInfo?.expDate),
                                      icon: FontAwesomeIcons.hourglass,
                                      valueColor: _expiryColor(userInfo?.expDate),
                                    ),
                                    const SizedBox(height: 10),
                                    _InfoRow(
                                      label: 'Status',
                                      value: userInfo?.status ?? '—',
                                      icon: FontAwesomeIcons.circleCheck,
                                      valueColor: userInfo?.status == 'Active'
                                          ? Colors.greenAccent
                                          : kColorHint,
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
                                  icon: FontAwesomeIcons.arrowsRotate,
                                  label: 'Refresh All Data',
                                  subtitle: 'Reload channels & categories',
                                  isFocused: _actionPanelActive && _actionIdx == 0,
                                  onTap: () => _handleAction(0),
                                ),
                                const SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.userPlus,
                                  label: 'Add New Account',
                                  subtitle: 'Switch to a different account',
                                  isFocused: _actionPanelActive && _actionIdx == 1,
                                  onTap: () => _handleAction(1),
                                ),
                                const SizedBox(height: 8),
                                _SettingsAction(
                                  icon: FontAwesomeIcons.rightFromBracket,
                                  label: 'Log Out',
                                  subtitle: 'Sign out and clear session',
                                  isFocused: _actionPanelActive && _actionIdx == 2,
                                  isDestructive: true,
                                  onTap: () => _handleAction(2),
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
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isFocused;
  final VoidCallback onTap;
  final bool isDestructive;

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
            Icon(
              FontAwesomeIcons.chevronRight,
              size: 11,
              color: isFocused ? accent : Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
