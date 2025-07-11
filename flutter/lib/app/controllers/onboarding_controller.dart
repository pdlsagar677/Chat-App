import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OnboardingController extends GetxController {
  final pageController = PageController();
  final currentPage = 0.obs;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/chat1.png",
      "title": "Welcome to Let's Chat",
      "description": "Connect with friends and family anytime, anywhere.",
    },
    {
      "image": "assets/images/chat2.png",
      "title": "Private & Secure",
      "description": "Conversations are protected with end-to-end encryption.",
    },
    {
      "image": "assets/images/chat3.png",
      "title": "Stay Connected",
      "description": "Join your community and stay updated in real-time.",
    },
  ];

  void nextPage() {
    if (currentPage.value == onboardingData.length - 1) {
      Get.offNamed('/LoginScreen'); // Or use Get.off(() => LoginScreen());
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void skip() {
    Get.offNamed('/LoginScreen');
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
