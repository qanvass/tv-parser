part of 'widgets.dart';

// ─── HOME APP BAR ─────────────────────────────────────────────────────────────

class WelcomeAppBar extends StatelessWidget {
  const WelcomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Row(
        children: [
          // Brand pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kColorPrimary.withValues(alpha: 0.18),
                  kColorPrimaryDark.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: kColorPrimary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(
                  width: 18,
                  height: 18,
                  image: const AssetImage(kIconSplash),
                ),
                const SizedBox(width: 8),
                Text(
                  kAppName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // User info + settings
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final userInfo = state is AuthSuccess
                  ? state.user.userInfo
                  : null;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (userInfo != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userInfo.username ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Exp: ${expirationDate(userInfo.expDate)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                  ],
                  _AppBarBtn(
                    icon: FontAwesomeIcons.gear,
                    onTap: () => Get.toNamed(screenSettings),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── HOME SEARCH BAR ──────────────────────────────────────────────────────────

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kColorCardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Get.textTheme.bodyMedium!.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Get.textTheme.bodyMedium!.copyWith(color: kColorHint),
          prefixIcon: const Icon(
            FontAwesomeIcons.magnifyingGlass,
            size: 16,
            color: kColorHint,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    FontAwesomeIcons.xmark,
                    size: 14,
                    color: kColorHint,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ─── TV SIDEBAR NAV ITEM ──────────────────────────────────────────────────────

class HomeNavItem extends StatefulWidget {
  const HomeNavItem({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.autofocus = false,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<HomeNavItem> createState() => _HomeNavItemState();
}

class _HomeNavItemState extends State<HomeNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _focused;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? kColorPrimary.withValues(alpha: .18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? kColorFocus : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: active ? kColorFocus : Colors.white60,
              ),
              const SizedBox(width: 14),
              Text(
                widget.title,
                style: Get.textTheme.titleSmall!.copyWith(
                  color: active ? Colors.white : Colors.white60,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (widget.isSelected) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: kColorFocus,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MOBILE CATEGORY CARD ─────────────────────────────────────────────────────

class CategoryCardMobile extends StatelessWidget {
  const CategoryCardMobile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      focusColor: kColorFocus.withValues(alpha: 0.25),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(icon, width: 42, height: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: Get.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Get.textTheme.bodySmall!.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TV CATEGORY CARD ─────────────────────────────────────────────────────────

class CategoryCardTv extends StatefulWidget {
  const CategoryCardTv({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });

  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<CategoryCardTv> createState() => _CategoryCardTvState();
}

class _CategoryCardTvState extends State<CategoryCardTv> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _focused
                ? kColorPrimary.withValues(alpha: 0.18)
                : kColorCardLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focused ? kColorFocus : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: kColorFocus.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _focused ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Image.asset(widget.icon, width: 8.w, height: 8.w),
              ),
              SizedBox(height: 3.h),
              Text(
                widget.title,
                style: Get.textTheme.displaySmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _focused ? kColorFocus : Colors.white,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                '◍ ${widget.subtitle}',
                style: Get.textTheme.titleSmall!.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MOBILE SECONDARY ACTION CARD ────────────────────────────────────────────

class SecondaryActionCard extends StatelessWidget {
  const SecondaryActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      focusColor: kColorFocus.withValues(alpha: 0.2),
      child: Ink(
        decoration: BoxDecoration(
          color: kColorCardLight,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kColorPrimary, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: Get.textTheme.bodySmall!.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TV ACTION BUTTON ─────────────────────────────────────────────────────────

class TvActionButton extends StatefulWidget {
  const TvActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<TvActionButton> createState() => _TvActionButtonState();
}

class _TvActionButtonState extends State<TvActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            color: _focused ? kColorPrimary : kColorCardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _focused ? kColorFocus : kColorCardDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: _focused ? Colors.white : kColorPrimary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: Get.textTheme.titleSmall!.copyWith(
                  color: _focused ? Colors.white : Colors.white70,
                  fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TALL BUTTON (used in login screens) ─────────────────────────────────────

class CardTallButton extends StatelessWidget {
  const CardTallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.radius = 5,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final double radius;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        width: 100.w,
        height: 55,
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton(
          onPressed: onTap,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(kColorPrimary),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          child: isLoading
              ? LoadingAnimationWidget.staggeredDotsWave(
                  color: Colors.white,
                  size: 40,
                )
              : Text(
                  label,
                  style: Get.textTheme.headlineLarge!.copyWith(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
