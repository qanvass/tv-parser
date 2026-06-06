part of 'helpers.dart';

bool isTvDevice() {
  return OrientationGuard.isTv;
}

void changeDeviceOrient() {
  OrientationGuard.applyDeviceOrientation();
}

void changeDeviceOrientBack() {
  OrientationGuard.applyDeviceOrientation();
}
