part of 'widgets.dart';

/// Shared app bar used across Live, Movies and Series screens.
///
/// Button index mapping (left → right):
///   Normal mode:  back=0, trailing[0]=1, trailing[1]=2, ..., search=trailing.length+1
///   Search mode:  back=0, close=1
///
/// Pass [focusedIndex] from the screen's appbar state to highlight the focused button.
/// Pass [isFocused] directly to [IptvAppBarAction] trailing widgets.
class IptvAppBar extends StatelessWidget {
  const IptvAppBar({
    super.key,
    required this.title,
    required this.icon,
    this.onBack,
    this.focusedIndex,
    // Search
    this.showSearch = false,
    this.searchHint = 'Search...',
    this.searchController,
    this.searchFocus,
    this.onSearchChanged,
    this.onSearchToggle,
    this.onSearchClose,
    // Extra right-side widgets
    this.trailing = const [],
  });

  final String title;
  final IconData icon;
  final VoidCallback? onBack;
  final int? focusedIndex;

  final bool showSearch;
  final String searchHint;
  final TextEditingController? searchController;
  final FocusNode? searchFocus;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchToggle;
  final VoidCallback? onSearchClose;

  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: const BoxDecoration(
        // color: Color(0xD0000000),
        // border: Border(bottom: BorderSide(color: Color(0x18FFFFFF), width: 1)),
      ),
      // padding: const EdgeInsets.symmetric(horizontal: 12),
      child: showSearch ? _buildSearchMode() : _buildNormalMode(),
    );
  }

  Widget _buildNormalMode() {
    final searchIdx = trailing.length + 1;
    return Row(
      children: [
        _AppBarBtn(
          icon: FontAwesomeIcons.chevronLeft,
          onTap: onBack ?? Get.back,
          isFocused: focusedIndex == 0,
        ),
        const SizedBox(width: 12),
        // Title pill
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
              Icon(icon, size: 14, color: kColorPrimary),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
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
        // Trailing actions (each passes its own isFocused)
        ...trailing,
        if (trailing.isNotEmpty) const SizedBox(width: 4),
        // Search toggle
        if (onSearchToggle != null)
          _AppBarBtn(
            icon: FontAwesomeIcons.magnifyingGlass,
            onTap: onSearchToggle!,
            isFocused: focusedIndex == searchIdx,
          ),
      ],
    );
  }

  Widget _buildSearchMode() {
    return Row(
      children: [
        _AppBarBtn(
          icon: FontAwesomeIcons.chevronLeft,
          onTap: onBack ?? Get.back,
          isFocused: focusedIndex == 0,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: kColorPrimary.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  FontAwesomeIcons.magnifyingGlass,
                  size: 13,
                  color: kColorPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocus,
                    autofocus: true,
                    onChanged: onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _AppBarBtn(
          icon: FontAwesomeIcons.xmark,
          onTap: onSearchClose ?? () {},
          isFocused: focusedIndex == 1,
        ),
      ],
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  const _AppBarBtn({
    required this.icon,
    required this.onTap,
    this.isFocused = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isFocused
              ? kColorPrimary
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused
                ? kColorFocus
                : Colors.white.withValues(alpha: 0.09),
            width: isFocused ? 2 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}

/// Reusable icon-only action button for appbar trailing area.
/// Pass [isFocused] from the parent screen's appbar state.
class IptvAppBarAction extends StatelessWidget {
  const IptvAppBarAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.isFocused = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isFocused
              ? kColorPrimary
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused
                ? kColorFocus
                : Colors.white.withValues(alpha: 0.09),
            width: isFocused ? 2 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: kColorFocus.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Icon(icon, color: isFocused ? Colors.white : color, size: 14),
      ),
    );
  }
}
