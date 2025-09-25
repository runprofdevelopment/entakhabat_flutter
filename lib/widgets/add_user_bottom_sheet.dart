import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddUserBottomSheet extends StatefulWidget {
  const AddUserBottomSheet({super.key});

  @override
  State<AddUserBottomSheet> createState() => _AddUserBottomSheetState();
}

class _AddUserBottomSheetState extends State<AddUserBottomSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _areaSearchController = TextEditingController();
  final TextEditingController _newAreaController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  String? _selectedRole;
  String? _selectedArea; // Changed from List to single String
  List<String> _customAreas = []; // New list for custom areas
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _showAddAreaDialog = false;
  String? _editingArea; // Track which area is being edited

  @override
  void initState() {
    super.initState();
    _areaSearchController.addListener(_filterAreas);
    _loadCustomAreas();
  }

  Future<void> _loadCustomAreas() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final areasSnapshot = await firestore.collection('customAreas').get();
      
      setState(() {
        _customAreas = areasSnapshot.docs
            .map((doc) => doc.data()['name'] as String)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading custom areas: $e');
    }
  }

  Future<void> _saveAreaToFirestore(String areaName) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('customAreas').add({
        'name': areaName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      Get.snackbar(
        'نجح',
        'تم إضافة المنطقة بنجاح',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Error saving area to Firestore: $e');
      Get.snackbar(
        'خطأ',
        'فشل في إضافة المنطقة: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _areaSearchController.dispose();
    _newAreaController.dispose();
    super.dispose();
  }

  void _filterAreas() {
    setState(() {
      if (_areaSearchController.text.isEmpty) {
        // No filtering for custom areas, as they are added manually
      } else {
        // No filtering for custom areas, as they are added manually
      }
    });
  }

  void _toggleArea(String area) {
    setState(() {
      _selectedArea = area;
    });
  }

  void _addNewArea() {
    _newAreaController.clear();
    _editingArea = null; // Reset editing state for new area
    setState(() {
      _showAddAreaDialog = true;
    });
  }

  void _editArea(String area) {
    _newAreaController.text = area;
    _editingArea = area; // Track the area being edited
    setState(() {
      _showAddAreaDialog = true;
    });
  }

  void _saveArea() {
    final newArea = _newAreaController.text.trim();
    if (newArea.isEmpty) {
      Get.snackbar(
        'خطأ',
        'يرجى إدخال اسم المنطقة',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    if (_editingArea != null && _editingArea != newArea) {
      // Editing an existing area
      _updateAreaInFirestore(_editingArea!, newArea);
    } else if (!_customAreas.contains(newArea)) {
      // Adding a new area
      setState(() {
        _customAreas.add(newArea);
        // Save to Firestore
        _saveAreaToFirestore(newArea);
      });
    } else {
      Get.snackbar(
        'تنبيه',
        'هذه المنطقة موجودة بالفعل',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    setState(() {
      _selectedArea = newArea;
      _showAddAreaDialog = false;
      _editingArea = null; // Reset editing state
    });
  }

  Future<void> _updateAreaInFirestore(String oldAreaName, String newAreaName) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Update the area name in customAreas collection
      final areaQuery = await firestore
          .collection('customAreas')
          .where('name', isEqualTo: oldAreaName)
          .get();
      
      for (final doc in areaQuery.docs) {
        await doc.reference.update({'name': newAreaName});
      }
      
      // Update all users who have this area assigned
      final usersQuery = await firestore
          .collection('users')
          .where('assignedAreas', arrayContains: oldAreaName)
          .get();
      
      for (final userDoc in usersQuery.docs) {
        final currentAreas = List<String>.from(userDoc.data()['assignedAreas'] ?? []);
        final updatedAreas = currentAreas.map((area) => 
          area == oldAreaName ? newAreaName : area
        ).toList();
        
        await userDoc.reference.update({'assignedAreas': updatedAreas});
      }
      
      // Update local list
      setState(() {
        _customAreas.remove(oldAreaName);
        _customAreas.add(newAreaName);
      });
      
      Get.snackbar(
        'نجح',
        'تم تحديث المنطقة بنجاح',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Error updating area in Firestore: $e');
      Get.snackbar(
        'خطأ',
        'فشل في تحديث المنطقة: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _addUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      Get.snackbar(
        'خطأ',
        'يرجى اختيار دور المستخدم',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (_selectedArea == null) {
      Get.snackbar(
        'خطأ',
        'يرجى اختيار منطقة أو إضافة منطقة جديدة',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Create user using Firebase service
    final FirebaseService firebaseService = Get.find<FirebaseService>();
    final AuthService authService = Get.find<AuthService>();
    
    final currentUser = authService.currentUser;
    
    String currentUserId = '';
    if (currentUser != null) {
      // Normal authentication flow
      final bool isAuthValid = await authService.ensureValidAuth();
      if (!isAuthValid) {
        Get.snackbar(
          'خطأ في المصادقة',
          'انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      currentUserId = currentUser.uid;
    }
    
    // Check if we have a valid current user
    if (currentUserId.isEmpty) {
      Get.snackbar(
        'خطأ',
        'لم يتم العثور على المستخدم الحالي، يرجى إعادة تسجيل الدخول',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    debugPrint('Creating user with createdBy: $currentUserId'); // Debug log
    debugPrint('Current user email: ${authService.currentUser?.email}'); // Debug log
    debugPrint('Current user data: ${authService.userData}'); // Debug log
    
    final bool success = await firebaseService.createUser(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      accountType: _selectedRole!,
      assignedAreas: _selectedRole == 'owner' ? [] : [_selectedArea!],
      createdBy: currentUserId,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      // Show success toast with user credentials
      Get.snackbar(
        'نجح',
        'تم إضافة المستخدم بنجاح\nالبريد: ${_emailController.text.trim()}\nكلمة المرور: ${_passwordController.text}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.TOP,
        maxWidth: 400,
      );
      
      // Clear form
      setState(() {
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _phoneController.clear();
        _areaSearchController.clear();
        _selectedRole = null;
        _selectedArea = null;
        // Don't clear _customAreas as they should persist
        _isPasswordVisible = false;
      });
      
      // Reset form validation
      _formKey.currentState?.reset();
      
      // Scroll to top
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final scrollController = PrimaryScrollController.of(context);
          scrollController?.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
      
      // Don't close bottom sheet - let owner stay and create more users
      // Future.delayed(const Duration(milliseconds: 500), () {
      //   if (mounted) {
      //     Get.back();
      //   }
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: screenHeight * 0.02),
            width: screenWidth * 0.1,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إضافة مستخدم جديد',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.close,
                    size: screenWidth * 0.06,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field
                    Text(
                      'اسم المستخدم',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[700],
                        ),
                        decoration: InputDecoration(
                          hintText: 'أدخل اسم المستخدم',
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال اسم المستخدم';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.025),
                    
                    // Email Field
                    Text(
                      'البريد الإلكتروني',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[700],
                        ),
                        decoration: InputDecoration(
                          hintText: 'أدخل البريد الإلكتروني',
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'البريد الإلكتروني غير صحيح';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.025),
                    
                    // Password Field
                    Text(
                      'كلمة المرور',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[700],
                        ),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور',
                          hintStyle: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.04,
                            vertical: screenHeight * 0.015,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey[600],
                              size: screenWidth * 0.05,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          if (value.length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.025),
                    
                    // Phone Field
                    Text(
                      'رقم الهاتف',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[700],
                        ),
                        decoration: InputDecoration(
                          hintText: 'أدخل رقم الهاتف (11 رقم)',
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال رقم الهاتف';
                          }
                          if (value.length != 11) {
                            return 'رقم الهاتف يجب أن يكون 11 رقم';
                          }
                          if (!RegExp(r'^[0-9]{11}$').hasMatch(value)) {
                            return 'رقم الهاتف يجب أن يحتوي على أرقام فقط';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.025),
                    
                    // Role Selection
                    Text(
                      'دور المستخدم',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'owner'),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.01,
                                vertical: screenHeight * 0.015,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'owner' 
                                    ? const Color.fromRGBO(34, 139, 34, 1)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: _selectedRole == 'owner'
                                      ? const Color.fromRGBO(34, 139, 34, 1)
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: _selectedRole == 'owner' 
                                        ? Colors.white 
                                        : Colors.grey[600],
                                    size: screenWidth * 0.04,
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
                                  Flexible(
                                    child: Text(
                                      'مالك',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedRole == 'owner' 
                                            ? Colors.white 
                                            : Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'admin'),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.01,
                                vertical: screenHeight * 0.015,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'admin' 
                                    ? Colors.grey[700]
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: _selectedRole == 'admin'
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: _selectedRole == 'admin' 
                                        ? Colors.white 
                                        : Colors.grey[600],
                                    size: screenWidth * 0.04,
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
                                  Flexible(
                                    child: Text(
                                      'مدير',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedRole == 'admin' 
                                            ? Colors.white 
                                            : Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'collector'),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.01,
                                vertical: screenHeight * 0.015,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'collector' 
                                    ? const Color.fromRGBO(225, 34, 34, 1)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: _selectedRole == 'collector'
                                      ? const Color.fromRGBO(225, 34, 34, 1)
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add,
                                    color: _selectedRole == 'collector' 
                                        ? Colors.white 
                                        : Colors.grey[600],
                                    size: screenWidth * 0.04,
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
                                  Flexible(
                                    child: Text(
                                      'مجمع',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedRole == 'collector' 
                                            ? Colors.white 
                                            : Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: screenHeight * 0.025),
                    
                    // Area Selection
                    if (_selectedRole != 'owner') ...[
                    Text(
                          'المنطقة المخصصة',
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                        // Add Area Button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _addNewArea,
                            icon: Icon(Icons.add, size: screenWidth * 0.05),
                            label: Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                              child: Text('إضافة منطقة', style: TextStyle(fontSize: screenWidth * 0.04)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(34, 139, 34, 1),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015, horizontal: screenWidth * 0.04),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                    SizedBox(height: screenHeight * 0.015),
                        // Selected Area
                        if (_selectedArea != null) ...[
                      Text(
                            'المنطقة المختارة:',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.03,
                              vertical: screenHeight * 0.008,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(225, 34, 34, 1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedArea!,
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.035,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                GestureDetector(
                                  onTap: () => setState(() => _selectedArea = null),
                                  child: Icon(
                                    Icons.close,
                                    size: screenWidth * 0.04,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      SizedBox(height: screenHeight * 0.02),
                    ],
                    // Areas List
                        if (_customAreas.isNotEmpty) ...[
                          Text(
                            'المناطق المضافة:',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                    Container(
                            height: screenHeight * 0.15,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListView.builder(
                              itemCount: _customAreas.length,
                        itemBuilder: (context, index) {
                                final area = _customAreas[index];
                                final isSelected = _selectedArea == area;
                          return ListTile(
                            title: Text(
                              area,
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: isSelected ? const Color.fromRGBO(225, 34, 34, 1) : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            leading: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected 
                                  ? const Color.fromRGBO(225, 34, 34, 1)
                                  : Colors.grey[400],
                              size: screenWidth * 0.05,
                            ),
                                  trailing: IconButton(
                                    onPressed: () => _editArea(area),
                                    icon: Icon(Icons.edit, size: screenWidth * 0.04, color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(
                                      minWidth: screenWidth * 0.08,
                                      minHeight: screenWidth * 0.08,
                                    ),
                                  ),
                            tileColor: isSelected 
                                ? Colors.grey[50]
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onTap: () => _toggleArea(area),
                          );
                        },
                      ),
                    ),
                        ],
                    SizedBox(height: screenHeight * 0.04),
                    ],
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: screenWidth * 0.05,
                                height: screenWidth * 0.05,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'إضافة المستخدم',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.02),
                    
                    
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
        ),
        // Add/Edit Area Dialog
        if (_showAddAreaDialog)
          Container(
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
                        _editingArea != null ? Icons.edit_location : Icons.add_location_alt,
                        color: Colors.white,
                        size: screenWidth * 0.08,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Text(
                      _editingArea != null ? 'تعديل المنطقة' : 'إضافة منطقة جديدة',
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
                        controller: _newAreaController,
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
                            onPressed: () => setState(() => _showAddAreaDialog = false),
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
                            onPressed: _saveArea,
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
                              'حفظ',
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
      ],
    );
  }
} 