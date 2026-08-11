part of 'helpers.dart';

bool isTvDevice() {
  return OrientationGuard.isTv;
}

/// Phone/tablet only. Casting from Android TV / Google TV to another Cast
/// receiver is nonsense — hide Cast chrome and skip discovery on TV builds.
bool supportsCasting() => !isTvDevice();

void changeDeviceOrient() {
  OrientationGuard.applyDeviceOrientation();
}

void changeDeviceOrientBack() {
  OrientationGuard.applyDeviceOrientation();
}
