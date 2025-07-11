import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/app_theme.dart';
import '../controllers/theme_controller.dart';

Widget showThemeSelectorSheet() {
  final themeController = Get.find<ThemeController>();

  return Obx(
    () => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choose Theme",
              style: Get.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Toggle Buttons for system, light, dark
            ToggleButtons(
              isSelected: List.generate(3, (index) {
                final modes = [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ];
                final selectedMode = themeController.themeMode.value;
                if (modes[index] == ThemeMode.light) {
                  return selectedMode == ThemeMode.light &&
                      themeController.currentCustomTheme.isEmpty;
                }
                return selectedMode == modes[index] &&
                    themeController.currentCustomTheme.isEmpty;
              }),
              onPressed: (index) {
                final modes = [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ];
                themeController.setThemeMode(modes[index]);
                Get.back();
              },
              borderRadius: BorderRadius.circular(12),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("System"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Light"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Dark"),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Custom Themes", style: Get.textTheme.titleMedium),
            ),
            const SizedBox(height: 12),

            // Custom theme preview tiles
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  AppThemes.allThemes.keys
                      .where((k) => k != 'Light' && k != 'Dark')
                      .map((themeName) {
                        final theme = AppThemes.allThemes[themeName]!;
                        final isSelected =
                            themeController.currentCustomTheme.value ==
                            themeName;

                        // Get colors from theme
                        final backgroundColor = theme.scaffoldBackgroundColor;
                        final primaryColor = theme.primaryColor;
                        final textColor =
                            theme.textTheme.bodyLarge?.color ??
                            (theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black);

                        return GestureDetector(
                          onTap: () {
                            themeController.setCustomTheme(themeName);
                            Get.back();

                            // Show confirmation snackbar
                            Get.snackbar(
                              "Theme Applied",
                              "$themeName theme is now active",
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                              backgroundColor: theme.cardColor,
                              colorText: textColor,
                              margin: const EdgeInsets.all(16),
                              borderRadius: 12,
                              snackStyle: SnackStyle.FLOATING,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? primaryColor
                                        : Colors.transparent,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                      : null,
                            ),
                            width: 120,
                            height: 120,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Theme preview colors
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  themeName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Apply",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
