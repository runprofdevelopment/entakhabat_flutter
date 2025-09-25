import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class FirebaseService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a document to Firestore
  Future<void> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).add(data);
      Get.snackbar('Success', 'Document added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add document: $e');
    }
  }

  // Get documents from Firestore
  Stream<QuerySnapshot> getDocuments(String collection) {
    return _firestore.collection(collection).snapshots();
  }

  // Update a document
  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
      Get.snackbar('Success', 'Document updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update document: $e');
    }
  }

  // Delete a document
  Future<void> deleteDocument(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      Get.snackbar('Success', 'Document deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete document: $e');
    }
  }

    // Create new user via external API
  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String accountType,
    required List<String> assignedAreas,
    required String createdBy, // ID of the user creating this account
  }) async {
    debugPrint('FirebaseService.createUser called with createdBy: $createdBy'); // Debug log
    
    // Check if the creating user is an owner
    try {
              debugPrint('Checking creator permissions for user: $createdBy'); // Debug log
      final creatorDoc = await _firestore.collection('users').doc(createdBy).get();
      if (!creatorDoc.exists) {
                  debugPrint('Creator document does not exist for user: $createdBy'); // Debug log
        Get.snackbar(
          'خطأ',
          'المستخدم غير موجود',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
      
      final creatorData = creatorDoc.data()!;
      final creatorAccountType = creatorData['accountType']?.toString().toLowerCase().trim() ?? '';
      
              debugPrint('Creator account type: $creatorAccountType'); // Debug log
      
      if (creatorAccountType != 'owner') {
                  debugPrint('Permission denied: Creator is not an owner'); // Debug log
        Get.snackbar(
          'خطأ',
          'فقط مالك النظام يمكنه إنشاء مستخدمين جدد',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
      
              debugPrint('Permission check passed: Creator is an owner'); // Debug log
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء التحقق من الصلاحيات',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    try {
      // Use external API to create user
      final ApiService apiService = Get.find<ApiService>();
      
      final result = await apiService.createUser(
        email: email,
        password: password,
        name: name,
        phone: phone,
        accountType: accountType,
        assignedAreas: accountType == 'owner' ? [] : assignedAreas,
        isActive: true,
        adminPermissions: accountType == 'admin' ? ['read', 'write'] : ['read'],
      );

      if (result != null) {
        debugPrint('User created successfully via API: $result');
      return true;
      } else {
        debugPrint('Failed to create user via API');
      return false;
      }
    } catch (e) {
      debugPrint('Error creating user via API: $e');
      Get.snackbar(
        'خطأ',
        'حدث خطأ غير متوقع: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  // Get all collectors (active and inactive)
  Stream<List<UserModel>> getAllCollectors() {
    return _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'collector')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get only active collectors (for collector-specific screens)
  Stream<List<UserModel>> getActiveCollectors() {
    return _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'collector')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get all admins
  Stream<List<UserModel>> getAdmins() {
    return _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'admin')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get collector performance
  Stream<UserModel?> getCollectorPerformance(String collectorId) {
    try {
      debugPrint('FirebaseService: Getting collector performance for ID: $collectorId');
      
      return _firestore
          .collection('users')
          .doc(collectorId)
          .snapshots()
          .map((doc) {
        try {
          debugPrint('FirebaseService: Document exists: ${doc.exists}');
          if (doc.exists && doc.data() != null) {
            debugPrint('FirebaseService: Document data: ${doc.data()}');
            return UserModel.fromFirestore(doc.data()!, doc.id);
          }
          debugPrint('FirebaseService: Document does not exist or has no data');
          return null;
        } catch (e) {
          debugPrint('FirebaseService: Error parsing document: $e');
          
          // Report to Crashlytics
          FirebaseCrashlytics.instance.recordError(
            e,
            StackTrace.current,
            reason: 'Error parsing Firestore document for collector ID: $collectorId',
          );
          
          return null;
        }
      }).handleError((error) {
        debugPrint('FirebaseService: Stream error: $error');
        
        // Report to Crashlytics
        FirebaseCrashlytics.instance.recordError(
          error,
          StackTrace.current,
          reason: 'Stream error in getCollectorPerformance for ID: $collectorId',
        );
        
        return null;
      });
    } catch (e) {
      debugPrint('FirebaseService: Error setting up stream: $e');
      
      // Report to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Error setting up stream for collector ID: $collectorId',
      );
      
      return Stream.value(null);
    }
  }

  // Update collector performance
  Future<void> updateCollectorPerformance({
    required String collectorId,
    required int votesCollected,
    required String area,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(collectorId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentData = doc.data()!;
          final currentTotal = currentData['totalVotesCollected'] ?? 0;
          final currentAreaVotes = Map<String, int>.from(currentData['areaVotesCount'] ?? {});
          
          // Update total votes
          transaction.update(docRef, {
            'totalVotesCollected': currentTotal + votesCollected,
            'areaVotesCount.$area': (currentAreaVotes[area] ?? 0) + votesCollected,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      Get.snackbar(
        'نجح',
        'تم تحديث الأداء بنجاح',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث الأداء: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Enable or disable a collector (set isActive)
  Future<void> setCollectorActive(String collectorId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(collectorId).update({'isActive': isActive});
      Get.snackbar(
        isActive ? 'تم التفعيل' : 'تم التعطيل',
        isActive ? 'تم تفعيل المجمع بنجاح' : 'تم تعطيل المجمع بنجاح',
        backgroundColor: isActive ? Colors.green : Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث حالة المجمع: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Delete a collector (does NOT delete collected data)
  Future<void> deleteCollector(String collectorId) async {
    try {
      await _firestore.collection('users').doc(collectorId).delete();
      Get.snackbar(
        'تم الحذف',
        'تم حذف المجمع بنجاح',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في حذف المجمع: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Paginate collectors for infinite scroll
  Future<Map<String, dynamic>> paginateCollectors({
    DocumentSnapshot? lastDoc,
    String statusFilter = 'الكل',
    String areaFilter = '',
    int limit = 20,
  }) async {
    Query query = _firestore.collection('users')
      .where('accountType', isEqualTo: 'collector');
    if (statusFilter == 'مفعل') {
      query = query.where('isActive', isEqualTo: true);
    } else if (statusFilter == 'معطل') {
      query = query.where('isActive', isEqualTo: false);
    }
    if (areaFilter.isNotEmpty) {
      query = query.where('assignedAreas', arrayContains: areaFilter);
    }
    query = query.orderBy('totalVotesCollected', descending: true);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }
    query = query.limit(limit);
    final snapshot = await query.get();
    final collectors = snapshot.docs.map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
    final hasMore = snapshot.docs.length == limit;
    // For area filter dropdown
    final allAreasSnapshot = await _firestore.collection('users').where('accountType', isEqualTo: 'collector').get();
    final Set<String> allAreas = {};
    for (final doc in allAreasSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final List<String> areas = List<String>.from(data['assignedAreas'] ?? []);
      allAreas.addAll(areas);
    }
    return {
      'collectors': collectors,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      'hasMore': hasMore,
      'allAreas': allAreas.toList()..sort(),
    };
  }


} 