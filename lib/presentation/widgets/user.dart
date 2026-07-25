part of 'widgets.dart';

class CardInputTv extends StatelessWidget {
  const CardInputTv({
    super.key,
    this.controller,
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.onTap,
    this.onEditingComplete,
    required this.isFocused,
    required this.isEnabled,
  });
  final TextEditingController? controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final Function() onTap;
  final Function()? onEditingComplete;

  final bool isFocused, isEnabled;

  @override
  Widget build(BuildContext context) {
    final style = Get.textTheme.bodyMedium!.copyWith(
      color: Colors.black,
      fontSize: 14.sp,
      fontWeight: FontWeight.bold,
    );

    return SizedBox(
      width: getSize(context).width,
      height: 50,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused ? kColorPrimary : Colors.transparent,
              width: 3,
            ),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: TextField(
            controller: controller,
            enabled: isEnabled,
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: Get.textTheme.bodyMedium!.copyWith(color: Colors.grey),
              suffixIcon: Icon(icon, size: 18, color: kColorPrimary),
              border: InputBorder.none,
            ),
            cursorColor: kColorPrimary,
            style: style,
          ),
        ),
      ),
    );
  }
}

class IntroImageAnimated extends StatelessWidget {
  final bool isTv;
  const IntroImageAnimated({super.key, this.isTv = false});

  @override
  Widget build(BuildContext context) {
    final height = getSize(context).height / (isTv ? 1 : 2);
    return Container(
      width: getSize(context).width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF35105E), Color(0xFF171121), Color(0xFF07070B)],
        ),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        kIconLogoTransparent,
        width: isTv ? 340 : 69.w,
        fit: BoxFit.contain,
        semanticLabel: 'TV Parser',
      ),
    );
  }
}
