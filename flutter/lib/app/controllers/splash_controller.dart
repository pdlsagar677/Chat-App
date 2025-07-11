import 'dart:async';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SplashController extends GetxController {
  final GetStorage storage = GetStorage();

  @override
  void onInit() {
    super.onInit();

    // Wait 2.5 seconds before checking navigation
    Timer(const Duration(seconds: 2), () {
      bool? seenOnboarding = storage.read('onboarding_seen');

      if (seenOnboarding == true) {
        Get.offNamed('/loginScreen');
      } else {
        Get.offNamed('/onboardingScreen');
      }
    });
  }
}
