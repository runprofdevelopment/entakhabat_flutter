import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../splash_screen.dart';
import '../widgets/scan_method_bottom_sheet.dart';

class CollectorDashboard extends StatefulWidget {
  final String collectorId;

  const CollectorDashboard({
    super.key,
    required this.collectorId,
  });

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  @override
  void initState() {
    super.initState();
    
    // Set custom keys for debugging
    FirebaseCrashlytics.instance.setCustomKey('collector_id', widget.collectorId);
    FirebaseCrashlytics.instance.setCustomKey('screen_name', 'CollectorDashboard');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final FirebaseService firebaseService = Get.find<FirebaseService>();
    final double headerHeight = screenHeight * 0.32;

    // Add a simple test to see if the widget is building
    debugPrint('CollectorDashboard: Building widget for collector ID: ${widget.collectorId}');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<UserModel?>(
        stream: firebaseService.getCollectorPerformance(widget.collectorId),
        builder: (context, snapshot) {
          // Add debug logging
          debugPrint('CollectorDashboard: Connection state: ${snapshot.connectionState}');
          debugPrint('CollectorDashboard: Has error: ${snapshot.hasError}');
          debugPrint('CollectorDashboard: Has data: ${snapshot.hasData}');
          if (snapshot.hasError) {
            debugPrint('CollectorDashboard: Error: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Report to Crashlytics
            FirebaseCrashlytics.instance.recordError(
              snapshot.error!,
              StackTrace.current,
              reason: 'StreamBuilder error in CollectorDashboard for ID: ${widget.collectorId}',
            );
            
            return Center(
              child: Text(
                'حدث خطأ في تحميل البيانات',
                style: TextStyle(fontSize: screenWidth * 0.04),
              ),
            );
          }

          final UserModel? collector = snapshot.data;
          if (collector == null) {
            // Show error if no fallback data
            return Center(
              child: Text(
                'لم يتم العثور على بيانات المجمع',
                style: TextStyle(fontSize: screenWidth * 0.04),
              ),
            );
          }

          return _buildDashboardContent(collector);
        },
      ),
    );
  }

  Widget _buildDashboardContent(UserModel collector) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double headerHeight = screenHeight * 0.32;

    return Column(
      children: [
        // Gradient Header
        Container(
          height: headerHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.fromRGBO(225, 34, 34, 1),
                Color.fromRGBO(200, 30, 30, 1),
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: screenHeight * 0.03),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.11,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: screenWidth * 0.11,
                      color: const Color.fromRGBO(225, 34, 34, 1),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.05),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          collector.name,
                          style: TextStyle(
                            fontSize: screenWidth * 0.055,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.008),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.verified_user, color: Colors.white, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'مجمع نشط',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: screenWidth * 0.035,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final AuthService authService = Get.find<AuthService>();
                      await authService.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const SplashScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white, size: 30),
                    tooltip: 'تسجيل الخروج',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _modernPerformanceStats(context, collector),
                SizedBox(height: screenHeight * 0.025),
                _modernAreaPerformance(context, collector),
                SizedBox(height: screenHeight * 0.025),
                _modernAssignedAreas(context, collector),
                SizedBox(height: screenHeight * 0.025),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modernPerformanceStats(BuildContext context, UserModel collector) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.045),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
      decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
                    color: Colors.blue.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
          ),
        ],
      ),
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Icon(
                Icons.how_to_vote,
                color: Colors.blue,
                size: screenWidth * 0.13,
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
          Text(
              '${collector.totalVotesCollected ?? 0}',
            style: TextStyle(
                fontSize: screenWidth * 0.13,
              fontWeight: FontWeight.bold,
                color: Colors.blue[900],
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.01),
          Text(
              'إجمالي الأصوات',
            style: TextStyle(
                fontSize: screenWidth * 0.05,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
            SizedBox(height: screenHeight * 0.04),
            // Add National ID Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.bottomSheet(
                    ScanMethodBottomSheet(
                      collectorId: widget.collectorId,
                      collectorName: collector.name,
                      assignedArea: collector.assignedAreas.isNotEmpty ? collector.assignedAreas.first : '',
                    ),
                    isScrollControlled: true,
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: Padding(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.012),
                  child: Text(
                    'إضافة بطاقة شخصية',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, String title, String value, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: screenWidth * 0.06),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold, color: color),
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: screenWidth * 0.028, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _modernAreaPerformance(BuildContext context, UserModel collector) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final areaVotes = collector.areaVotesCount ?? {};
    final int maxVotes = areaVotes.isNotEmpty ? areaVotes.values.reduce((a, b) => a > b ? a : b) : 1;
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.045),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                Icon(Icons.map, color: Colors.green, size: 26),
                SizedBox(width: 8),
        Text(
          'أداء المناطق',
                  style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
              ),
            ],
          ),
            SizedBox(height: screenHeight * 0.018),
            areaVotes.isNotEmpty
              ? Column(
                  children: areaVotes.entries.map((entry) {
                    final isTop = entry.value == maxVotes && maxVotes > 0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                              style: TextStyle(fontSize: screenWidth * 0.035, color: Colors.grey[800]),
                            ),
                          ),
                          if (isTop)
                            Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                          SizedBox(width: 8),
                        Container(
                            width: screenWidth * 0.25,
                            child: LinearProgressIndicator(
                              value: maxVotes == 0 ? 0 : entry.value / maxVotes,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${entry.value}',
                            style: TextStyle(fontSize: screenWidth * 0.035, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ],
                    ),
                    );
                  }).toList(),
                )
              : Center(
                  child: Text(
                    'لا توجد بيانات أداء بعد',
                    style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey[500]),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _modernAssignedAreas(BuildContext context, UserModel collector) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.045),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.redAccent, size: 26),
                SizedBox(width: 8),
        Text(
                  'المناطق المخصصة',
                  style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.018),
            Wrap(
              spacing: screenWidth * 0.02,
              runSpacing: screenHeight * 0.01,
              children: collector.assignedAreas.map((area) => Chip(
                label: Text(area, style: TextStyle(fontSize: screenWidth * 0.032, color: Colors.white)),
                backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                avatar: const Icon(Icons.check_circle, color: Colors.white, size: 18),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernQuickActions(BuildContext context, UserModel collector) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.045),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.orange, size: 26),
                SizedBox(width: 8),
                Text(
                  'إجراءات سريعة',
                  style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.018),
            Row(
              children: [
                Expanded(
                  child: _modernActionButton(
                    context,
                    'إضافة بطاقة شخصية',
                    Icons.qr_code_scanner,
                    Colors.green,
                    () {
                      Get.bottomSheet(
                        ScanMethodBottomSheet(
                          collectorId: widget.collectorId,
                          collectorName: collector.name,
                          assignedArea: collector.assignedAreas.isNotEmpty ? collector.assignedAreas.first : '',
                        ),
                        isScrollControlled: true,
                      );
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _modernActionButton(
                    context,
                    'طباعة بياناتي',
                    Icons.print,
                    Colors.orange,
                    () => _printUserData(),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _modernActionButton(
                    context,
                    'طباعة جميع المستخدمين',
                    Icons.people,
                    Colors.purple,
                    () => _printAllUsers(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernActionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.025),
        ),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(icon, size: screenWidth * 0.08),
            SizedBox(height: screenHeight * 0.01),
            Text(
              title,
            style: TextStyle(fontSize: screenWidth * 0.032, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
      ),
    );
  }
  
  void _printUserData() async {
    final AuthService authService = Get.find<AuthService>();
    await authService.printCurrentUserData();
    Get.snackbar(
      'تم طباعة بيانات المستخدم',
      'تحقق من وحدة التحكم للحصول على التفاصيل',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
  
  void _printAllUsers() async {
    final AuthService authService = Get.find<AuthService>();
    await authService.printAllUsers();
    Get.snackbar(
      'تم طباعة جميع المستخدمين',
      'تحقق من وحدة التحكم للحصول على التفاصيل',
      backgroundColor: Colors.purple,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
} 