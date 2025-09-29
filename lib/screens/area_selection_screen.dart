import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'barcode_scanner_screen.dart';
import 'live_barcode_scanner_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AreaSelectionScreen extends StatefulWidget {
  final String collectorId;
  final String collectorName;

  const AreaSelectionScreen({
    super.key,
    required this.collectorId,
    required this.collectorName,
  });

  @override
  State<AreaSelectionScreen> createState() => _AreaSelectionScreenState();
}

class _AreaSelectionScreenState extends State<AreaSelectionScreen> {
  String? _selectedArea;
  bool _isLoading = true;
  UserModel? _collector;
  List<String> _allAreas = [];
  String _areaSearch = '';

  @override
  void initState() {
    super.initState();
    _loadCollectorData();
    _loadAllAreasIfOwner();
  }

  Future<void> _loadCollectorData() async {
    try {
      final FirebaseService firebaseService = Get.find<FirebaseService>();
      await for (final collector in firebaseService.getCollectorPerformance(widget.collectorId)) {
        if (collector != null) {
          setState(() {
            _collector = collector;
            _isLoading = false;
          });
          break;
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'خطأ',
        'فشل في تحميل بيانات المجمع: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadAllAreasIfOwner() async {
    final AuthService authService = Get.find<AuthService>();
    final userData = authService.userData;
    final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
    if (accountType == 'owner') {
      // Fetch all unique areas from all users
      final FirebaseService firebaseService = Get.find<FirebaseService>();
      final allCollectors = await firebaseService.getAllCollectors().first;
      final Set<String> allAreasSet = {};
      for (final c in allCollectors) {
        allAreasSet.addAll(c.assignedAreas);
      }
      
      // Also load custom areas from Firestore
      try {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        final customAreasSnapshot = await firestore.collection('customAreas').get();
        final customAreas = customAreasSnapshot.docs
            .map((doc) => doc.data()['name'] as String)
            .toList();
        allAreasSet.addAll(customAreas);
      } catch (e) {
        debugPrint('Error loading custom areas: $e');
      }
      
      setState(() {
        _allAreas = allAreasSet.toList()..sort();
      });
    }
  }

  Stream<List<String>> _getCustomAreasStream() {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    return firestore.collection('customAreas').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
    });
  }

  void _selectArea(String area) {
    setState(() {
      _selectedArea = area;
    });
  }

  void _proceedToNext() {
    if (_selectedArea == null) {
      Get.snackbar(
        'خطأ',
        'يرجى اختيار منطقة أولاً',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    Get.to(() => BarcodeScannerScreen(
      selectedArea: _selectedArea!,
      collectorId: widget.collectorId,
      collectorName: widget.collectorName,
    ));
  }

  void _proceedToLiveScanning() {
    if (_selectedArea == null) {
      Get.snackbar(
        'خطأ',
        'يرجى اختيار منطقة أولاً',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    Get.to(() => LiveBarcodeScannerScreen(
      selectedArea: _selectedArea!,
      collectorId: widget.collectorId,
      collectorName: widget.collectorName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final AuthService authService = Get.find<AuthService>();
    final userData = authService.userData;
    final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
    final isOwner = accountType == 'owner';

    List<String> areaList = isOwner
      ? (_allAreas.where((a) => a.contains(_areaSearch)).toList())
      : (_collector?.assignedAreas ?? []);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _collector == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: screenWidth * 0.15,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        'لم يتم العثور على بيانات المجمع',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Gradient Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: screenHeight * 0.06, bottom: screenHeight * 0.03),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.fromRGBO(225, 34, 34, 1),
                            Color.fromRGBO(200, 30, 30, 1),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: screenWidth * 0.09,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: screenWidth * 0.09,
                              color: const Color.fromRGBO(225, 34, 34, 1),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.012),
                          Text(
                            _collector!.name,
                            style: TextStyle(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user, color: Colors.white, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  isOwner ? 'مالك' : 'مجمع',
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
                    ),
                    // Area search (owner only)
                    if (isOwner) ...[
                      Padding(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'ابحث عن منطقة...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(() => _areaSearch = val),
                        ),
                      ),
                    ],
                    // Area list
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: screenHeight * 0.01),
                            Text(
                              'اختر المنطقة:',
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            // Area Options as a vertical list
                            if (isOwner)
                              StreamBuilder<List<String>>(
                                stream: _getCustomAreasStream(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    final customAreas = snapshot.data!;
                                    final allAreas = {...areaList, ...customAreas}.toList()..sort();
                                    final filteredAreas = allAreas.where((a) => a.contains(_areaSearch)).toList();
                                    
                                    return Column(
                                      children: filteredAreas.map((area) => Padding(
                                        padding: EdgeInsets.only(bottom: screenHeight * 0.018),
                                        child: _buildAreaCard(area, area),
                                      )).toList(),
                                    );
                                  }
                                  return Column(
                                    children: areaList.map((area) => Padding(
                                      padding: EdgeInsets.only(bottom: screenHeight * 0.018),
                                      child: _buildAreaCard(area, area),
                                    )).toList(),
                                  );
                                },
                              )
                            else
                              Column(
                                children: areaList.map((area) => Padding(
                                  padding: EdgeInsets.only(bottom: screenHeight * 0.018),
                                  child: _buildAreaCard(area, area),
                                )).toList(),
                              ),
                            SizedBox(height: screenHeight * 0.04),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _collector == null
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.04,
                0,
                screenWidth * 0.04,
                screenHeight * 0.025,
              ),
              child: SizedBox(
                width: double.infinity,
                height: screenHeight * 0.065,
                child:
                 Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedArea != null ? _proceedToNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                        ),
                        child: Text(
                          'المسح اليدوي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selectedArea != null ? _proceedToLiveScanning : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color.fromRGBO(225, 34, 34, 1),
                          side: BorderSide(color: const Color.fromRGBO(225, 34, 34, 1), width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                        ),
                        child: Text(
                          'المسح الحي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAreaCard(String title, String areaId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSelected = _selectedArea == areaId;

    return GestureDetector(
      onTap: () => _selectArea(areaId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? const Color.fromRGBO(225, 34, 34, 1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: isSelected
              ? Border.all(color: const Color.fromRGBO(225, 34, 34, 1), width: 2)
              : null,
        ),
        constraints: BoxConstraints(
          minHeight: screenHeight * 0.12,
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.025, horizontal: screenWidth * 0.04),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : const Color.fromRGBO(225, 34, 34, 0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(screenWidth * 0.025),
                    child: Icon(
                      Icons.location_on,
                      size: screenWidth * 0.07,
                      color: isSelected ? const Color.fromRGBO(225, 34, 34, 1) : Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.check_circle, color: Colors.white, size: screenWidth * 0.07),
              ),
          ],
        ),
      ),
    );
  }
} 