import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ApiService extends GetxService {
  static const String baseUrl = 'https://entakhabat-api-rrs7hvh2wq-ey.a.run.app';
  
  // Get Firebase ID token for authentication
  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  // Create user via external API
  Future<Map<String, dynamic>?> createUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String accountType,
    required List<String> assignedAreas,
    bool isActive = true,
    List<String> adminPermissions = const ['read', 'write'],
  }) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        _showError('خطأ في المصادقة', 'فشل في الحصول على رمز المصادقة');
        return null;
      }

      final requestBody = {
        'email': email,
        'password': password,
        'name': name,
        'phone': "+2$phone",
        'accountType': accountType,
        'isActive': isActive,
        'adminPermissions': adminPermissions,
      };
      
      // Only include assignedAreas for non-owner account types
      if (accountType != 'owner') {
        requestBody['assignedAreas'] = assignedAreas;
      }

      debugPrint('Creating user via API...');
      debugPrint('Request URL: $baseUrl/users');
      debugPrint('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('API Response - Status: ${response.statusCode}');
      debugPrint('API Response - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response indicates success: false
        if (responseData is Map && responseData['success'] == false) {
          String errorMessage = responseData['error'] ?? responseData['message'] ?? 'حدث خطأ في إنشاء المستخدم';
          _showError('خطأ', errorMessage);
          return null;
        }
        
        _showSuccess('نجح', 'تم إنشاء المستخدم بنجاح');
        return responseData;
      } else {
        String errorMessage = 'حدث خطأ في إنشاء المستخدم (${response.statusCode})';
        
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        _showError('خطأ', errorMessage);
        return null;
      }
    } catch (e) {
      debugPrint('Create user API error: $e');
      _showError('خطأ في الاتصال', 'فشل في الاتصال بالخادم: $e');
      return null;
    }
  }

  // Get all users from external API
  Future<List<Map<String, dynamic>>?> getAllUsers() async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        _showError('خطأ في المصادقة', 'فشل في الحصول على رمز المصادقة');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Get Users API - Status: ${response.statusCode}');
      debugPrint('Get Users API - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response indicates success: false
        if (responseData is Map && responseData['success'] == false) {
          String errorMessage = responseData['error'] ?? responseData['message'] ?? 'حدث خطأ في جلب المستخدمين';
          _showError('خطأ', errorMessage);
          return null;
        }
        
        if (responseData is List) {
          return responseData.cast<Map<String, dynamic>>();
        } else if (responseData is Map && responseData.containsKey('users')) {
          return (responseData['users'] as List).cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        String errorMessage = 'حدث خطأ في جلب المستخدمين';
        
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        _showError('خطأ', errorMessage);
        return null;
      }
    } catch (e) {
      debugPrint('Get users API error: $e');
      _showError('خطأ في الاتصال', 'فشل في الاتصال بالخادم: $e');
      return null;
    }
  }

  // Get user by ID from external API
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        _showError('خطأ في المصادقة', 'فشل في الحصول على رمز المصادقة');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Get User API - Status: ${response.statusCode}');
      debugPrint('Get User API - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response indicates success: false
        if (responseData is Map && responseData['success'] == false) {
          String errorMessage = responseData['error'] ?? responseData['message'] ?? 'حدث خطأ في جلب بيانات المستخدم';
          _showError('خطأ', errorMessage);
          return null;
        }
        
        return responseData;
      } else {
        String errorMessage = 'حدث خطأ في جلب بيانات المستخدم';
        
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        _showError('خطأ', errorMessage);
        return null;
      }
    } catch (e) {
      debugPrint('Get user API error: $e');
      _showError('خطأ في الاتصال', 'فشل في الاتصال بالخادم: $e');
      return null;
    }
  }

  // Update user via external API
  Future<bool> updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        _showError('خطأ في المصادقة', 'فشل في الحصول على رمز المصادقة');
        return false;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Update User API - Status: ${response.statusCode}');
      debugPrint('Update User API - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response indicates success: false
        if (responseData is Map && responseData['success'] == false) {
          String errorMessage = responseData['error'] ?? responseData['message'] ?? 'حدث خطأ في تحديث المستخدم';
          _showError('خطأ', errorMessage);
          return false;
        }
        
        _showSuccess('نجح', 'تم تحديث المستخدم بنجاح');
        return true;
      } else {
        String errorMessage = 'حدث خطأ في تحديث المستخدم';
        
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        _showError('خطأ', errorMessage);
        return false;
      }
    } catch (e) {
      debugPrint('Update user API error: $e');
      _showError('خطأ في الاتصال', 'فشل في الاتصال بالخادم: $e');
      return false;
    }
  }

  // Delete user via external API
  Future<bool> deleteUser(String userId) async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        _showError('خطأ في المصادقة', 'فشل في الحصول على رمز المصادقة');
        return false;
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Delete User API - Status: ${response.statusCode}');
      debugPrint('Delete User API - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response indicates success: false
        if (responseData is Map && responseData['success'] == false) {
          String errorMessage = responseData['error'] ?? responseData['message'] ?? 'حدث خطأ في حذف المستخدم';
          _showError('خطأ', errorMessage);
          return false;
        }
        
        _showSuccess('نجح', 'تم حذف المستخدم بنجاح');
        return true;
      } else {
        String errorMessage = 'حدث خطأ في حذف المستخدم';
        
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        _showError('خطأ', errorMessage);
        return false;
      }
    } catch (e) {
      debugPrint('Delete user API error: $e');
      _showError('خطأ في الاتصال', 'فشل في الاتصال بالخادم: $e');
      return false;
    }
  }

  // Helper methods for showing messages
  void _showSuccess(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }
} 