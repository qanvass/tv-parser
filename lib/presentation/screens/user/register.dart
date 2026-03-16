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

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _fullUrl.dispose();
    super.dispose();
  }

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

  void _login(BuildContext ctx) {
    if (_username.text == 'azul-iptv' && _password.text == 'azul-iptv') {
      ctx.read<SettingsCubit>().updateStatusAccount(true);
      changeDeviceOrient();
      Get.offAndToNamed(screenWelcome);
      return;
    }
    if (_username.text.isNotEmpty &&
        _password.text.isNotEmpty &&
        _url.text.isNotEmpty) {
      ctx.read<AuthBloc>().add(
        AuthRegister(_username.text, _password.text, _url.text),
      );
    }
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
            return AzulEnvatoChecker(
              uniqueKey: settingState.setting,
              successPage: BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthFailed) {
                    showWarningToast(
                      context,
                      'Login failed.',
                      'Please check your IPTV credentials and try again.',
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
                          height: getSize(context).height * .38,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const IntroImageAnimated(),
                              // Back button overlay
                              Positioned(
                                top: MediaQuery.of(context).padding.top + 4,
                                left: 4,
                                child: IconButton(
                                  onPressed: () => Get.back(),
                                  icon: const Icon(
                                    FontAwesomeIcons.chevronLeft,
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
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign In',
                                    style: Get.textTheme.headlineMedium!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter your IPTV credentials to continue',
                                    style: Get.textTheme.bodyMedium!.copyWith(
                                      color: kColorHint,
                                    ),
                                  ),
                                  const SizedBox(height: 22),

                                  // Username
                                  _LoginFieldMobile(
                                    controller: _username,
                                    hint: 'Username',
                                    icon: FontAwesomeIcons.solidUser,
                                    style: fieldStyle,
                                  ),
                                  const SizedBox(height: 12),

                                  // Password
                                  _LoginFieldMobile(
                                    controller: _password,
                                    hint: 'Password',
                                    icon: FontAwesomeIcons.lock,
                                    obscure: true,
                                    style: fieldStyle,
                                  ),
                                  const SizedBox(height: 12),

                                  // Server URL
                                  _LoginFieldMobile(
                                    controller: _url,
                                    hint: 'http://server.domain.net:8080',
                                    icon: FontAwesomeIcons.link,
                                    style: fieldStyle,
                                  ),

                                  // Xtreme import
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _showXtremeDialog,
                                      icon: const Icon(
                                        FontAwesomeIcons.link,
                                        size: 13,
                                        color: kColorPrimary,
                                      ),
                                      label: Text(
                                        'Import Xtreme Link',
                                        style: Get.textTheme.bodySmall!
                                            .copyWith(
                                              color: kColorPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  CardTallButton(
                                    label: 'Sign In',
                                    isLoading: isLoading,
                                    onTap: () => _login(context),
                                  ),
                                  const SizedBox(height: 16),

                                  // Privacy
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'By signing in, you agree to our ',
                                        style: Get.textTheme.bodySmall!
                                            .copyWith(color: Colors.white54),
                                      ),
                                      InkWell(
                                        onTap: () async => await launchUrl(
                                          Uri.parse(kPrivacy),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                        child: Text(
                                          'privacy policy.',
                                          style: Get.textTheme.bodySmall!
                                              .copyWith(
                                                color: kColorPrimary.withValues(
                                                  alpha: .85,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
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
              ),
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
    required this.controller,
    required this.hint,
    required this.icon,
    required this.style,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextStyle style;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
