import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../themes/app_theme.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _themeModeKey = 'themeMode';
  final _customThemeKey = 'customTheme';

  Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  RxString currentCustomTheme = ''.obs;
  Rx<ThemeData> currentTheme = ThemeData.light().obs;

  @override
  void onInit() {
    super.onInit();
    themeMode.value = _loadThemeMode();
    currentCustomTheme.value = _box.read(_customThemeKey) ?? '';
    _updateCurrentTheme();
    _applyTheme();
  }

  ThemeMode _loadThemeMode() {
    final saved = _box.read(_themeModeKey);
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    currentCustomTheme.value = ''; // Reset custom theme
    _saveThemeMode(mode);
    _updateCurrentTheme();
    _applyTheme();
  }

  void setCustomTheme(String themeName) {
    currentCustomTheme.value = themeName;
    _box.write(_customThemeKey, themeName);
    _updateCurrentTheme();
    _applyTheme();
  }

  void _updateCurrentTheme() {
    if (currentCustomTheme.value.isNotEmpty) {
      currentTheme.value =
          AppThemes.allThemes[currentCustomTheme.value] ?? ThemeData.light();
    } else {
      switch (themeMode.value) {
        case ThemeMode.light:
          currentTheme.value = ThemeData.light();
          break;
        case ThemeMode.dark:
          currentTheme.value = ThemeData.dark();
          break;
        case ThemeMode.system:
          final brightness =
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          currentTheme.value =
              brightness == Brightness.dark
                  ? ThemeData.dark()
                  : ThemeData.light();
          break;
      }
    }
  }

  void _applyTheme() {
    if (currentCustomTheme.value.isNotEmpty) {
      final customTheme = AppThemes.allThemes[currentCustomTheme.value];
      if (customTheme != null) {
        Get.changeTheme(customTheme);
        return;
      }
    }

    Get.changeThemeMode(themeMode.value);
  }

  void _saveThemeMode(ThemeMode mode) {
    _box.write(_themeModeKey, mode.toString().split('.').last);
  }

  // Helper method to get current effective theme
  ThemeData getEffectiveTheme() {
    if (currentCustomTheme.value.isNotEmpty) {
      return AppThemes.allThemes[currentCustomTheme.value] ?? ThemeData.light();
    }

    switch (themeMode.value) {
      case ThemeMode.light:
        return ThemeData.light();
      case ThemeMode.dark:
        return ThemeData.dark();
      case ThemeMode.system:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light();
    }
  }
}
