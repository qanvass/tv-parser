part of '../screens.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Ink(
        width: double.infinity,
        height: double.infinity,
        decoration: kDecorBackground,
        child: Column(
          children: [
            // ── Hero image ──────────────────────────────────────────
            Expanded(
              flex: 5,
              child: const IntroImageAnimated(),
            ),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch films anywhere\nand anytime',
                      style: Get.textTheme.headlineLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      'Enjoy your favorite movies, live TV, and series '
                      'wherever you like.',
                      style: Get.textTheme.bodyMedium!.copyWith(
                        color: kColorHint,
                      ),
                    ),
                    const Spacer(),
                    CardTallButton(
                      label: 'Get Started',
                      radius: 12,
                      onTap: () => Get.toNamed(screenRegister),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
