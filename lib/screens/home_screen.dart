import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/auth_service.dart';
import '../splash_screen.dart';
import 'owner_dashboard.dart';
import 'collector_dashboard.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = Get.find<AuthService>();
    
    return Obx(() {
      final userData = authService.userData;
      final currentUser = authService.currentUser;
      
      debugPrint('HomeScreen: Current user: ${currentUser?.uid}');
      debugPrint('HomeScreen: User data: $userData');
      
      // Check if user is authenticated
      if (currentUser == null || userData == null) {
        debugPrint('HomeScreen: No authenticated user, redirecting to login');
        // Redirect to login screen if not authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAll(() => const LoginScreen());
        });
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Try different possible field names for account type
      final accountType = userData['accountType'] ?? 
                         userData['account_type'] ?? 
                         userData['type'] ?? 
                         userData['userType'] ?? 
                         userData['user_type'] ?? 
                         '';
      
      debugPrint('HomeScreen: User data: $userData');
      debugPrint('HomeScreen: Account type: "$accountType"');
      
      // Route to appropriate dashboard based on account type (case insensitive)
      final normalizedAccountType = accountType.toLowerCase().trim();
      
      try {
        if (normalizedAccountType == 'owner' || normalizedAccountType == 'admin') {
          debugPrint('HomeScreen: Routing to Owner Dashboard for $normalizedAccountType');
          return const OwnerDashboard();
        } else if (normalizedAccountType == 'collector') {
          debugPrint('HomeScreen: Routing to Collector Dashboard');
          final currentUserId = authService.user?.uid ?? '';
          debugPrint('HomeScreen: Collector ID: $currentUserId');
          return CollectorDashboard(collectorId: currentUserId);
        } else {
          debugPrint('HomeScreen: Routing to Default Dashboard (unknown account type: "$accountType")');
          // Default dashboard for unknown account types
          return _buildDefaultDashboard(context, authService);
        }
      } catch (e) {
        debugPrint('HomeScreen: Error in routing: $e');
        
        // Report to Crashlytics
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Error in HomeScreen routing',
          information: [
            'User ID: ${currentUser?.uid}',
            'Account Type: $accountType',
            'User Data: $userData',
          ],
        );
        
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('حدث خطأ في تحميل الشاشة'),
                SizedBox(height: 8),
                Text('$e', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Get.offAll(() => const LoginScreen());
                  },
                  child: Text('العودة لتسجيل الدخول'),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  Widget _buildDefaultDashboard(BuildContext context, AuthService authService) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
        foregroundColor: Colors.white,
        title: Text(
          'entkhabat',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await authService.signOut();
              Get.offAll(() => const SplashScreen());
            },
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.05),
              
              // Welcome Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.05),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromRGBO(225, 34, 34, 1),
                      Color.fromRGBO(200, 30, 30, 1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(77),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person,
                      size: screenWidth * 0.15,
                      color: Colors.white,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Obx(() {
                      final userData = authService.userData;
                      final userName = userData?['name'] ?? 'المستخدم';
                      final userRole = userData?['role'] ?? 'مستخدم';
                      final accountType = userData?['accountType'] ?? 'غير محدد';
                      
                      return Column(
                        children: [
                          Text(
                            'مرحباً بك في entkhabat',
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            userRole,
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.005,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(204),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'نوع الحساب: $accountType',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'منصة الانتخابات المصرية',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * 0.05),
              
              // Features Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: screenWidth * 0.03,
                  mainAxisSpacing: screenHeight * 0.02,
                  children: [
                    _buildFeatureCard(
                      context,
                      'الانتخابات',
                      Icons.how_to_vote,
                      Colors.blue,
                      () => _showFeatureInfo('الانتخابات'),
                    ),
                    _buildFeatureCard(
                      context,
                      'المرشحين',
                      Icons.people,
                      Colors.green,
                      () => _showFeatureInfo('المرشحين'),
                    ),
                    _buildFeatureCard(
                      context,
                      'النتائج',
                      Icons.analytics,
                      Colors.orange,
                      () => _showFeatureInfo('النتائج'),
                    ),
                    _buildFeatureCard(
                      context,
                      'الإحصائيات',
                      Icons.bar_chart,
                      Colors.purple,
                      () => _showFeatureInfo('الإحصائيات'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
                                          color: color.withAlpha(51),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                                            color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: screenWidth * 0.08,
                color: color,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureInfo(String feature) {
    Get.snackbar(
      feature,
      'هذه الميزة ستكون متاحة قريباً',
              backgroundColor: Colors.blue.withAlpha(26),
      colorText: Colors.blue,
      duration: const Duration(seconds: 2),
    );
  }
} 