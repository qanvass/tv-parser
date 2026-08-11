part of '../screens.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _url = TextEditingController();
  final _fullUrl = TextEditingController();
  bool _isM3uMode = false;

  @override
  void initState() {
    super.initState();
    _url.text = '';
    _username.text = '';
    _password.text = '';
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _fullUrl.dispose();
    super.dispose();
  }

  /*
  void _showXtremeDialog() {
    final style = Get.textTheme.bodyMedium!.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );
    showDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Import Xtreme API Link'),
        content: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _fullUrl,
              decoration: InputDecoration(
                hintText:
                    'http://domain.tr:8080/get.php?username=user&password=pass',
                hintStyle: Get.textTheme.bodySmall!.copyWith(
                  color: Colors.grey,
                ),
              ),
              style: style,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _fullUrl.clear();
              Get.back();
            },
            child: Text(
              'Cancel',
              style: Get.textTheme.bodyMedium!.copyWith(
                color: Colors.grey.shade400,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final txt = _fullUrl.text.trim();
              if (txt.isEmpty) return;
              if (Uri.tryParse(txt)?.hasAbsolutePath ?? false) {
                final uri = Uri.parse(txt);
                final params = uri.queryParameters;
                _username.text = params['username'] ?? '';
                _password.text = params['password'] ?? '';
                _url.text =
                    '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}';
                Get.back();
              } else {
                Get.snackbar('Error', 'Invalid URL format');
              }
            },
            child: Text(
              'Import',
              style: Get.textTheme.bodyMedium!.copyWith(color: kColorPrimary),
            ),
          ),
        ],
      ),
    );
  }
  */

  void _login(BuildContext ctx) {
    final rawUrl = _url.text.trim();
    if (rawUrl.isEmpty) {
      showWarningToast(
        context,
        _isM3uMode ? 'Playlist URL Required' : 'Server URL Required',
        _isM3uMode
            ? 'Please enter your M3U playlist URL to continue.'
            : 'Please enter your Server / Portal URL to continue.',
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
        'Please enter a valid URL starting with http:// or https://',
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
      ctx.read<AuthBloc>().add(AuthLoadM3u(normalizedUrl));
      return;
    }

    final username = _username.text.trim();
    final password = _password.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showWarningToast(
        context,
        'Credentials Required',
        'Please enter your username and password.',
      );
      return;
    }

    ctx.read<AuthBloc>().add(AuthRegister(username, password, normalizedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = Get.textTheme.bodyMedium!.copyWith(
      color: Colors.white,
      fontSize: 15.sp,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      body: Ink(
        width: double.infinity,
        height: double.infinity,
        decoration: kDecorBackground,
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settingState) {
            return BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthFailed) {
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
                } else if (state is AuthSuccess) {
                  context.read<LiveCatyBloc>().add(GetLiveCategories());
                  context.read<MovieCatyBloc>().add(GetMovieCategories());
                  context.read<SeriesCatyBloc>().add(GetSeriesCategories());
                  changeDeviceOrient();
                  Get.offAndToNamed(screenWelcome);
                }
              },
              builder: (context, state) {
                final isLoading = state is AuthLoading;
                return IgnorePointer(
                  ignoring: isLoading,
                  child: Column(
                    children: [
                      // ── Hero section ──────────────────────────────
                      SizedBox(
                        height: getSize(context).height * .26,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const IntroImageAnimated(),
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 4,
                              left: 4,
                              child: IconButton(
                                onPressed: () => Get.back(),
                                icon: Icon(
                                  FontAwesomeIcons.chevronLeft.data,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Form section ──────────────────────────────
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: kDecorBackground.gradient,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. App logo
                                Center(
                                  child: Image.asset(
                                    kIconLogoTransparent,
                                    height: 56,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 2. “Sign in to TV Parser”
                                Center(
                                  child: Text(
                                    'Sign in to TV Parser',
                                    style: Get.textTheme.headlineMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 18.sp,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // 3. Subtitle: “Use your authorized provider credentials.”
                                Center(
                                  child: Text(
                                    'Use your authorized provider credentials.\nSign in with your authorized playlist/provider credentials.',
                                    textAlign: TextAlign.center,
                                    style: Get.textTheme.bodyMedium!.copyWith(
                                      color: kColorHint,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Mode Switcher Toggle
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B1828),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          key: const ValueKey(
                                            'toggle_xtream_mode',
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _isM3uMode = false;
                                              _url.text = '';
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: !_isM3uMode
                                                  ? kColorPrimary
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Xtream Codes API',
                                              style: TextStyle(
                                                color: !_isM3uMode
                                                    ? Colors.white
                                                    : Colors.white60,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          key: const ValueKey(
                                            'toggle_m3u_mode',
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _isM3uMode = true;
                                              _url.text = '';
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _isM3uMode
                                                  ? kColorPrimary
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'M3U Playlist URL',
                                              style: TextStyle(
                                                color: _isM3uMode
                                                    ? Colors.white
                                                    : Colors.white60,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // 4. Server / Playlist URL field
                                Text(
                                  _isM3uMode
                                      ? "M3U Playlist URL"
                                      : "Server / Portal URL",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _LoginFieldMobile(
                                  key: const ValueKey('field_url'),
                                  controller: _url,
                                  hint: _isM3uMode
                                      ? 'https://example.com/playlist.m3u'
                                      : 'https://example.com',
                                  icon: FontAwesomeIcons.link.data,
                                  style: fieldStyle,
                                  helperText: _isM3uMode
                                      ? 'Enter the direct M3U playlist URL.'
                                      : 'Enter the server URL provided by your authorized playlist provider.',
                                ),
                                const SizedBox(height: 14),

                                if (!_isM3uMode) ...[
                                  // 5. Username field
                                  Text(
                                    "Username",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _LoginFieldMobile(
                                    controller: _username,
                                    hint: 'Username',
                                    icon: FontAwesomeIcons.solidUser.data,
                                    style: fieldStyle,
                                  ),
                                  const SizedBox(height: 14),

                                  // 6. Password field
                                  Text(
                                    "Password",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _LoginFieldMobile(
                                    controller: _password,
                                    hint: 'Password',
                                    icon: FontAwesomeIcons.lock.data,
                                    obscure: true,
                                    style: fieldStyle,
                                  ),
                                  const SizedBox(height: 24),
                                ] else ...[
                                  const SizedBox(height: 10),
                                ],

                                // 7. Sign In button
                                CardTallButton(
                                  key: const ValueKey('btn_sign_in'),
                                  label: 'Sign In',
                                  isLoading: isLoading,
                                  onTap: () => _login(context),
                                ),
                                const SizedBox(height: 12),

                                // 8. Optional “Need help finding your credentials?” link
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF13101E,
                                          ),
                                          title: const Text(
                                            'Need Help?',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          content: const Text(
                                            'Please contact your playlist provider or administrator to retrieve your Server URL, Username, and Password.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Get.back(),
                                              child: const Text(
                                                'OK',
                                                style: TextStyle(
                                                  color: kColorPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      "Need help finding your credentials?",
                                      style: TextStyle(
                                        color: kColorPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Mobile form field ────────────────────────────────────────────────────────

class _LoginFieldMobile extends StatelessWidget {
  const _LoginFieldMobile({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.style,
    this.obscure = false,
    this.helperText,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextStyle style;
  final bool obscure;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: kColorCardLight,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: style,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(top: 12),
              hintText: hint,
              hintStyle: Get.textTheme.bodyMedium!.copyWith(color: kColorHint),
              suffixIcon: Icon(icon, size: 16, color: kColorPrimary),
              border: InputBorder.none,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              helperText!,
              style: Get.textTheme.bodySmall!.copyWith(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
