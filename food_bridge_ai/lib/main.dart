import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/user_provider.dart';
import 'providers/donation_provider.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error catcher for physical device debugging
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  ErrorWidget.builder = (details) {
    // Silently handle widget crashes in release/presentation modes
    return const SizedBox.shrink();
  };

  // Avoid duplicate-app errors on hot restart or re-entry.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  try {
    runApp(const FoodBridgeApp());

    // Defer non-critical Firebase work until after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.initialize().catchError((e) {
        debugPrint('Notification Init Error: $e');
      });
      FirebaseService.isSeeded().then((seeded) {
        if (!seeded) {
          FirebaseService.seedDemoData().catchError((e) => null);
        }
      }).catchError((e) => null);
    });
  } catch (e) {
    debugPrint('CRITICAL APP STARTUP ERROR: $e');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Oh no! We couldn\'t connect to the servers right now.\n\nPlease check your internet and restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ));
  }
}

class FoodBridgeApp extends StatelessWidget {
  const FoodBridgeApp({super.key});

  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DonationProvider()),
      ],
      child: MaterialApp(
        title: 'Food Flow AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        scaffoldMessengerKey: FoodBridgeApp.messengerKey,
        home: const SplashScreen(),
      ),
    );
  }
}
