part of '../screens.dart';

class RegisterUserTv extends StatefulWidget {
  const RegisterUserTv({super.key});

  @override
  State<RegisterUserTv> createState() => _RegisterUserTvState();
}

class _RegisterUserTvState extends State<RegisterUserTv> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _domain = TextEditingController();

  // 0=username, 1=password, 2=url, 3=button
  int _row = 0;
  // true while a TextField keyboard is open
  bool _editing = false;

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

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _row = (_row + 1).clamp(0, 3));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _row = (_row - 1).clamp(0, 3));
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

  void _activate() {
    if (_row == 3) {
      _login();
      return;
    }
    setState(() => _editing = true);
    [_fn0, _fn1, _fn2][_row].requestFocus();
  }

  // Called when user presses Done on keyboard
  void _done(int nextRow) {
    setState(() {
      _editing = false;
      _row = nextRow;
    });
    _navFocus.requestFocus();
  }

  void _login() {
    if (_username.text == 'azul-demo' && _password.text == 'azul-demo') {
      context.read<SettingsCubit>().updateStatusAccount(true);
      Get.offAndToNamed(screenWelcome);
      return;
    }
    if (_username.text.isNotEmpty &&
        _password.text.isNotEmpty &&
        _domain.text.isNotEmpty) {
      context.read<AuthBloc>().add(
        AuthRegister(_username.text, _password.text, _domain.text),
      );
    }
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
              return AzulEnvatoChecker(
                uniqueKey: settingState.setting,
                successPage: BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      context.read<LiveCatyBloc>().add(GetLiveCategories());
                      context.read<MovieCatyBloc>().add(GetMovieCategories());
                      context.read<SeriesCatyBloc>().add(GetSeriesCategories());
                      Get.offAndToNamed(screenWelcome);
                    } else if (state is AuthFailed) {
                      showWarningToast(
                        context,
                        'Login failed.',
                        'Please check your IPTV credentials and try again.',
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
                                    kIconSplash,
                                    width: getSize(context).height * .22,
                                    height: getSize(context).height * .22,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    kAppName,
                                    style: Get.textTheme.headlineLarge!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Your premium IPTV experience',
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Sign In',
                                      style: Get.textTheme.headlineMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),

                                    const SizedBox(height: 24),

                                    _TvField(
                                      controller: _username,
                                      hint: 'Username',
                                      icon: FontAwesomeIcons.solidUser,
                                      focusNode: _fn0,
                                      keyboardType: TextInputType.text,
                                      isSelected: _row == 0,
                                      isEditing: _editing && _row == 0,
                                      onDone: () => _done(1),
                                    ),
                                    const SizedBox(height: 12),

                                    _TvField(
                                      controller: _password,
                                      hint: 'Password',
                                      icon: FontAwesomeIcons.lock,
                                      focusNode: _fn1,
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      isSelected: _row == 1,
                                      isEditing: _editing && _row == 1,
                                      obscure: true,
                                      onDone: () => _done(2),
                                    ),
                                    const SizedBox(height: 12),

                                    _TvField(
                                      controller: _domain,
                                      hint: 'http://server.domain.net:8080',
                                      icon: FontAwesomeIcons.link,
                                      focusNode: _fn2,
                                      keyboardType: TextInputType.url,
                                      isSelected: _row == 2,
                                      isEditing: _editing && _row == 2,
                                      onDone: () => _done(3),
                                    ),
                                    const SizedBox(height: 20),

                                    _TvButton(
                                      isSelected: _row == 3,
                                      onTap: _login,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
    required this.controller,
    required this.hint,
    required this.icon,
    required this.focusNode,
    required this.keyboardType,
    required this.isSelected,
    required this.isEditing,
    required this.onDone,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final bool isSelected; // D-pad is on this row
  final bool isEditing; // keyboard is open for this row
  final bool obscure;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 52,
      decoration: BoxDecoration(
        color: isEditing ? Colors.white : kColorCardDark,
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
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: isEditing,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onDone(),
        style: TextStyle(
          color: isEditing ? Colors.black87 : Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isEditing ? Colors.grey : kColorHint,
            fontSize: 14,
          ),
          suffixIcon: Icon(
            icon,
            size: 16,
            color: isEditing ? kColorPrimaryDark : kColorPrimary,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        cursorColor: kColorPrimary,
      ),
    );
  }
}

// ─── TV Button ────────────────────────────────────────────────────────────────

class _TvButton extends StatelessWidget {
  const _TvButton({required this.isSelected, required this.onTap});

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
          'Sign In',
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
