import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../splash_screen.dart';
import '../widgets/add_user_bottom_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import 'area_selection_screen.dart';
import 'all_collectors_screen.dart';

// Move _getRankColor to the top-level
Color _getRankColor(int rank) {
  switch (rank) {
    case 1:
      return Colors.amber;
    case 2:
      return Colors.grey[400]!;
    case 3:
      return Colors.orange[300]!;
    default:
      return Colors.blue;
  }
}

class OwnerDashboardTable extends StatefulWidget {
  final List<UserModel> topCollectors;
  final AuthService authService;
  final FirebaseService firebaseService;
  final String statusFilter;
  final Function(String) onStatusChanged;
  const OwnerDashboardTable({
    Key? key,
    required this.topCollectors,
    required this.authService,
    required this.firebaseService,
    required this.statusFilter,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  State<OwnerDashboardTable> createState() => _OwnerDashboardTableState();
}

class _OwnerDashboardTableState extends State<OwnerDashboardTable> {
  List<String> selectedAreas = [];

  List<String> get allAreas {
    final Set<String> areas = {};
    for (final c in widget.topCollectors) {
      areas.addAll(c.assignedAreas);
    }
    return areas.toList()..sort();
  }

  List<UserModel> get _filteredCollectors {
    return widget.topCollectors.where((collector) {
      final matchesStatus = widget.statusFilter == 'الكل' ||
        (widget.statusFilter == 'مفعل' && collector.isActive) ||
        (widget.statusFilter == 'معطل' && !collector.isActive);
      final matchesArea = selectedAreas.isEmpty ||
        collector.assignedAreas.any((area) => selectedAreas.contains(area));
      return matchesStatus && matchesArea;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final userData = widget.authService.userData;
    final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
    final isOwner = accountType == 'owner';
    final adminAreas = List<String>.from(userData?['assignedAreas'] ?? []);
    final collectors = _filteredCollectors;
    final showCount = collectors.length > 5 ? 5 : collectors.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with 'View More' button
        Row(
          children: [
            Expanded(
              child: Text(
                'أفضل المجمعين',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            if (collectors.length > 5)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllCollectorsScreen(),
                    ),
                  );
                },
                child: const Text('عرض المزيد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        // Filter chips and area dropdown
        Row(
          children: [
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('الكل'),
                  selected: widget.statusFilter == 'الكل',
                  onSelected: (_) => widget.onStatusChanged('الكل'),
                  selectedColor: Colors.blue.shade100,
                ),
                FilterChip(
                  label: const Text('مفعل'),
                  selected: widget.statusFilter == 'مفعل',
                  onSelected: (_) => widget.onStatusChanged('مفعل'),
                  selectedColor: Colors.green.shade100,
                ),
                FilterChip(
                  label: const Text('معطل'),
                  selected: widget.statusFilter == 'معطل',
                  onSelected: (_) => widget.onStatusChanged('معطل'),
                  selectedColor: Colors.orange.shade100,
                ),
              ],
            ),
            SizedBox(width: screenWidth * 0.02),
            // Area dropdown button
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final allAreasList = allAreas;
                  final selected = List<String>.from(selectedAreas);
                  String search = '';
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (ctx) {
                      return StatefulBuilder(
                        builder: (ctx, setModalState) {
                          final filteredAreas = search.isEmpty
                            ? allAreasList
                            : allAreasList.where((a) => a.contains(search)).toList();
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(ctx).viewInsets.bottom,
                              left: 0, right: 0, top: 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.red[400]),
                                      const SizedBox(width: 8),
                                      Text(
                                        'تصفية حسب المنطقة',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                ),
                                // Search bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'ابحث عن منطقة...',
                                      prefixIcon: const Icon(Icons.search),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (val) => setModalState(() => search = val),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Area list
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Container(
                                    height: 300,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: filteredAreas.isEmpty
                                      ? Center(
                                          child: Text('لا توجد مناطق مطابقة', style: TextStyle(color: Colors.grey[500])),
                                        )
                                      : ListView(
                                          children: filteredAreas.map((area) => CheckboxListTile(
                                            value: selected.contains(area),
                                            title: Text(area, style: TextStyle(fontWeight: selected.contains(area) ? FontWeight.bold : FontWeight.normal)),
                                            activeColor: Colors.red[400],
                                            onChanged: (checked) {
                                              setModalState(() {
                                                if (checked == true) {
                                                  selected.add(area);
                                                } else {
                                                  selected.remove(area);
                                                }
                                              });
                                            },
                                          )).toList(),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // Apply and Reset buttons
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700],
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            setState(() {
                                              selectedAreas = selected;
                                            });
                                          },
                                          child: const Text('تطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red[700],
                                            side: BorderSide(color: Colors.red[700]!),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          onPressed: () {
                                            setModalState(() {
                                              selected.clear();
                                              search = '';
                                            });
                                          },
                                          child: const Text('إعادة تعيين', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedAreas.isEmpty
                            ? 'تصفية حسب المنطقة'
                            : selectedAreas.length == 1
                              ? selectedAreas.first
                              : '${selectedAreas.length} مناطق مختارة',
                          style: TextStyle(
                            color: selectedAreas.isEmpty ? Colors.grey[600] : Colors.red[800],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        // Table header
        Container(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.012),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(flex: 1, child: Center(child: Text('م', style: TextStyle(fontSize: screenWidth * 0.038, fontWeight: FontWeight.w700, color: Colors.grey[700])))),
              Expanded(flex: 3, child: Text('المجمع', style: TextStyle(fontSize: screenWidth * 0.038, fontWeight: FontWeight.w700, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Text('المنطقة', style: TextStyle(fontSize: screenWidth * 0.038, fontWeight: FontWeight.w700, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Center(child: Text('الأصوات', style: TextStyle(fontSize: screenWidth * 0.038, fontWeight: FontWeight.w700, color: Colors.grey[700])))),
              Expanded(flex: 2, child: Center(child: Text('الحالة', style: TextStyle(fontSize: screenWidth * 0.038, fontWeight: FontWeight.w700, color: Colors.grey[700])))),
              Expanded(flex: 2, child: Center(child: Text('إجراءات', style: TextStyle(fontSize: screenWidth * 0.038, fontWeight: FontWeight.w700, color: Colors.grey[700])))),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        // Table rows or empty state
        if (collectors.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.08),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: screenWidth * 0.18, color: Colors.grey[300]),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'لا توجد نتائج مطابقة',
                    style: TextStyle(fontSize: screenWidth * 0.045, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: showCount,
            itemBuilder: (context, i) {
              final collector = collectors[i];
              return Card(
                margin: EdgeInsets.symmetric(vertical: screenHeight * 0.007, horizontal: 0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.012),
                  child: _buildTableRow(
                    context,
                    collector.name,
                    collector.assignedAreas.isNotEmpty ? collector.assignedAreas.first : '-',
                    (collector.totalVotesCollected ?? 0).toString(),
                    i + 1,
                    collectorId: collector.id,
                    isActive: collector.isActive,
                    canManage: true, // Always show actions for debug
                    onEnable: () => widget.firebaseService.setCollectorActive(collector.id, true),
                    onDisable: () => widget.firebaseService.setCollectorActive(collector.id, false),
                    onDelete: () => widget.firebaseService.deleteCollector(collector.id),
                    avatar: _buildAvatar(collector.name),
                  ),
                ),
              );
            },
          ),
        if (collectors.length > 10)
          Padding(
            padding: EdgeInsets.only(top: screenHeight * 0.01),
            child: Text(
              'عرض أول 10 فقط من ${collectors.length} مجمعين. استخدم البحث أو الفلتر لإيجاد المزيد.',
              style: TextStyle(fontSize: screenWidth * 0.032, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : '';
    return Tooltip(
      message: name,
      child: CircleAvatar(
        backgroundColor: Colors.blueGrey.shade100,
        foregroundColor: Colors.blueGrey.shade700,
        radius: 18,
        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showModifyAreaDialog(String collectorId, String collectorName) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Get current collector data
    final collector = widget.topCollectors.firstWhere((c) => c.id == collectorId);
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

  Widget _buildTableRow(BuildContext context, String name, String zone, String votes, int rank, {
    required String collectorId,
    required bool isActive,
    required bool canManage,
    required void Function() onEnable,
    required void Function() onDisable,
    required void Function() onDelete,
    Widget? avatar,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      children: [
        // Number column
        Expanded(
          flex: 1,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Collector name
        Expanded(
          flex: 3,
          child: Text(
            name,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Area
        Expanded(
          flex: 2,
          child: Tooltip(
            message: zone,
            child: Text(
              zone,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Votes
        Expanded(
          flex: 2,
          child: Center(
            child: Tooltip(
              message: 'إجمالي الأصوات',
              child: Text(
                votes,
                style: TextStyle(
                  fontSize: screenWidth * 0.032,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        // Status
        Expanded(
          flex: 2,
          child: Center(
            child: Tooltip(
              message: isActive ? 'مفعل' : 'معطل',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                constraints: const BoxConstraints(maxWidth: 80),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isActive ? 'مفعل' : 'معطل',
                        style: TextStyle(
                          color: isActive ? Colors.green[800] : Colors.orange[800],
                          fontSize: screenWidth * 0.025,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Actions
        Expanded(
          flex: 2,
          child: canManage
              ? Center(
                  child: Tooltip(
                    message: 'إجراءات الحساب',
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                      onSelected: (value) async {
                        if (value == 'enable') {
                          onEnable();
                        } else if (value == 'disable') {
                          onDisable();
                        } else if (value == 'modify_area') {
                          _showModifyAreaDialog(collectorId, name);
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
                            onDelete();
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isActive)
                          const PopupMenuItem(value: 'enable', child: Text('تفعيل')),
                        if (isActive)
                          const PopupMenuItem(value: 'disable', child: Text('تعطيل')),
                        const PopupMenuItem(value: 'modify_area', child: Text('تعديل المنطقة')),
                        const PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  final Map<String, int> dailyVotes;

  LineChartPainter(this.dailyVotes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Sort dates for proper line drawing
    final sortedDates = dailyVotes.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return;
    }

    // Start from the earliest date
    path.moveTo(0, size.height * 0.8);

    for (int i = 0; i < sortedDates.length; i++) {
      final dateStr = sortedDates[i];
      final date = DateTime.parse(dateStr);
      final x = (i / (sortedDates.length - 1)) * size.width;
      final y = size.height * (1 - (dailyVotes[dateStr]! / 1000.0)); // Scale y-axis

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  String statusFilter = 'الكل';
  List<String> selectedAreas = [];
  String areaSearch = '';

  List<String> get allAreas {
    // Collect all unique areas from all collectors
    final collectors = _lastCollectors ?? [];
    final Set<String> areas = {};
    for (final c in collectors) {
      areas.addAll(c.assignedAreas);
    }
    return areas.toList()..sort();
  }

  List<UserModel>? _lastCollectors;

  @override
  Widget build(BuildContext context) {
    final AuthService authService = Get.find<AuthService>();
    final FirebaseService firebaseService = Get.find<FirebaseService>();
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color.fromRGBO(225, 34, 34, 1),
              Color.fromRGBO(180, 30, 30, 1),
            ],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withAlpha(77),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            debugPrint('Logout FAB pressed');
            try {
              await authService.signOut();
              debugPrint('Sign out successful');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const SplashScreen()),
                (route) => false,
              );
            } catch (e) {
              debugPrint('Error during logout: $e');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const SplashScreen()),
                (route) => false,
              );
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.logout,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<UserModel>>(
          stream: firebaseService.getAllCollectors(),
          builder: (context, collectorsSnapshot) {
            _lastCollectors = collectorsSnapshot.data;
            return StreamBuilder<QuerySnapshot>(
              stream: firebaseService.getDocuments('nationalIDs'),
              builder: (context, nationalIDsSnapshot) {
                if (collectorsSnapshot.connectionState == ConnectionState.waiting ||
                    nationalIDsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (collectorsSnapshot.hasError || nationalIDsSnapshot.hasError) {
                  return Center(child: Text('حدث خطأ في تحميل البيانات'));
                }
                final collectors = collectorsSnapshot.data ?? [];
                final nationalIDs = nationalIDsSnapshot.data?.docs ?? [];
                final totalVotes = nationalIDs.length;
                final activeCollectors = collectors.length;
                final Map<String, int> areaVotes = {};
                for (final collector in collectors) {
                  collector.areaVotesCount?.forEach((area, count) {
                    areaVotes[area] = (areaVotes[area] ?? 0) + count;
                  });
                }
                String participationRate = 'N/A';
                final topCollectors = [...collectors];
                topCollectors.sort((a, b) => (b.totalVotesCollected ?? 0).compareTo(a.totalVotesCollected ?? 0));
                final Map<String, int> dailyVotes = {};
                for (final doc in nationalIDs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'];
                  if (timestamp is Timestamp) {
                    final date = timestamp.toDate();
                    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    dailyVotes[dateStr] = (dailyVotes[dateStr] ?? 0) + 1;
                  }
                }
                final activeAreas = areaVotes.keys.length;
                return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.03),
              _buildHeaderSection(context, authService),
              SizedBox(height: screenHeight * 0.025),
              _buildWelcomeSection(context, authService),
                      SizedBox(height: screenHeight * 0.025),
                      _buildStatisticsCards(context, totalVotes, activeCollectors, participationRate, activeAreas),
        SizedBox(height: screenHeight * 0.025),
                      _buildChartsSection(context, areaVotes, dailyVotes, participationRate, totalVotes, activeAreas),
        SizedBox(height: screenHeight * 0.025),
                      OwnerDashboardTable(
                        topCollectors: topCollectors,
                        authService: authService,
                        firebaseService: firebaseService,
                        statusFilter: statusFilter,
                        onStatusChanged: (val) => setState(() => statusFilter = val),
                      ),
        SizedBox(height: screenHeight * 0.025),
        _buildQuickActions(context),
        SizedBox(height: screenHeight * 0.025),
        _buildAreaManagementSection(context),
        SizedBox(height: screenHeight * 0.025),
            ],
          ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, AuthService authService) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'ar').format(now);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.04),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.fromRGBO(225, 34, 34, 1),
            Color.fromRGBO(180, 30, 30, 1),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(225, 34, 34, 0.08),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
      children: [
          CircleAvatar(
            radius: screenWidth * 0.08,
            backgroundColor: Colors.white,
            child: Icon(Icons.admin_panel_settings, size: screenWidth * 0.09, color: const Color.fromRGBO(225, 34, 34, 1)),
          ),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Obx(() {
              final userData = authService.userData;
              final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
              final isOwner = accountType == 'owner';
              final userName = userData?['name'] ?? 'المستخدم';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOwner ? 'لوحة تحكم المالك' : 'لوحة تحكم المدير',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    'مرحباً $userName',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.white.withOpacity(0.85),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              );
            }),
          ),
          // App logo or quick summary can go here
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, AuthService authService) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(225, 34, 34, 1),
            Color.fromRGBO(180, 30, 30, 1),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  size: screenWidth * 0.08,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Obx(() {
                  final userData = authService.userData;
                  final currentUser = authService.currentUser;
                  
                  if (userData == null && currentUser == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً بك،',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'مدير النظام',
                          style: TextStyle(
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'مالك النظام',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    );
                  }
                  
                  final userName = userData?['name'] ?? 'المستخدم';
                  final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
                  final isOwner = accountType == 'owner';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً بك،',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isOwner ? 'مالك النظام' : 'مدير النظام',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.025),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.trending_up,
                  size: screenWidth * 0.05,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.015,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الحالة: نشط',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenWidth * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'متصل',
                    style: TextStyle(
                      fontSize: screenWidth * 0.025,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(BuildContext context, int totalVotes, int activeCollectors, String participationRate, int activeAreas) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _animatedStatCard(
          context,
          icon: Icons.how_to_vote,
          color: Colors.green,
          bgColor: Colors.green.shade50,
          value: totalVotes,
          label: 'الأصوات المجمعة',
          duration: 1200,
        ),
        _animatedStatCard(
          context,
          icon: Icons.person_add,
          color: Colors.orange,
          bgColor: Colors.orange.shade50,
          value: activeCollectors,
          label: 'المجمعين النشطين',
          duration: 1400,
        ),
        _animatedStatCard(
          context,
          icon: Icons.location_on,
          color: Colors.purple,
          bgColor: Colors.purple.shade50,
          value: activeAreas,
          label: 'المناطق النشطة',
          duration: 1600,
        ),
      ],
    );
  }

  Widget _animatedStatCard(BuildContext context, {required IconData icon, required Color color, required Color bgColor, required int value, required String label, int duration = 1000}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.03, horizontal: screenWidth * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: EdgeInsets.all(screenWidth * 0.045),
              child: Icon(icon, color: color, size: screenWidth * 0.09),
            ),
            SizedBox(height: screenHeight * 0.02),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: value),
              duration: Duration(milliseconds: duration),
              builder: (context, val, child) => Text(
                '$val',
                  style: TextStyle(
                  fontSize: screenWidth * 0.09,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Cairo',
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
          Text(
              label,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context, Map<String, int> areaVotes, Map<String, int> dailyVotes, String participationRate, int totalVotes, int activeAreas) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التحليلات والإحصائيات',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        
        // Charts Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: screenWidth * 0.03,
          mainAxisSpacing: screenHeight * 0.02,
          childAspectRatio: 1.4,
          children: [
            _buildChartCard(
              context,
              'توزيع الأصوات',
              '$totalVotes',
              Icons.pie_chart,
              Colors.green,
              _buildPieChart(totalVotes),
            ),
            _buildChartCard(
              context,
              'الأداء اليومي',
              dailyVotes.length.toString(),
              Icons.show_chart,
              Colors.orange,
              _buildLineChart(dailyVotes),
            ),
            _buildChartCard(
              context,
              'المناطق النشطة',
              '$activeAreas',
              Icons.location_on,
              Colors.purple,
              _buildBarChart(areaVotes),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard(BuildContext context, String title, String value, IconData icon, Color color, Widget chart) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Icon(
                icon,
                size: screenWidth * 0.05,
                color: color,
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.015),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: screenWidth * 0.015),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildProgressChart(double progress) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(int totalVotes) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.blue, Colors.orange, Colors.purple],
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<String, int> dailyVotes) {
    return Container(
      height: 35,
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: LineChartPainter(dailyVotes),
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> areaVotes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBar(areaVotes['القاهرة'] ?? 0, Colors.purple),
        _buildBar(areaVotes['الجيزة'] ?? 0, Colors.purple),
        _buildBar(areaVotes['القليوبية'] ?? 0, Colors.purple),
        _buildBar(areaVotes['الإسكندرية'] ?? 0, Colors.purple),
      ],
    );
  }

  Widget _buildBar(int height, Color color) {
    return Container(
      width: 6,
      height: 35 * ((height.toDouble()) / 1000), // Scale height based on total votes
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Color _getPerformanceColor(String performance) {
    final value = int.tryParse(performance.replaceAll('%', '')) ?? 0;
    if (value >= 90) return Colors.green;
    if (value >= 80) return Colors.orange;
    return Colors.red;
  }

  Widget _buildQuickActions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final AuthService authService = Get.find<AuthService>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإجراءات السريعة',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        
        Obx(() {
          final userData = authService.userData;
          final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
          final isOwner = accountType == 'owner';
          final shouldShowAddUser = isOwner;
          return Column(
            children: [
              Row(
                children: [
                  if (shouldShowAddUser) ...[
                    Expanded(
                      child: _buildActionButton(
                        context,
                        'إضافة مستخدم',
                        Icons.person_add,
                        Colors.blue,
                        () => _showAddUserBottomSheet(),
                      ),
                    ),
                  ],
                ],
              ),
              // Removed report, print all users, and print user data buttons
            ],
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenHeight * 0.015,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: screenWidth * 0.055,
              color: Colors.white,
            ),
            SizedBox(height: screenHeight * 0.008),
            Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
      backgroundColor: Colors.blue.withOpacity(0.1),
      colorText: Colors.blue,
      duration: const Duration(seconds: 2),
    );
  }

  void _showAddUserBottomSheet() {
    Get.bottomSheet(
      const AddUserBottomSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  Widget _buildAreaManagementSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final AuthService authService = Get.find<AuthService>();
    final FirebaseService firebaseService = Get.find<FirebaseService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إدارة المناطق',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: screenHeight * 0.015),
        Obx(() {
          final userData = authService.userData;
          final accountType = userData?['accountType']?.toString().toLowerCase().trim() ?? '';
          final isOwner = accountType == 'owner';

          if (!isOwner) {
            return const Center(
              child: Text(
                'لا تملك صلاحيات لإدارة المناطق.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            );
          }

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context,
                      'إضافة منطقة جديدة',
                      Icons.add_location_alt,
                      Colors.purple,
                      () => _showAddAreaDialog(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.015),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('customAreas').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final areas = snapshot.data?.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['name'] as String? ?? '';
                  }).where((name) => name.isNotEmpty).toList() ?? [];

                  if (areas.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Text(
                          'لا توجد مناطق مضافة',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Text(
                        'المناطق المضافة:',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      ...areas.map((area) => _buildAreaCard(context, area)).toList(),
                    ],
                  );
                },
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildAreaCard(BuildContext context, String area) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Card(
      margin: EdgeInsets.symmetric(vertical: screenHeight * 0.007),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: screenHeight * 0.012),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.purple[400]),
            SizedBox(width: screenWidth * 0.02),
            Expanded(
              child: Text(
                area,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue[400]),
              onPressed: () => _showEditAreaDialog(area),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAreaDialog() {
    final TextEditingController areaController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    Get.dialog(
      Material(
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
                      color: const Color.fromRGBO(34, 139, 34, 1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.add_location_alt,
                      color: Colors.white,
                      size: screenWidth * 0.08,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'إضافة منطقة جديدة',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextFormField(
                      controller: areaController,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.grey[700],
                      ),
                      decoration: InputDecoration(
                        hintText: 'أدخل اسم المنطقة',
                        hintStyle: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenHeight * 0.015,
                        ),
                      ),
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
                          onPressed: () async {
                            final areaName = areaController.text.trim();
                            if (areaName.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('customAreas').add({
                                'name': areaName,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              Get.back();
                              Get.snackbar(
                                'تمت إضافة المنطقة',
                                'تمت إضافة المنطقة "$areaName" بنجاح.',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(34, 139, 34, 1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                            elevation: 2,
                          ),
                          child: Text(
                            'إضافة',
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
      ),
    );
  }

  void _showEditAreaDialog(String currentArea) {
    final TextEditingController areaController = TextEditingController(text: currentArea);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    Get.dialog(
      Material(
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
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.edit_location,
                      color: Colors.white,
                      size: screenWidth * 0.08,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'تعديل المنطقة',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextFormField(
                      controller: areaController,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        color: Colors.grey[700],
                      ),
                      decoration: InputDecoration(
                        hintText: 'أدخل اسم المنطقة',
                        hintStyle: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenHeight * 0.015,
                        ),
                      ),
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
                          onPressed: () async {
                            final newAreaName = areaController.text.trim();
                            if (newAreaName.isNotEmpty && newAreaName != currentArea) {
                              // Update the area name in customAreas collection
                              final areaQuery = await FirebaseFirestore.instance
                                  .collection('customAreas')
                                  .where('name', isEqualTo: currentArea)
                                  .get();
                              
                              for (final doc in areaQuery.docs) {
                                await doc.reference.update({'name': newAreaName});
                              }
                              
                              // Update all users who have this area assigned
                              final usersQuery = await FirebaseFirestore.instance
                                  .collection('users')
                                  .where('assignedAreas', arrayContains: currentArea)
                                  .get();
                              
                              for (final userDoc in usersQuery.docs) {
                                final currentAreas = List<String>.from(userDoc.data()['assignedAreas'] ?? []);
                                final updatedAreas = currentAreas.map((area) => 
                                  area == currentArea ? newAreaName : area
                                ).toList();
                                
                                await userDoc.reference.update({'assignedAreas': updatedAreas});
                              }
                              
                              Get.back();
                              Get.snackbar(
                                'تم تحديث المنطقة',
                                'تم تحديث المنطقة من "$currentArea" إلى "$newAreaName" بنجاح.',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
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
      ),
    );
  }
} 