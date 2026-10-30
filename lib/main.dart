import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/screens/splash_screen.dart';
import 'package:chatty/services/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

// global object accessing device screen size
Size mq = Size.zero;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // entering full screen
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await _initializeFirebase();
  await ThemeController.init();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Chatty',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

_initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);
}