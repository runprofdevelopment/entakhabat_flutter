import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/connectivity_service.dart';
import 'login_screen.dart';

class ConnectionErrorScreen extends StatefulWidget {
  const ConnectionErrorScreen({super.key});

  @override
  State<ConnectionErrorScreen> createState() => _ConnectionErrorScreenState();
}

class _ConnectionErrorScreenState extends State<ConnectionErrorScreen> {
  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    final connectivityService = Get.find<ConnectivityService>();
    
    // Listen to both connectivity and Firebase changes
    connectivityService.connectivityStream.listen((isConnected) {
      _checkAndNavigate(connectivityService);
    });
    
    connectivityService.firebaseStream.listen((isFirebaseReady) {
      _checkAndNavigate(connectivityService);
    });
    
    // Initial check
    _checkAndNavigate(connectivityService);
  }

  void _checkAndNavigate(ConnectivityService connectivityService) {
    if (connectivityService.isConnected && connectivityService.isFirebaseInitialized) {
      // Navigate to login screen when both internet and Firebase are ready
      Get.off(() => const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error Icon
                  Container(
                    width: screenWidth * 0.3,
                    height: screenWidth * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha(77),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.wifi_off,
                      size: screenWidth * 0.15,
                      color: const Color.fromRGBO(225, 34, 34, 1),
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.05),
                  
                  // Error Title
                  Text(
                    'لا يوجد اتصال بالإنترنت',
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  // Error Description
                  Text(
                    'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: const Color.fromARGB(179, 0, 0, 0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: screenHeight * 0.05),
                  
                  // Retry Button
                  Obx(() {
                    final connectivityService = Get.find<ConnectivityService>();
                    return SizedBox(
                      width: double.infinity,
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: connectivityService.isChecking 
                          ? null 
                          : () => connectivityService.retryConnection(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color.fromRGBO(225, 34, 34, 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        child: connectivityService.isChecking
                          ? SizedBox(
                              width: screenWidth * 0.05,
                              height: screenWidth * 0.05,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color.fromRGBO(225, 34, 34, 1),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: screenWidth * 0.05,
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Text(
                                  'إعادة المحاولة',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.045,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                      ),
                    );
                  }),
                  
                  SizedBox(height: screenHeight * 0.03),
                  
                  // Status Text
                  Obx(() {
                    final connectivityService = Get.find<ConnectivityService>();
                    return Column(
                      children: [
                        Text(
                          'حالة الاتصال:',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: screenWidth * 0.02,
                              height: screenWidth * 0.02,
                              decoration: BoxDecoration(
                                color: connectivityService.isConnected 
                                  ? Colors.green 
                                  : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              connectivityService.isConnected 
                                ? 'متصل بالإنترنت' 
                                : 'غير متصل بالإنترنت',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: screenWidth * 0.02,
                              height: screenWidth * 0.02,
                              decoration: BoxDecoration(
                                color: connectivityService.isFirebaseInitialized 
                                  ? Colors.green 
                                  : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              connectivityService.isFirebaseInitialized 
                                ? 'Firebase متصل' 
                                : 'Firebase غير متصل',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 