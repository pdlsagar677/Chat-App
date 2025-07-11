import 'package:chat_app/app/controllers/auth_controller.dart';
import 'package:chat_app/app/controllers/message_controller.dart';
import 'package:chat_app/app/controllers/theme_controller.dart';
import 'package:chat_app/app/screens/auth/login_screen.dart';
import 'package:chat_app/app/screens/auth/register_screen.dart';
import 'package:chat_app/app/screens/chat/chat_screen.dart';
import 'package:chat_app/app/screens/home/home_screen.dart';
import 'package:chat_app/app/screens/onboarding/onboarding_screen.dart';
import 'package:chat_app/app/screens/splash/splash_screen.dart';
import 'package:chat_app/app/services/socket_service.dart';
import 'package:chat_app/app/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize GetStorage first
    await GetStorage.init();

    // Load environment variables (optional, with fallback)
    try {
      await dotenv.load(fileName: "assets/.env");
    } catch (e) {
      print('Warning: Could not load .env file: $e');
    }

    // Initialize services
    final storage = GetStorage();
    final baseUrl = 'http://172.16.3.39:5001';
    final authToken = storage.read('auth_token') ?? '';
    final userId = storage.read('user_id') ?? '';

    // Register SocketService before any Get.find<SocketService>() is used
    final socketService = SocketService(baseUrl: baseUrl);

    // Only initialize socket if we have valid credentials
    if (userId.isNotEmpty && authToken.isNotEmpty) {
      try {
        await socketService.initSocket(userId: userId, token: authToken);
        await socketService.connect();
        print('[Main] ✅ Socket initialized and connected');
      } catch (e) {
        print('[Main] ⚠️ Could not initialize socket: $e');
      }
    }

    // Register services and controllers
    Get.put(socketService);
    Get.put(ThemeController());
    Get.put(AuthController());
    Get.put(MessageController());

    runApp(MyApp());
  } catch (e) {
    print('Error during app initialization: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      init: ThemeController(),
      builder: (themeController) {
        return Obx(() {
          final String customTheme = themeController.currentCustomTheme.value;
          final ThemeMode mode = themeController.themeMode.value;

          return GetMaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Lets Chat',

            // Use ThemeMode only if no custom theme is selected
            themeMode: customTheme.isEmpty ? mode : ThemeMode.light,

            // If custom theme is selected, apply it; otherwise use default light theme
            theme: AppThemes.allThemes[customTheme] ?? ThemeData.light(),

            // Dark theme used only when themeMode == dark
            darkTheme: ThemeData.dark(),
            builder: (context, child) {
              return AnimatedTheme(
                data: Theme.of(context),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: child!,
              );
            },

            initialRoute: '/LoginScreen',
            getPages: [
              // GetPage(name: '/SplashScreen', page: () => const SplashScreen()),
              // GetPage(
              //   name: '/OnboardingScreen',
              //   page: () => const OnboardingScreen(),
              // ),
              GetPage(name: '/LoginScreen', page: () => LoginScreen()),
              GetPage(name: '/RegisterScreen', page: () => RegisterScreen()),
              GetPage(name: '/HomeScreen', page: () => HomeScreen()),
              GetPage(
                name: '/ChatScreen',
                page: () {
                  final args = Get.arguments as Map<String, dynamic>?;
                  return ChatScreen(
                    receiverId: args?['userId'] ?? '',
                    receiverName: args?['userName'] ?? 'Unknown',
                  );
                },
              ),
            ],
          );
        });
      },
    );
  }
}

// Error app to show if initialization fails
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'App Initialization Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
