part of 'helpers.dart';

void showWarningToast(BuildContext context, String title, String message) {
  final snackBar = SnackBar(
    elevation: 15,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: ContentType.failure,
      color: kColorPrimary,
      inMaterialBanner: true,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

void showSoftToast(BuildContext context, String title, String message) {
  final snackBar = SnackBar(
    elevation: 15,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: ContentType.success,
      inMaterialBanner: true,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}
