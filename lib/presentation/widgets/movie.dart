part of 'widgets.dart';

class CardMovieImagesBackground extends StatefulWidget {
  const CardMovieImagesBackground({super.key, required this.listImages});
  final List<String> listImages;

  @override
  State<CardMovieImagesBackground> createState() =>
      _CardMovieImagesBackgroundState();
}

class _CardMovieImagesBackgroundState extends State<CardMovieImagesBackground> {
  late bool isNotEmpty;
  late int sizeList;
  int indexImage = 0;

  void _runAnimation() async {
    await Future.delayed(const Duration(seconds: 5));

    if (mounted) {
      setState(() {
        if ((indexImage + 1) >= sizeList) {
          indexImage = 0;
        } else {
          indexImage = indexImage + 1;
        }
      });
      _runAnimation();
    }
  }

  @override
  void initState() {
    isNotEmpty = widget.listImages.isNotEmpty;

    if (isNotEmpty) {
      sizeList = widget.listImages.length;
      _runAnimation();
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!isNotEmpty) {
      return const SizedBox();
    }

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(seconds: 3),
          switchInCurve: Curves.easeIn,
          child: CachedNetworkImage(
            width: 100.w,
            height: 100.h,
            fit: BoxFit.cover,
            imageUrl: widget.listImages[indexImage],
            errorWidget: (_, i, e) {
              return const SizedBox();
            },
          ),
        ),
        Container(
          width: 100.w,
          height: 100.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              end: Alignment.topCenter,
              begin: Alignment.bottomCenter,
              colors: [
                kColorBackDark.withValues(alpha: 1),
                kColorBack.withValues(alpha: .5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
