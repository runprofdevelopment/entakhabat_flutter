import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Observable user
  final Rx<User?> _user = Rx<User?>(null);
  User? get user => _user.value;
  
  // Observable user data from Firestore
  final Rx<Map<String, dynamic>?> _userData = Rx<Map<String, dynamic>?>(null);
  Map<String, dynamic>? get userData => _userData.value;
  
  // Observable authentication state
  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  // Collector status listener subscription
  StreamSubscription<DocumentSnapshot>? _collectorStatusSub;

  @override
  void onInit() {
    super.onInit();
    // Listen to authentication state changes
    _user.bindStream(_auth.authStateChanges());
    
    // When user changes, fetch their data
    ever(_user, (User? user) async {
      if (user != null) {
        debugPrint('AuthService: User signed in, fetching data for: ${user.uid}');
        await fetchUserData(user.uid);
        _startCollectorStatusListener(user.uid);
      } else {
        debugPrint('AuthService: User signed out, clearing data');
        _userData.value = null;
        _stopCollectorStatusListener();
      }
    });
  }

  void _startCollectorStatusListener(String uid) {
    _stopCollectorStatusListener();
    _collectorStatusSub = _firestore.collection('users').doc(uid).snapshots().listen((doc) async {
      if (!doc.exists) {
        // User document deleted
        await _auth.signOut();
        _userData.value = null;
        Get.snackbar(
          'تم حذف الحساب',
          'تم حذف حسابك من قبل الإدارة',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      } else if (doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['accountType'] == 'collector' && data['isActive'] == false) {
          // Log out immediately and show toast
          await _auth.signOut();
          _userData.value = null;
          Get.snackbar(
            'تم تعطيل الحساب',
            'تم تعطيل حسابك أثناء الاستخدام، يرجى التواصل مع الإدارة',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      }
    });
  }

  void _stopCollectorStatusListener() {
    _collectorStatusSub?.cancel();
    _collectorStatusSub = null;
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading.value = true;
      debugPrint('AuthService: Attempting to sign in with email: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('AuthService: Firebase Auth successful, UID: ${userCredential.user!.uid}');
      
      // Set user information in Crashlytics
      FirebaseCrashlytics.instance.setUserIdentifier(userCredential.user!.uid);
      FirebaseCrashlytics.instance.setCustomKey('user_email', email);
      FirebaseCrashlytics.instance.setCustomKey('sign_in_method', 'email_password');
      
      // Fetch user data from Firestore after successful authentication
      final userData = await fetchUserData(userCredential.user!.uid);
      
      // Check if account is disabled
      if (userData != null && userData['isActive'] == false) {
        await _auth.signOut();
        _userData.value = null;
        Get.snackbar(
          'تم تعطيل الحساب',
          'تم تعطيل حسابك، يرجى التواصل مع الإدارة',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
        return null;
      }
      if (userData != null) {
        debugPrint('AuthService: User data fetched successfully: $userData');
        
        // Print comprehensive user data after successful sign-in
        _printUserData(userData, userCredential.user!);
        
        // Print all users in the database for debugging
        await printAllUsers();
        
        Get.snackbar(
          'نجح تسجيل الدخول',
          'مرحباً بك في إنتخابات',
          backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        return userCredential;
      } else {
        debugPrint('AuthService: User data not found in Firestore, signing out');
        // User data not found, sign out the user
        await _auth.signOut();
        return null;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: Firebase Auth error during login: $e');
      
      // Report to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Firebase Auth error during sign in',
        information: ['Email: $email', 'Error code: ${e.code}'],
      );
      
      String errorMessage = 'حدث خطأ في تسجيل الدخول';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'البريد الإلكتروني غير مسجل';
          break;
        case 'wrong-password':
          errorMessage = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صحيح';
          break;
        case 'user-disabled':
          errorMessage = 'تم تعطيل هذا الحساب';
          break;
        case 'too-many-requests':
          errorMessage = 'تم تجاوز عدد المحاولات المسموح، حاول لاحقاً';
          break;
        case 'network-request-failed':
          errorMessage = 'تحقق من اتصالك بالإنترنت';
          break;
        case 'invalid-credential':
          errorMessage = 'بيانات الاعتماد غير صحيحة';
          break;
        default:
          errorMessage = 'خطأ في Firebase Auth: ${e.message}';
      }
      
      Get.snackbar(
        'خطأ في تسجيل الدخول',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      
      return null;
    } catch (e) {
      debugPrint('AuthService: General error during login: $e');
      
      // Report to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'General error during sign in',
        information: ['Email: $email'],
      );
      
      Get.snackbar(
        'خطأ في تسجيل الدخول',
        'حدث خطأ غير متوقع',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return null;
    } finally {
      _isLoading.value = false;
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading.value = true;
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      Get.snackbar(
        'تم إنشاء الحساب بنجاح',
        'مرحباً بك في إنتخابات',
        backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'حدث خطأ في إنشاء الحساب';
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'كلمة المرور ضعيفة جداً';
          break;
        case 'email-already-in-use':
          errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صحيح';
          break;
        case 'operation-not-allowed':
          errorMessage = 'تسجيل الحسابات معطل';
          break;
      }
      
      Get.snackbar(
        'خطأ في إنشاء الحساب',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
      return null;
    } catch (e) {
      Get.snackbar(
        'خطأ في إنشاء الحساب',
        'حدث خطأ غير متوقع',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return null;
    } finally {
      _isLoading.value = false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('AuthService: Starting sign out process');
      await _auth.signOut();
      debugPrint('AuthService: Firebase sign out successful');
      
      // Clear user data
      _userData.value = null;
      debugPrint('AuthService: User data cleared');
      
      Get.snackbar(
        'تم تسجيل الخروج',
        'شكراً لاستخدام إنتخابات',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      debugPrint('AuthService: Sign out completed successfully');
    } catch (e) {
      debugPrint('AuthService: Error during sign out: $e');
      Get.snackbar(
        'خطأ في تسجيل الخروج',
        'حدث خطأ أثناء تسجيل الخروج',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      _isLoading.value = true;
      await _auth.sendPasswordResetEmail(email: email);
      
      Get.snackbar(
        'تم إرسال رابط إعادة تعيين كلمة المرور',
        'تحقق من بريدك الإلكتروني',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'حدث خطأ في إرسال رابط إعادة التعيين';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'البريد الإلكتروني غير مسجل';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صحيح';
          break;
      }
      
      Get.snackbar(
        'خطأ في إرسال الرابط',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'خطأ في إرسال الرابط',
        'حدث خطأ غير متوقع',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  // Fetch user data from Firestore
  Future<Map<String, dynamic>?> fetchUserData(String authUID) async {
    try {
      debugPrint('AuthService: Fetching user data for AuthUID: $authUID');
      
      // Get user document directly by ID (since document ID = user UID)
      final DocumentSnapshot docSnapshot = await _firestore
          .collection('users')
          .doc(authUID)
          .get();

      debugPrint('AuthService: Document exists: ${docSnapshot.exists}');

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        debugPrint('AuthService: User data found: $userData');
        _userData.value = userData;
        return userData;
      } else {
        _userData.value = null;
        debugPrint('AuthService: No user data found for AuthUID: $authUID');
        Get.snackbar(
          'خطأ في البيانات',
          'لم يتم العثور على بيانات المستخدم',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return null;
      }
    } catch (e) {
      _userData.value = null;
      debugPrint('AuthService: Error fetching user data: $e');
      Get.snackbar(
        'خطأ في قاعدة البيانات',
        'فشل في جلب بيانات المستخدم: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return null;
    }
  }

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Refresh authentication token
  Future<void> refreshToken() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        debugPrint('AuthService: Token refreshed successfully');
      }
    } catch (e) {
      debugPrint('AuthService: Error refreshing token: $e');
      // If token refresh fails, sign out the user
      await signOut();
    }
  }
  
  // Check and refresh authentication if needed
  Future<bool> ensureValidAuth() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('AuthService: No current user found');
        return false;
      }
      
      // Try to refresh the token
      await currentUser.reload();
      
      // Verify user exists in Firestore
      final userData = await fetchUserData(currentUser.uid);
      if (userData == null) {
        debugPrint('AuthService: User not found in Firestore');
        return false;
      }
      
      debugPrint('AuthService: Authentication is valid');
      return true;
    } catch (e) {
      debugPrint('AuthService: Authentication is invalid, signing out: $e');
      await signOut();
      return false;
    }
  }
  
  // Print comprehensive user data for debugging
  void _printUserData(Map<String, dynamic> userData, User firebaseUser) {
    debugPrint('=== USER DATA AFTER SIGN IN ===');
    debugPrint('Firebase Auth User:');
    debugPrint('  UID: ${firebaseUser.uid}');
    debugPrint('  Email: ${firebaseUser.email}');
    debugPrint('  Email Verified: ${firebaseUser.emailVerified}');
    debugPrint('  Display Name: ${firebaseUser.displayName}');
    debugPrint('  Photo URL: ${firebaseUser.photoURL}');
    debugPrint('  Phone Number: ${firebaseUser.phoneNumber}');
    debugPrint('  Creation Time: ${firebaseUser.metadata.creationTime}');
    debugPrint('  Last Sign In: ${firebaseUser.metadata.lastSignInTime}');
    debugPrint('  Provider Data: ${firebaseUser.providerData.map((p) => p.providerId).toList()}');
    
    debugPrint('Firestore User Data:');
    debugPrint('  Name: ${userData['name'] ?? 'N/A'}');
    debugPrint('  Email: ${userData['email'] ?? 'N/A'}');
    debugPrint('  Phone: ${userData['phone'] ?? 'N/A'}');
    debugPrint('  Account Type: ${userData['accountType'] ?? 'N/A'}');
    debugPrint('  Assigned Areas: ${userData['assignedAreas'] ?? 'N/A'}');
    debugPrint('  Created At: ${userData['createdAt'] ?? 'N/A'}');
    debugPrint('  Created By: ${userData['createdBy'] ?? 'N/A'}');
    debugPrint('  Is Active: ${userData['isActive'] ?? 'N/A'}');
    
    // Print any additional fields that might exist
    debugPrint('Additional Fields:');
    userData.forEach((key, value) {
      if (!['name', 'email', 'phone', 'accountType', 'assignedAreas', 'createdAt', 'createdBy', 'isActive'].contains(key)) {
        debugPrint('  $key: $value');
      }
    });
    
    debugPrint('=== END USER DATA ===');
  }
  
  // Print all users in the database (for debugging)
  Future<void> printAllUsers() async {
    try {
      debugPrint('=== FETCHING ALL USERS ===');
      final QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      
      debugPrint('Total users found: ${usersSnapshot.docs.length}');
      
      for (int i = 0; i < usersSnapshot.docs.length; i++) {
        final doc = usersSnapshot.docs[i];
        final userData = doc.data() as Map<String, dynamic>;
        
        debugPrint('User ${i + 1}:');
        debugPrint('  Document ID: ${doc.id}');
        debugPrint('  Name: ${userData['name'] ?? 'N/A'}');
        debugPrint('  Email: ${userData['email'] ?? 'N/A'}');
        debugPrint('  Phone: ${userData['phone'] ?? 'N/A'}');
        debugPrint('  Account Type: ${userData['accountType'] ?? 'N/A'}');
        debugPrint('  Assigned Areas: ${userData['assignedAreas'] ?? 'N/A'}');
        debugPrint('  Created At: ${userData['createdAt'] ?? 'N/A'}');
        debugPrint('  Created By: ${userData['createdBy'] ?? 'N/A'}');
        debugPrint('  Is Active: ${userData['isActive'] ?? 'N/A'}');
        debugPrint('  ---');
      }
      
      debugPrint('=== END ALL USERS ===');
    } catch (e) {
      debugPrint('Error fetching all users: $e');
    }
  }
  
  // Manually print current user data (can be called from any screen)
  Future<void> printCurrentUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('No user currently signed in');
      return;
    }
    
    final userData = await fetchUserData(currentUser.uid);
    if (userData != null) {
      _printUserData(userData, currentUser);
    } else {
      debugPrint('Failed to fetch current user data');
    }
  }

} 