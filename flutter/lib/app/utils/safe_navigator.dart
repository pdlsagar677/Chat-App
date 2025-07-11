import 'dart:async';
import 'package:get/get.dart';

class SafeNavigator {
  static void toNamed(String route, {dynamic arguments}) {
    Future.delayed(Duration.zero, () {
      Get.toNamed(route, arguments: arguments);
    });
  }

  static void offAllNamed(String route, {dynamic arguments}) {
    Future.delayed(Duration.zero, () {
      Get.offAllNamed(route, arguments: arguments);
    });
  }

  static void to(dynamic page) {
    Future.delayed(Duration.zero, () {
      Get.to(page);
    });
  }

  static void offAll(dynamic page) {
    Future.delayed(Duration.zero, () {
      Get.offAll(page);
    });
  }
}
