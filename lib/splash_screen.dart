import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/connection_error_screen.dart';
import 'services/connectivity_service.dart';
import 'services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _textScaleAnimation;
  final ConnectivityService _connectivityService = Get.put(ConnectivityService());
  final AuthService _authService = Get.put(AuthService());

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Text animation
    _textScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.bounceOut),
    );

    // Start animation and check connectivity
    _textController.forward();
    _checkAndNavigate();
  }

  void _checkAndNavigate() async {
    // Wait for splash animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Check Firebase and internet connection
    final isReady = await _connectivityService.checkFirebaseAndInternet();
    
    debugPrint('Splash Screen - Firebase initialized: ${_connectivityService.isFirebaseInitialized}');
    debugPrint('Splash Screen - Internet connected: ${_connectivityService.isConnected}');
    debugPrint('Splash Screen - Is ready: $isReady');
    
    if (mounted) {
      if (isReady) {
        // Check if user is already authenticated
        if (_authService.isSignedIn) {
          debugPrint('Splash Screen - User is signed in, fetching user data...');
          
          // Fetch user data from Firestore
          final userData = await _authService.fetchUserData(_authService.currentUser!.uid);
          
          if (userData != null) {
            debugPrint('Splash Screen - User data found, navigating to Home Screen');
            final accountType = userData['accountType'] ?? '';
            debugPrint('Splash Screen - Account type: $accountType');
            Get.off(() => const HomeScreen());
          } else {
            debugPrint('Splash Screen - User data not found, signing out and navigating to Login Screen');
            await _authService.signOut();
            Get.off(() => const LoginScreen());
          }
        } else {
          debugPrint('Splash Screen - User is not signed in, navigating to Login Screen');
          Get.off(() => const LoginScreen());
        }
      } else {
        debugPrint('Splash Screen - Navigating to Connection Error Screen');
        // Navigate to connection error screen
        Get.off(() => const ConnectionErrorScreen());
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(225, 34, 34, 1),
              Color.fromARGB(255, 255, 255, 255),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.1),
                
                // Animated Logo and Text
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _textScaleAnimation.value,
                      child: Image.asset(
                        'assets/splash_logo.png',
                        fit: BoxFit.fitWidth,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
