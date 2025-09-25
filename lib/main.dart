import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'services/firebase_service.dart';
import 'services/api_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Initialize intl for Arabic
  await initializeDateFormatting('ar', null);
  
  // Initialize GetX services
  Get.put(FirebaseService());
  Get.put(ApiService());
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
              title: 'entkhabat',
      // Set RTL text direction for Arabic
      textDirection: TextDirection.rtl,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        // Use Cairo font for Arabic text
        fontFamily: GoogleFonts.cairo().fontFamily,
        // RTL specific theme configurations
        textTheme: GoogleFonts.cairoTextTheme().apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
        // Ensure proper RTL support for input fields
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// This file now only serves as the entry point for the app
// The main functionality is handled by the splash screen and subsequent screens
