import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

class AllCollectorsScreen extends StatefulWidget {
  const AllCollectorsScreen({Key? key}) : super(key: key);

  @override
  State<AllCollectorsScreen> createState() => _AllCollectorsScreenState();
}

class _AllCollectorsScreenState extends State<AllCollectorsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<UserModel> _collectors = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String _statusFilter = 'الكل';
  String _areaFilter = '';
  List<String> _allAreas = [];

  @override
  void initState() {
    super.initState();
    _fetchCollectors();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCollectors() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final FirebaseService firebaseService = Get.find<FirebaseService>();
    final result = await firebaseService.paginateCollectors(
      lastDoc: _lastDoc,
      statusFilter: _statusFilter,
      areaFilter: _areaFilter,
      limit: 20,
    );
    setState(() {
      _collectors.addAll(result['collectors'] as List<UserModel>);
      _lastDoc = result['lastDoc'] as DocumentSnapshot?;
      _hasMore = result['hasMore'] as bool;
      _isLoading = false;
      if (_allAreas.isEmpty && result['allAreas'] != null) {
        _allAreas = result['allAreas'] as List<String>;
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchCollectors();
    }
  }

  void _onStatusChanged(String status) {
    setState(() {
      _statusFilter = status;
      _collectors.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    _fetchCollectors();
  }

  void _onAreaChanged(String area) {
    setState(() {
      _areaFilter = area;
      _collectors.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    _fetchCollectors();
  }

  void _showModifyAreaDialog(String collectorId, String collectorName) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Get current collector data
    final collector = _collectors.firstWhere((c) => c.id == collectorId);
    final currentArea = collector.assignedAreas.isNotEmpty ? collector.assignedAreas.first : '';
    
    // Get all available areas
    final areasSnapshot = await FirebaseFirestore.instance.collection('customAreas').get();
    final availableAreas = areasSnapshot.docs.map((doc) => doc.data()['name'] as String).toList();
    
    // Initialize selected area with current area
    String selectedArea = currentArea;
    
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        decoration: BoxDecoration(
                          color: Colors.purple[600],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: screenWidth * 0.08,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        'تعديل منطقة المجمع',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        collectorName,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Text(
                        'المنطقة الحالية: $currentArea',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        'اختر المنطقة الجديدة:',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Container(
                        height: screenHeight * 0.2,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ListView.builder(
                          itemCount: availableAreas.length,
                          itemBuilder: (context, index) {
                            final area = availableAreas[index];
                            final isSelected = selectedArea == area;
                            return ListTile(
                              title: Text(
                                area,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: isSelected ? Colors.purple[600] : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              leading: Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.purple[600] : Colors.grey[400],
                                size: screenWidth * 0.05,
                              ),
                              tileColor: isSelected ? Colors.purple[50] : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              onTap: () {
                                setDialogState(() {
                                  selectedArea = area;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.back(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[400]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                              ),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedArea.isNotEmpty ? () async {
                                if (selectedArea != currentArea) {
                                  // Update collector's assigned area
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(collectorId)
                                      .update({
                                    'assignedAreas': [selectedArea],
                                  });
                                  
                                  Get.back();
                                  Get.snackbar(
                                    'تم تحديث المنطقة',
                                    'تم تحديث منطقة المجمع "$collectorName" إلى "$selectedArea" بنجاح.',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 3),
                                  );
                                } else {
                                  Get.back();
                                  Get.snackbar(
                                    'لا توجد تغييرات',
                                    'لم يتم إجراء أي تغييرات على منطقة المجمع.',
                                    backgroundColor: Colors.orange,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 2),
                                  );
                                }
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                                elevation: 2,
                              ),
                              child: Text(
                                'تحديث',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExportDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصدير البيانات'),
        content: const Text('هل تريد تصدير بيانات المجمعين إلى ملف CSV؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تصدير CSV'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _exportCollectors();
    }
  }

  Future<void> _exportCollectors() async {
    // Fetch all filtered collectors (not just loaded ones)
    final FirebaseService firebaseService = Get.find<FirebaseService>();
    final result = await firebaseService.paginateCollectors(
      statusFilter: _statusFilter,
      areaFilter: _areaFilter,
      limit: 10000, // Large enough to get all
    );
    final allCollectors = result['collectors'] as List<UserModel>;
    if (allCollectors.isEmpty) {
      Get.snackbar('لا يوجد بيانات', 'لا يوجد مجمعين للتصدير', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    
    try {
      // Prepare CSV data
      final List<List<dynamic>> rows = [
        ['#', 'الاسم', 'البريد الإلكتروني', 'الهاتف', 'الحالة', 'الأصوات', 'المناطق'],
      ];
      for (int i = 0; i < allCollectors.length; i++) {
        final c = allCollectors[i];
        rows.add([
          i + 1,
          c.name,
          c.email,
          c.phone,
          c.isActive ? 'مفعل' : 'معطل',
          c.totalVotesCollected ?? 0,
          c.assignedAreas.join(' | '),
        ]);
      }
      final String csvData = const ListToCsvConverter().convert(rows);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'collector_exportation_$timestamp.csv';
      
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          // For mobile platforms, use share_plus to let user choose where to save
          final bytes = utf8.encode(csvData);
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes);
          
          await Share.shareXFiles(
            [XFile(tempFile.path)],
            text: 'تصدير بيانات المجمعين',
            subject: 'collector_exportation_$timestamp.csv',
          );
          
          Get.snackbar(
            'تم التصدير', 
            'تم إنشاء ملف CSV وفتح خيارات المشاركة', 
            backgroundColor: Colors.green, 
            colorText: Colors.white
          );
        } catch (e) {
          Get.snackbar('خطأ', 'فشل في تصدير CSV: $e', backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        // For desktop platforms
        try {
          final directory = await getDownloadsDirectory();
          final filePath = '${directory!.path}/$fileName';
          final file = File(filePath);
          await file.writeAsString(csvData);
          Get.snackbar(
            'تم التصدير', 
            'تم حفظ الملف في: $filePath', 
            backgroundColor: Colors.green, 
            colorText: Colors.white, 
            duration: const Duration(seconds: 5)
          );
        } catch (e) {
          Get.snackbar('خطأ', 'فشل في تصدير CSV: $e', backgroundColor: Colors.red, colorText: Colors.white);
        }
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تصدير CSV: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      // Modern AppBar
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(90),
        child: Container(
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
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(225, 34, 34, 0.12),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Icon(Icons.people, color: Colors.white, size: screenWidth * 0.09),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'جميع المجمعين',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Export button
                IconButton(
                  icon: const Icon(Icons.file_download, color: Colors.white, size: 28),
                  tooltip: 'تصدير البيانات',
                  onPressed: _showExportDialog,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Modern Filter bar
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, color: Colors.red[400]),
                    const SizedBox(width: 10),
                    // Status Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          borderRadius: BorderRadius.circular(14),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'الكل',
                              child: Row(
                                children: [
                                  Icon(Icons.all_inclusive, size: 16, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('الكل'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'مفعل',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('مفعل'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'معطل',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, size: 16, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('معطل'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) => _onStatusChanged(val ?? 'الكل'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Area Filter Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _areaFilter.isEmpty ? null : _areaFilter,
                            borderRadius: BorderRadius.circular(14),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            hint: Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('اختر المنطقة'),
                              ],
                            ),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Row(
                                  children: [
                                    Icon(Icons.all_inclusive, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    const Text('جميع المناطق'),
                                  ],
                                ),
                              ),
                              ..._allAreas.map((area) => DropdownMenuItem(
                                value: area,
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(area),
                                  ],
                                ),
                              )),
                            ],
                            onChanged: (val) => _onAreaChanged(val ?? ''),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Collectors list
          Expanded(
            child: _collectors.isEmpty && !_isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا يوجد مجمعين', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _collectors.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _collectors.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final collector = _collectors[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: collector.isActive ? Colors.green[100] : Colors.orange[100],
                                child: Icon(
                                  Icons.person,
                                  color: collector.isActive ? Colors.green[700] : Colors.orange[700],
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      collector.name ?? 'غير محدد',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      collector.email ?? 'غير محدد',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      collector.phone ?? 'غير محدد',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: collector.isActive ? Colors.green[100] : Colors.orange[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            collector.isActive ? 'مفعل' : 'معطل',
                                            style: TextStyle(
                                              color: collector.isActive ? Colors.green[700] : Colors.orange[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.how_to_vote, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${collector.totalVotesCollected ?? 0}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (collector.assignedAreas.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'المناطق: ${collector.assignedAreas.join('، ')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Actions
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                                onSelected: (value) async {
                                  final firebaseService = Get.find<FirebaseService>();
                                  if (value == 'enable') {
                                    await firebaseService.setCollectorActive(collector.id, true);
                                  } else if (value == 'disable') {
                                    await firebaseService.setCollectorActive(collector.id, false);
                                  } else if (value == 'modify_area') {
                                    _showModifyAreaDialog(collector.id, collector.name ?? '');
                                  } else if (value == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('تأكيد الحذف'),
                                        content: const Text('هل أنت متأكد أنك تريد حذف هذا المجمع؟ لن يتم حذف بيانات الأصوات المجمعة.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('إلغاء'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('حذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await firebaseService.deleteCollector(collector.id);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!collector.isActive)
                                    const PopupMenuItem(value: 'enable', child: Text('تفعيل')),
                                  if (collector.isActive)
                                    const PopupMenuItem(value: 'disable', child: Text('تعطيل')),
                                  const PopupMenuItem(value: 'modify_area', child: Text('تعديل المنطقة')),
                                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 