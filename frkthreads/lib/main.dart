import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:frkthreads/screens/splashscreen.dart';
import 'package:frkthreads/screens/homescreen.dart';
import 'package:frkthreads/screens/signinscreen.dart';
import 'package:provider/provider.dart';
import 'package:frkthreads/providers/theme_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:frkthreads/services/local_notification_service.dart';
import 'package:frkthreads/screens/auth_wrapper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize local notifications
  await LocalNotificationService.instance.initialize();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          // Add page transition animations
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case '/':
                page = const SplashScreen();
                break;
              case '/home':
                page = const HomeScreen();
                break;
              case '/signin':
                page = const SignInScreen();
                break;
              default:
                page = const SplashScreen();
            }
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (context, animation, secondaryAnimation) {
                return AnimationConfiguration.staggeredList(
                  position: 0,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: page,
                    ),
                  ),
                );
              },
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: curve),
                );
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        );
      },
    );
  }
}
