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

  int _row = 0;
  // true while an edit dialog is open
  bool _isDialogOpen = false;
  bool _isM3uMode = true;

  final FocusNode _navFocus = FocusNode();
  final FocusNode _fn0 = FocusNode(); // username
  final FocusNode _fn1 = FocusNode(); // password
  final FocusNode _fn2 = FocusNode(); // url

  final ScrollController _fieldsScroll = ScrollController();
  final GlobalKey _urlFieldKey = GlobalKey();
  final GlobalKey _usernameFieldKey = GlobalKey();
  final GlobalKey _passwordFieldKey = GlobalKey();
  final GlobalKey _signInKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fn0.skipTraversal = true;
    _fn1.skipTraversal = true;
    _fn2.skipTraversal = true;

    _isM3uMode = true;
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
    _fieldsScroll.dispose();
    super.dispose();
  }

  void _setRow(int next) {
    setState(() => _row = next);
    _ensureFocusedFieldVisible();
  }

  void _ensureFocusedFieldVisible() {
    final GlobalKey? key;
    if (_row == 1) {
      key = _urlFieldKey;
    } else if (!_isM3uMode && _row == 2) {
      key = _usernameFieldKey;
    } else if (!_isM3uMode && _row == 3) {
      key = _passwordFieldKey;
    } else if ((_isM3uMode && _row == 2) || (!_isM3uMode && _row == 4)) {
      // Keep Sign In above the soft keyboard / fold.
      key = _signInKey;
    } else {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key?.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: key == _signInKey ? 0.85 : 0.35,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isDialogOpen) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final maxRow = _isM3uMode ? 3 : 5;

    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      if (Navigator.of(context).canPop()) {
        Get.back();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _setRow((_row + 1).clamp(0, maxRow));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _setRow((_row - 1).clamp(0, maxRow));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space) {
      _activate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showEditDialog(
    String title,
    NativeTextFieldController controller, {
    bool obscure = false,
  }) {
    setState(() => _isDialogOpen = true);
    // Release parent D-pad trap so dialog / IME can own directional keys.
    _navFocus.unfocus();

    // Native EditText (PlatformView) — Flutter TextField swallows D-pad on
    // Chromecast/Google TV (InputConnectionAdaptor), so Gboard keys never move.
    final editCtrl = NativeTextFieldController(text: controller.text);
    final editFocus = FocusNode(debugLabel: 'register_tv_edit_dialog');

    var closed = false;
    void closeDialog([String? textToSave]) {
      if (closed) return;
      closed = true;
      if (textToSave != null) {
        controller.text = textToSave;
      }
      if (_isDialogOpen) {
        setState(() => _isDialogOpen = false);
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      // Soft keyboard on Chromecast/Android TV must not cover Save.
      // Leanback IME often overlays without reliable viewInsets, so the
      // editor is top-aligned and also padded by viewInsets when present.
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              closed = true;
              if (_isDialogOpen) {
                setState(() => _isDialogOpen = false);
              }
            }
          },
          child: MediaQuery.removeViewInsets(
            context: ctx,
            removeBottom: true,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 36, 40, 12),
                  child: Material(
                    color: const Color(0xFF13101E),
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Native TV text field → system IME owns D-pad.
                            // deferDpadToIme: no Flutter caret remaps; native
                            // EditText does not consume DPAD (Gboard navigates).
                            SizedBox(
                              height: 48,
                              child: AndroidTVTextField(
                                controller: editCtrl,
                                focusNode: editFocus,
                                hint: 'Enter $title',
                                obscureText: obscure,
                                height: 48,
                                deferDpadToIme: true,
                                onSubmitted: (val) => closeDialog(val),
                                backgroundColor: kColorCardDark,
                                textColor: Colors.white,
                                focuesedBorderColor: kColorFocus,
                                unFocuesedBorderColor: kColorPrimary,
                                textSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Pinned action row — stays above the IME.
                            // ExcludeFocus while editing so Flutter focus
                            // traversal cannot steal arrows from Gboard.
                            ExcludeFocus(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => editCtrl.clear(),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => closeDialog(),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kColorPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        closeDialog(editCtrl.text),
                                    child: const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.white,
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (_isDialogOpen) {
        setState(() => _isDialogOpen = false);
      }
      editFocus.dispose();
      editCtrl.dispose();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _navFocus.requestFocus();
        }
      });
    });

    // After dialog route animation + PlatformView create, focus native field.
    // Then release Flutter primary focus so FlutterView stops eating DPAD while
    // the native EditText / Gboard keep Android focus (clearNativeOnUnfocus=false).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () async {
        if (!mounted || closed || !editFocus.canRequestFocus) return;
        editFocus.requestFocus();
        await Future<void>.delayed(const Duration(milliseconds: 280));
        if (!mounted || closed) return;
        if (editFocus.hasFocus) {
          editFocus.unfocus();
        }
      });
    });
  }

  void _activate([int? row]) {
    final target = row ?? _row;

    if (target == 0) {
      setState(() {
        _isM3uMode = !_isM3uMode;
        // Neutral player shell: never prefill provider hosts or credentials.
        _domain.text = '';
        _username.text = '';
        _password.text = '';
        final maxRow = _isM3uMode ? 3 : 5;
        if (_row > maxRow) {
          _row = maxRow;
        }
      });
      return;
    }

    if (_isM3uMode) {
      if (target == 1) {
        _showEditDialog('M3U Playlist URL', _domain);
      } else if (target == 2) {
        _login();
      } else if (target == 3) {
        _showHelpDialog();
      }
      return;
    } else {
      if (target == 1) {
        _showEditDialog('Server / Portal URL', _domain);
      } else if (target == 2) {
        _showEditDialog('Username', _username);
      } else if (target == 3) {
        _showEditDialog('Password', _password, obscure: true);
      } else if (target == 4) {
        _login();
      } else if (target == 5) {
        _showHelpDialog();
      }
      return;
    }
  }

  // Called when user presses Done on keyboard
  void _done(int nextRow) {
    setState(() {
      _isDialogOpen = false;
      _row = nextRow;
    });
    _navFocus.requestFocus();
    _ensureFocusedFieldVisible();
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

    // Full playlist links belong in M3U mode — don't treat them as XC hosts.
    final looksLikePlaylist = normalizedUrl.toLowerCase().contains('/api/list/') ||
        normalizedUrl.toLowerCase().endsWith('.m3u') ||
        normalizedUrl.toLowerCase().endsWith('.m3u8') ||
        normalizedUrl.toLowerCase().contains('get.php?');

    if (_isM3uMode || looksLikePlaylist) {
      if (!_isM3uMode && looksLikePlaylist) {
        setState(() => _isM3uMode = true);
      }
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
        // Shrink body when soft keyboard opens so Sign In stays visible.
        resizeToAvoidBottomInset: true,
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
                    final detail = state.message.trim();
                    final isGenericLogout = detail == 'LogOut' || detail.isEmpty;
                    showWarningToast(
                      context,
                      'Login Failed',
                      isGenericLogout
                          ? (_isM3uMode
                              ? 'Unable to sign in. Check that your M3U playlist URL is correct and reachable.'
                              : 'Unable to sign in. Please check your server URL, username, and password.')
                          : detail,
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
                                const SizedBox(height: 16),
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
                        child: LayoutBuilder(
                          builder: (context, panelConstraints) {
                            // Chromecast / short Google TV: compact so
                            // URL + username + password + Sign In fit
                            // without relying on D-pad scroll.
                            final panelH = panelConstraints.maxHeight;
                            final compact = panelH < 680;
                            final tight = panelH < 600;
                            final controlH = tight ? 40.0 : (compact ? 44.0 : 48.0);
                            final gap = tight ? 4.0 : (compact ? 6.0 : 8.0);
                            final labelGap = tight ? 2.0 : 4.0;
                            final outerV = tight ? 8.0 : (compact ? 12.0 : 20.0);
                            final outerH = compact ? 20.0 : 32.0;
                            final cardPadH = compact ? 16.0 : 24.0;
                            final cardPadV = tight ? 10.0 : (compact ? 12.0 : 16.0);
                            final showHelper = !compact;

                            Widget fieldLabel(String text) => Text(
                                  text,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: compact ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: outerH,
                                vertical: outerV,
                              ),
                              child: Align(
                                alignment: Alignment.center,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  // Force full panel height so Expanded
                                  // fields + pinned Sign In share space.
                                  // When keyboard opens, Scaffold shrinks
                                  // panelH so Sign In stays above it.
                                  child: SizedBox(
                                    height: (panelH - outerV * 2)
                                        .clamp(180.0, double.infinity),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: kColorCardLight.withValues(
                                          alpha: .8,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: cardPadH,
                                        vertical: cardPadV,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Sign in to TV Parser',
                                            style: Get.textTheme.headlineSmall!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: compact ? 18 : null,
                                                  height: 1.15,
                                                ),
                                          ),
                                          if (!tight) ...[
                                            SizedBox(height: compact ? 2 : 4),
                                            Text(
                                              'Sign in with your authorized playlist/provider credentials.',
                                              style: Get.textTheme.bodySmall!
                                                  .copyWith(
                                                    color: kColorHint,
                                                    fontSize: compact ? 10 : 11,
                                                    height: 1.2,
                                                  ),
                                            ),
                                          ],
                                          SizedBox(height: gap),

                                          fieldLabel('Connection Type'),
                                          SizedBox(height: labelGap),
                                          _TvToggle(
                                            key: const ValueKey(
                                              'toggle_m3u_mode_tv',
                                            ),
                                            height: controlH,
                                            isSelected: _row == 0,
                                            isM3uMode: _isM3uMode,
                                            onTap: () {
                                              setState(() {
                                                _isM3uMode = !_isM3uMode;
                                                // Neutral player shell: never
                                                // prefill provider hosts or
                                                // credentials.
                                                _domain.text = '';
                                                _username.text = '';
                                                _password.text = '';
                                                final maxRow =
                                                    _isM3uMode ? 3 : 5;
                                                if (_row > maxRow) {
                                                  _row = maxRow;
                                                }
                                              });
                                            },
                                          ),
                                          SizedBox(height: gap),

                                          // Fields scroll; Sign In stays pinned.
                                          Expanded(
                                            child: SingleChildScrollView(
                                              controller: _fieldsScroll,
                                              physics:
                                                  const ClampingScrollPhysics(),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  fieldLabel(
                                                    _isM3uMode
                                                        ? 'M3U Playlist URL'
                                                        : 'Server / Portal URL',
                                                  ),
                                                  SizedBox(height: labelGap),
                                                  _TvField(
                                                    key: _urlFieldKey,
                                                    controller: _domain,
                                                    hint: _isM3uMode
                                                        ? 'https://example.com/playlist.m3u'
                                                        : 'https://example.com',
                                                    icon: FontAwesomeIcons
                                                        .link.data,
                                                    focusNode: _fn2,
                                                    keyboardType:
                                                        TextInputType.url,
                                                    height: controlH,
                                                    isSelected: _row == 1,
                                                    // Editing is via top-aligned
                                                    // dialog so Save stays above IME.
                                                    isEditing: false,
                                                    onTap: () => _activate(1),
                                                    onDone: () => _done(2),
                                                    helperText: showHelper
                                                        ? (_isM3uMode
                                                            ? 'Enter the direct M3U playlist URL.'
                                                            : 'Enter the server URL provided by your authorized playlist provider.')
                                                        : null,
                                                  ),
                                                  SizedBox(height: gap),

                                                  if (!_isM3uMode) ...[
                                                    fieldLabel('Username'),
                                                    SizedBox(height: labelGap),
                                                    _TvField(
                                                      key: _usernameFieldKey,
                                                      controller: _username,
                                                      hint: 'Username',
                                                      icon: FontAwesomeIcons
                                                          .solidUser.data,
                                                      focusNode: _fn0,
                                                      keyboardType:
                                                          TextInputType.text,
                                                      height: controlH,
                                                      isSelected: _row == 2,
                                                      isEditing: false,
                                                      onTap: () =>
                                                          _activate(2),
                                                      onDone: () => _done(3),
                                                    ),
                                                    SizedBox(height: gap),
                                                    fieldLabel('Password'),
                                                    SizedBox(height: labelGap),
                                                    _TvField(
                                                      key: _passwordFieldKey,
                                                      controller: _password,
                                                      hint: 'Password',
                                                      icon: FontAwesomeIcons
                                                          .lock.data,
                                                      focusNode: _fn1,
                                                      keyboardType:
                                                          TextInputType
                                                              .visiblePassword,
                                                      height: controlH,
                                                      isSelected: _row == 3,
                                                      isEditing: false,
                                                      obscure: true,
                                                      onTap: () =>
                                                          _activate(3),
                                                      onDone: () => _done(4),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),

                                          SizedBox(height: gap),

                                          // Pinned: always visible under fields /
                                          // above soft keyboard (via Scaffold inset).
                                          KeyedSubtree(
                                            key: _signInKey,
                                            child: _TvButton(
                                              key: const ValueKey(
                                                'btn_sign_in_tv',
                                              ),
                                              label: 'Sign In',
                                              height: controlH,
                                              isSelected: _isM3uMode
                                                  ? _row == 2
                                                  : _row == 4,
                                              onTap: _login,
                                            ),
                                          ),
                                          SizedBox(height: tight ? 2 : 4),
                                          _TvTextButton(
                                            label:
                                                'Need help finding your credentials?',
                                            isSelected: _isM3uMode
                                                ? _row == 3
                                                : _row == 5,
                                            compact: compact,
                                            onTap: _showHelpDialog,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
    this.height = 48,
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
  final double height;
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
        height: height,
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
          height: height,
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
    this.height = 48,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
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
    this.compact = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
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
            fontSize: compact ? 11 : 12,
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
    this.height = 48,
  });

  final bool isSelected;
  final bool isM3uMode;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
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
