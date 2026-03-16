part of 'screens.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FavoritesCubit>().initialData();
    context.read<WatchingCubit>().initialData();
  }

  @override
  Widget build(BuildContext context) {
    return const _HomeTvLayout();
  }
}

// ─── TV LAYOUT ────────────────────────────────────────────────────────────────
// Simple card grid — same look as original but with working D-pad focus.
//
// Layout:
//   Row 0 → [Live TV]  [Movies]  [Series]      (items 0,1,2)
//   Row 1 → [Favorites] [Catch Up] [Settings]  (items 3,4,5)
//
// Remote:  ◄ ► move within row  |  ▼▲ switch rows  |  OK/Enter activates

class _HomeTvLayout extends StatefulWidget {
  const _HomeTvLayout({super.key});

  @override
  State<_HomeTvLayout> createState() => _HomeTvLayoutState();
}

class _HomeTvLayoutState extends State<_HomeTvLayout> {
  // 0-2 = top row cards, 3-5 = bottom row buttons
  int _focused = 0;
  final FocusNode _navFocus = FocusNode();

  @override
  void dispose() {
    _navFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight) {
      final max = _focused < 3 ? 2 : 5;
      if (_focused < max) setState(() => _focused++);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final min = _focused < 3 ? 0 : 3;
      if (_focused > min) setState(() => _focused--);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _focused < 3) {
      setState(() => _focused = 3);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _focused >= 3) {
      setState(() => _focused = 0);
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
    switch (_focused) {
      case 0:
        Get.toNamed(screenLiveCategories);
      case 1:
        Get.toNamed(screenMovieCategories);
      case 2:
        Get.toNamed(screenSeriesCategories);
      case 3:
        Get.toNamed(screenFavourite);
      case 4:
        Get.toNamed(screenCatchUp);
      case 5:
        Get.toNamed(screenSettings);
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
          width: double.infinity,
          height: double.infinity,
          decoration: kDecorBackground,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            children: [
              // ── App bar ──────────────────────────────────────────────
              const WelcomeAppBar(),
              const SizedBox(height: 32),

              // ── Main category cards ──────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _TvCard(
                        title: 'Live TV',

                        icon: kIconLive,
                        isFocused: _focused == 0,
                        onTap: () => Get.toNamed(screenLiveCategories),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _TvCard(
                        title: 'Movies',

                        icon: kIconMovies,
                        isFocused: _focused == 1,
                        onTap: () => Get.toNamed(screenMovieCategories),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _TvCard(
                        title: 'Series',

                        icon: kIconSeries,
                        isFocused: _focused == 2,
                        onTap: () => Get.toNamed(screenSeriesCategories),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Secondary action buttons ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TvActionBtn(
                    title: 'Favourites',
                    icon: FontAwesomeIcons.heart,
                    isFocused: _focused == 3,
                    onTap: () => Get.toNamed(screenFavourite),
                  ),
                  const SizedBox(width: 20),
                  _TvActionBtn(
                    title: 'Catch Up',
                    icon: FontAwesomeIcons.rotate,
                    isFocused: _focused == 4,
                    onTap: () => Get.toNamed(screenCatchUp),
                  ),
                  const SizedBox(width: 20),
                  _TvActionBtn(
                    title: 'Settings',
                    icon: FontAwesomeIcons.gear,
                    isFocused: _focused == 5,
                    onTap: () => Get.toNamed(screenSettings),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TV Card ──────────────────────────────────────────────────────────────────

class _TvCard extends StatelessWidget {
  const _TvCard({
    required this.title,

    required this.icon,
    required this.isFocused,
    required this.onTap,
  });

  final String title;

  final String icon;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isFocused
              ? kColorPrimary.withValues(alpha: .18)
              : kColorCardLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isFocused ? kColorFocus : Colors.transparent,
            width: 3,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .45),
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
              scale: isFocused ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Image.asset(icon, width: 8.w, height: 8.w),
            ),
            SizedBox(height: 3.h),
            Text(
              title,
              style: Get.textTheme.displaySmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: isFocused ? kColorFocus : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TV Action Button ─────────────────────────────────────────────────────────

class _TvActionBtn extends StatelessWidget {
  const _TvActionBtn({
    required this.title,
    required this.icon,
    required this.isFocused,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: isFocused ? kColorPrimary : kColorCardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isFocused ? kColorFocus : kColorCardDark),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: .4),
                    blurRadius: 14,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isFocused ? Colors.white : kColorPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: Get.textTheme.titleSmall!.copyWith(
                color: isFocused ? Colors.white : Colors.white70,
                fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: kColorPrimary));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(FontAwesomeIcons.boxOpen, size: 40, color: kColorHint),
        const SizedBox(height: 12),
        Text(
          label,
          style: Get.textTheme.bodyMedium!.copyWith(color: kColorHint),
        ),
      ],
    ),
  );
}
