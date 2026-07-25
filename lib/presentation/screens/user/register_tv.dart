part of '../screens.dart';

class RegisterUserTv extends StatefulWidget {
  const RegisterUserTv({super.key});

  @override
  State<RegisterUserTv> createState() => _RegisterUserTvState();
}

class _RegisterUserTvState extends State<RegisterUserTv> {
  final _username = NativeTextFieldController();
  final _password = NativeTextFieldController();
  final _domain = NativeTextFieldController();

  // 0=toggle, 1=url, 2=username, 3=password, 4=SignIn, 5=Help, 6=Demo (clamped depending on mode)
  int _row = 0;
  // true while a TextField keyboard is open
  bool _editing = false;
  bool _isM3uMode = false;

  final FocusNode _navFocus = FocusNode();
  final FocusNode _fn0 = FocusNode(); // username
  final FocusNode _fn1 = FocusNode(); // password
  final FocusNode _fn2 = FocusNode(); // url

  @override
  void initState() {
    super.initState();
    // Don't let D-pad traversal land on these — we control them manually
    _fn0.skipTraversal = true;
    _fn1.skipTraversal = true;
    _fn2.skipTraversal = true;

    _domain.text = '';
    _username.text = '';
    _password.text = '';
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _domain.dispose();
    _navFocus.dispose();
    _fn0.dispose();
    _fn1.dispose();
    _fn2.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_editing) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final maxRow = _isM3uMode ? 3 : 5;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _row = (_row + 1).clamp(0, maxRow));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _row = (_row - 1).clamp(0, maxRow));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _activate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activate([int? row]) {
    final target = row ?? _row;

    if (target == 0) {
      setState(() {
        _isM3uMode = !_isM3uMode;
        _domain.text = '';
        final maxRow = _isM3uMode ? 3 : 5;
        if (_row > maxRow) {
          _row = maxRow;
        }
      });
      return;
    }

    if (_isM3uMode) {
      if (target > 1) {
        if (target == 2) {
          _login();
        } else if (target == 3) {
          _showHelpDialog();
        }
        return;
      }
      setState(() {
        _row = target;
        _editing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (target == 1) {
          _fn2.requestFocus();
        }
      });
    } else {
      if (target > 3) {
        if (target == 4) {
          _login();
        } else if (target == 5) {
          _showHelpDialog();
        }
        return;
      }
      setState(() {
        _row = target;
        _editing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (target == 1) {
          _fn2.requestFocus();
        } else if (target == 2) {
          _fn0.requestFocus();
        } else if (target == 3) {
          _fn1.requestFocus();
        }
      });
    }
  }

  // Called when user presses Done on keyboard
  void _done(int nextRow) {
    setState(() {
      _editing = false;
      _row = nextRow;
    });
    _navFocus.requestFocus();
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF13101E),
        title: const Text('Need Help?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Please contact your playlist provider or administrator to retrieve your Server URL, Username, and Password.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK', style: TextStyle(color: kColorPrimary)),
          ),
        ],
      ),
    );
  }

  void _login() {
    final rawUrl = _domain.text.trim();
    if (rawUrl.isEmpty) {
      showWarningToast(
        context,
        _isM3uMode ? 'Playlist URL Required' : 'Server URL Required',
        _isM3uMode
            ? 'Unable to sign in. Please enter your M3U playlist URL.'
            : 'Unable to sign in. Please check your server URL, username, and password.',
      );
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      showWarningToast(
        context,
        _isM3uMode ? 'Invalid Playlist URL' : 'Invalid Server URL',
        _isM3uMode
            ? 'Unable to sign in. Please enter a valid playlist URL starting with http:// or https://'
            : 'Unable to sign in. Please check your server URL, username, and password.',
      );
      return;
    }

    var normalizedUrl = rawUrl;
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    if (_isM3uMode) {
      context.read<AuthBloc>().add(AuthLoadM3u(normalizedUrl));
      return;
    }

    final username = _username.text.trim();
    final password = _password.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showWarningToast(
        context,
        'Credentials Required',
        'Unable to sign in. Please check your server URL, username, and password.',
      );
      return;
    }

    context.read<AuthBloc>().add(
      AuthRegister(username, password, normalizedUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _navFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Ink(
          width: double.infinity,
          height: double.infinity,
          decoration: kDecorBackground,
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, settingState) {
              return BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthSuccess) {
                    context.read<LiveCatyBloc>().add(GetLiveCategories());
                    context.read<MovieCatyBloc>().add(GetMovieCategories());
                    context.read<SeriesCatyBloc>().add(GetSeriesCategories());
                    Get.offAndToNamed(screenWelcome);
                  } else if (state is AuthFailed) {
                    showWarningToast(
                      context,
                      'Login Failed',
                      'Unable to sign in. Please check your server URL, username, and password.',
                    );
                  }
                },
                builder: (context, state) {
                  if (state is AuthLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: kColorPrimary),
                    );
                  }

                  return Row(
                    children: [
                      // ── Left branding ─────────────────────────────
                      ExcludeFocus(
                        child: Expanded(
                          flex: 4,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [kColorBackDark, kColorCardLight],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  kIconLogoTransparent,
                                  width: getSize(context).height * .31,
                                  height: getSize(context).height * .31,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  kAppName,
                                  style: Get.textTheme.headlineLarge!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your authorized playlist player',
                                  style: Get.textTheme.bodyMedium!.copyWith(
                                    color: kColorHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Right form ────────────────────────────────
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              decoration: BoxDecoration(
                                color: kColorCardLight.withValues(alpha: .8),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(28),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Sign in to TV Parser',
                                      style: Get.textTheme.headlineSmall!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sign in with your authorized playlist/provider credentials.',
                                      style: Get.textTheme.bodySmall!.copyWith(
                                        color: kColorHint,
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // Connection Mode Toggle
                                    const Text(
                                      "Connection Type",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _TvToggle(
                                      key: const ValueKey('toggle_m3u_mode_tv'),
                                      isSelected: _row == 0,
                                      isM3uMode: _isM3uMode,
                                      onTap: () {
                                        setState(() {
                                          _isM3uMode = !_isM3uMode;
                                          _domain.text = '';
                                          final maxRow = _isM3uMode ? 3 : 5;
                                          if (_row > maxRow) {
                                            _row = maxRow;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // 1. Server / Playlist URL field
                                    Text(
                                      _isM3uMode
                                          ? "M3U Playlist URL"
                                          : "Server / Portal URL",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _TvField(
                                      key: const ValueKey('field_url_tv'),
                                      controller: _domain,
                                      hint: _isM3uMode
                                          ? 'https://example.com/playlist.m3u'
                                          : 'https://example.com',
                                      icon: FontAwesomeIcons.link.data,
                                      focusNode: _fn2,
                                      keyboardType: TextInputType.url,
                                      isSelected: _row == 1,
                                      isEditing: _editing && _row == 1,
                                      onTap: () => _activate(1),
                                      onDone: () => _done(2),
                                      helperText: _isM3uMode
                                          ? 'Enter the direct M3U playlist URL.'
                                          : 'Enter the server URL provided by your authorized playlist provider.',
                                    ),
                                    const SizedBox(height: 12),

                                    if (!_isM3uMode) ...[
                                      // 2. Username field
                                      const Text(
                                        "Username",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _TvField(
                                        controller: _username,
                                        hint: 'Username',
                                        icon: FontAwesomeIcons.solidUser.data,
                                        focusNode: _fn0,
                                        keyboardType: TextInputType.text,
                                        isSelected: _row == 2,
                                        isEditing: _editing && _row == 2,
                                        onTap: () => _activate(2),
                                        onDone: () => _done(3),
                                      ),
                                      const SizedBox(height: 12),

                                      // 3. Password field
                                      const Text(
                                        "Password",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _TvField(
                                        controller: _password,
                                        hint: 'Password',
                                        icon: FontAwesomeIcons.lock.data,
                                        focusNode: _fn1,
                                        keyboardType:
                                            TextInputType.visiblePassword,
                                        isSelected: _row == 3,
                                        isEditing: _editing && _row == 3,
                                        obscure: true,
                                        onTap: () => _activate(3),
                                        onDone: () => _done(4),
                                      ),
                                      const SizedBox(height: 20),
                                    ],

                                    // 4. Sign In button
                                    _TvButton(
                                      key: const ValueKey('btn_sign_in_tv'),
                                      label: 'Sign In',
                                      isSelected: _isM3uMode
                                          ? _row == 2
                                          : _row == 4,
                                      onTap: _login,
                                    ),
                                    const SizedBox(height: 12),

                                    // 5. Need help link
                                    _TvTextButton(
                                      label:
                                          'Need help finding your credentials?',
                                      isSelected: _isM3uMode
                                          ? _row == 3
                                          : _row == 5,
                                      onTap: _showHelpDialog,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── TV Input Field ───────────────────────────────────────────────────────────

class _TvField extends StatelessWidget {
  const _TvField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.focusNode,
    required this.keyboardType,
    required this.isSelected,
    required this.isEditing,
    required this.onDone,
    required this.onTap,
    this.obscure = false,
    this.helperText,
  });

  final NativeTextFieldController controller;
  final String hint;
  final IconData icon;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final bool isSelected; // D-pad is on this row
  final bool isEditing; // keyboard is open for this row
  final bool obscure;
  final VoidCallback onDone;
  final VoidCallback onTap;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    Widget fieldWidget;
    // When editing: use native Android EditText via PlatformView.
    if (isEditing) {
      controller.onFocusChanged = (hasFocus) {
        if (!hasFocus) onDone();
      };
      fieldWidget = SizedBox(
        height: 52,
        child: AndroidTVTextField(
          controller: controller,
          focusNode: focusNode,
          hint: hint,
          obscureText: obscure,
          onSubmitted: (_) => onDone(),
          backgroundColor: kColorCardDark,
          textColor: Colors.white,
          focuesedBorderColor: kColorFocus,
          unFocuesedBorderColor: Colors.transparent,
        ),
      );
    } else {
      // When not editing: show a styled read-only container.
      fieldWidget = GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          decoration: BoxDecoration(
            color: kColorCardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? kColorFocus : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kColorFocus.withValues(alpha: .35),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (_, value, __) {
                    final text = value.text;
                    final display = obscure && text.isNotEmpty
                        ? '•' * text.length
                        : text;
                    return Text(
                      display.isEmpty ? hint : display,
                      style: TextStyle(
                        color: display.isEmpty ? kColorHint : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: display.isEmpty ? 14 : 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              Icon(icon, size: 16, color: kColorPrimary),
            ],
          ),
        ),
      );
    }

    if (helperText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldWidget,
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              helperText!,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
        ],
      );
    }
    return fieldWidget;
  }
}

// ─── TV Button ────────────────────────────────────────────────────────────────

class _TvButton extends StatelessWidget {
  const _TvButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? kColorPrimary : kColorCardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kColorFocus : kColorCardDark,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .4),
                    blurRadius: 14,
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─── TV Text Button (D-pad focusable) ─────────────────────────────────────────

class _TvTextButton extends StatelessWidget {
  const _TvTextButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kColorFocus : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kColorPrimary : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── TV Toggle Switch (D-pad focusable) ───────────────────────────────────────

class _TvToggle extends StatelessWidget {
  const _TvToggle({
    super.key,
    required this.isSelected,
    required this.isM3uMode,
    required this.onTap,
  });

  final bool isSelected;
  final bool isM3uMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: kColorCardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? kColorFocus : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .35),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: !isM3uMode ? kColorPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Xtream Codes API',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isM3uMode ? kColorPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'M3U Playlist URL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
