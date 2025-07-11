import 'package:chat_app/app/controllers/register_controller.dart';
import 'package:chat_app/app/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/app/themes/theme_selector_sheet.dart';

class RegisterScreen extends StatelessWidget {
  final controller = Get.put(RegisterController());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.palette_outlined, color: colorScheme.primary),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => showThemeSelectorSheet(),
                );
              },
            ),
          ),
        ],
      ),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withAlpha(50),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Welcome
              Text(
                "Are you not Signed in?",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Create a new account",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withAlpha(150),
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: controller.fullNameController,
                onChanged: controller.validateFullName,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: colorScheme.primary,
                  ),
                  errorText: controller.fullNameError.value,
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Email Field
              TextField(
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: colorScheme.onSurface),
                onChanged: controller.validateEmail,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: colorScheme.primary,
                  ),
                  errorText: controller.emailError.value,
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: _border(colorScheme),
                  enabledBorder: _border(colorScheme, alpha: 100),
                  focusedBorder: _focusedBorder(colorScheme),
                ),
              ),
              const SizedBox(height: 24),

              // Password Field
              Obx(
                () => TextField(
                  controller: controller.passwordController,
                  obscureText: controller.isPasswordHidden.value,
                  onChanged: controller.validatePassword,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isPasswordHidden.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: colorScheme.onSurface.withAlpha(150),
                      ),
                      onPressed:
                          () =>
                              controller.isPasswordHidden.value =
                                  !controller.isPasswordHidden.value,
                    ),
                    errorText: controller.passwordError.value,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: _border(colorScheme),
                    enabledBorder: _border(colorScheme, alpha: 100),
                    focusedBorder: _focusedBorder(colorScheme),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Confirm Password Field
              Obx(
                () => TextField(
                  controller: controller.confirmPasswordController,
                  obscureText: controller.isPasswordHidden.value,
                  onChanged: controller.validateConfirmPassword,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isPasswordHidden.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: colorScheme.onSurface.withAlpha(150),
                      ),
                      onPressed:
                          () =>
                              controller.isPasswordHidden.value =
                                  !controller.isPasswordHidden.value,
                    ),
                    errorText: controller.confirmPasswordError.value,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: _border(colorScheme),
                    enabledBorder: _border(colorScheme, alpha: 100),
                    focusedBorder: _focusedBorder(colorScheme),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Register Button
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton(
                    onPressed:
                        controller.isLoading.value
                            ? null
                            : controller.registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child:
                        controller.isLoading.value
                            ? const CircularProgressIndicator()
                            : const Text(
                              "Sign Up",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Login Redirect
              Center(
                child: TextButton(
                  onPressed: () => Get.to(() => LoginScreen()),
                  child: Text.rich(
                    TextSpan(
                      text: "Already have an account? ",
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(150),
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(
                          text: "Login",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(ColorScheme colorScheme, {int alpha = 255}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colorScheme.outline.withAlpha(alpha),
          width: 1,
        ),
      );

  OutlineInputBorder _focusedBorder(ColorScheme colorScheme) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      );
}
