import 'package:chat_app/app/controllers/login_controller.dart';
import 'package:chat_app/app/screens/auth/register_screen.dart';
import 'package:chat_app/app/screens/home/home_screen.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/app/themes/theme_selector_sheet.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key}); // Added const constructor

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final controller = Get.put(LoginController());

    // Initialize text controllers
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final RxBool isPasswordHidden = true.obs;

    // Get theme colors
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
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.palette_outlined, color: colorScheme.primary),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => showThemeSelectorSheet(),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Icon with theme-aware styling
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
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

            // Welcome Text
            Text(
              "Welcome Back",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Sign in to your account",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),

            // Email Field
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: "Email",
                hintText: "you@example.com",
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: colorScheme.primary,
                ),
                labelStyle: TextStyle(color: colorScheme.primary),
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.outline, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colorScheme.error, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Password Field
            Obx(
              () => TextField(
                controller: passwordController,
                obscureText: isPasswordHidden.value,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordHidden.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed:
                        () => isPasswordHidden.value = !isPasswordHidden.value,
                  ),
                  labelStyle: TextStyle(color: colorScheme.primary),
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
                      color: colorScheme.outline.withValues(alpha: 0.5),
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.error, width: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Forgot Password Link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement forgot password functionality
                },
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sign In Button - Updated with clean navigation
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.all(
                    colorScheme.onPrimary.withValues(alpha: 0.1),
                  ),
                ),
                onPressed:
                    () => _handleLogin(emailController, passwordController),
                child: Text(
                  "Sign In",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Divider with "OR"
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "OR",
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Social Login Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleGoogleSignIn(),
                    icon: Icon(
                      Icons.g_mobiledata,
                      color: colorScheme.onSurface,
                      size: 24,
                    ),
                    label: Text(
                      "Google",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleAppleSignIn(),
                    icon: Icon(
                      Icons.apple,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                    label: Text(
                      "Apple",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Create Account Text
            Center(
              child: TextButton(
                onPressed: () => _navigateToRegister(),
                child: Text.rich(
                  TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(
                        text: "Create Account",
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _handleLogin(
    TextEditingController emailController,
    TextEditingController passwordController,
  ) {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        "Error",
        "Please fill in all fields",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final loginController = Get.find<LoginController>();
    loginController.loginUser(email, password);
  }

  // Handle Google Sign In
  void _handleGoogleSignIn() {
    // TODO: Implement Google Sign In logic
    Get.snackbar(
      "Info",
      "Google Sign In not implemented yet",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.secondary,
      colorText: Get.theme.colorScheme.onSecondary,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
    );
  }

  // Handle Apple Sign In
  void _handleAppleSignIn() {
    // TODO: Implement Apple Sign In logic
    Get.snackbar(
      "Info",
      "Apple Sign In not implemented yet",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.secondary,
      colorText: Get.theme.colorScheme.onSecondary,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
    );
  }

  // Navigate to Register Screen
  void _navigateToRegister() {
    Get.to(
      () => RegisterScreen(),
      arguments: "Data received from login screen",
    );
  }
}
