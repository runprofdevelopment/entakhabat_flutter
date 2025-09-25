import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String accountType; // 'admin' or 'collector'
  final List<String> assignedAreas;
  final DateTime createdAt;
  final String createdBy; // ID of the user who created this user
  final DateTime? lastLoginAt;
  final bool isActive;
  
  // Collector specific fields
  final int? totalVotesCollected;
  final int? dailyTarget;
  final int? monthlyTarget;
  final double? performanceRating;
  final List<PerformanceRecord>? performanceHistory;
  final Map<String, int>? areaVotesCount; // votes collected per area
  
  // Admin specific fields
  final List<String>? managedCollectors; // list of collector IDs managed by this admin
  final List<String>? adminPermissions; // list of permissions

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.accountType,
    required this.assignedAreas,
    required this.createdAt,
    required this.createdBy,
    this.lastLoginAt,
    this.isActive = true,
    this.totalVotesCollected,
    this.dailyTarget,
    this.monthlyTarget,
    this.performanceRating,
    this.performanceHistory,
    this.areaVotesCount,
    this.managedCollectors,
    this.adminPermissions,
  });

  // Create from Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    try {
      debugPrint('UserModel: Parsing document ID: $documentId');
      debugPrint('UserModel: Document data: $data');
      
      return UserModel(
        id: documentId,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        accountType: data['accountType'] ?? '',
        assignedAreas: List<String>.from(data['assignedAreas'] ?? []),
        createdAt: data['createdAt'] != null 
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        createdBy: data['createdBy'] ?? '',
        lastLoginAt: data['lastLoginAt'] != null 
            ? (data['lastLoginAt'] as Timestamp).toDate() 
            : null,
        isActive: data['isActive'] ?? true,
        totalVotesCollected: data['totalVotesCollected'] ?? 0,
        dailyTarget: data['dailyTarget'],
        monthlyTarget: data['monthlyTarget'],
        performanceRating: data['performanceRating']?.toDouble() ?? 0.0,
        performanceHistory: data['performanceHistory'] != null
            ? (data['performanceHistory'] as List)
                .map((record) => PerformanceRecord.fromMap(record))
                .toList()
            : null,
        areaVotesCount: data['areaVotesCount'] != null
            ? Map<String, int>.from(data['areaVotesCount'])
            : null,
        managedCollectors: data['managedCollectors'] != null
            ? List<String>.from(data['managedCollectors'])
            : null,
        adminPermissions: data['adminPermissions'] != null
            ? List<String>.from(data['adminPermissions'])
            : null,
      );
    } catch (e) {
      debugPrint('UserModel: Error parsing document: $e');
      
      // Report to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Error parsing UserModel from Firestore document ID: $documentId',
        information: ['Document data: $data'],
      );
      
      // Return a default user model to prevent crashes
      return UserModel(
        id: documentId,
        name: data['name'] ?? 'Unknown User',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        accountType: data['accountType'] ?? 'collector',
        assignedAreas: [],
        createdAt: DateTime.now(),
        createdBy: '',
        isActive: true,
        totalVotesCollected: 0,
        performanceRating: 0.0,
      );
    }
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'phone': phone,
      'accountType': accountType,
      'assignedAreas': assignedAreas,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'isActive': isActive,
    };

    if (lastLoginAt != null) {
      data['lastLoginAt'] = lastLoginAt;
    }

    // Add collector specific fields
    if (accountType == 'collector') {
      if (totalVotesCollected != null) data['totalVotesCollected'] = totalVotesCollected;
      if (dailyTarget != null) data['dailyTarget'] = dailyTarget;
      if (monthlyTarget != null) data['monthlyTarget'] = monthlyTarget;
      if (performanceRating != null) data['performanceRating'] = performanceRating;
      if (performanceHistory != null) {
        data['performanceHistory'] = performanceHistory!.map((record) => record.toMap()).toList();
      }
      if (areaVotesCount != null) data['areaVotesCount'] = areaVotesCount;
    }

    // Add admin specific fields
    if (accountType == 'admin') {
      if (managedCollectors != null) data['managedCollectors'] = managedCollectors;
      if (adminPermissions != null) data['adminPermissions'] = adminPermissions;
    }

    return data;
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? accountType,
    List<String>? assignedAreas,
    DateTime? createdAt,
    String? createdBy,
    DateTime? lastLoginAt,
    bool? isActive,
    int? totalVotesCollected,
    int? dailyTarget,
    int? monthlyTarget,
    double? performanceRating,
    List<PerformanceRecord>? performanceHistory,
    Map<String, int>? areaVotesCount,
    List<String>? managedCollectors,
    List<String>? adminPermissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      accountType: accountType ?? this.accountType,
      assignedAreas: assignedAreas ?? this.assignedAreas,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      totalVotesCollected: totalVotesCollected ?? this.totalVotesCollected,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      performanceRating: performanceRating ?? this.performanceRating,
      performanceHistory: performanceHistory ?? this.performanceHistory,
      areaVotesCount: areaVotesCount ?? this.areaVotesCount,
      managedCollectors: managedCollectors ?? this.managedCollectors,
      adminPermissions: adminPermissions ?? this.adminPermissions,
    );
  }
}

class PerformanceRecord {
  final DateTime date;
  final int votesCollected;
  final int target;
  final double achievementRate;
  final String notes;

  PerformanceRecord({
    required this.date,
    required this.votesCollected,
    required this.target,
    required this.achievementRate,
    this.notes = '',
  });

  factory PerformanceRecord.fromMap(Map<String, dynamic> data) {
    return PerformanceRecord(
      date: (data['date'] as Timestamp).toDate(),
      votesCollected: data['votesCollected'] ?? 0,
      target: data['target'] ?? 0,
      achievementRate: data['achievementRate']?.toDouble() ?? 0.0,
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'votesCollected': votesCollected,
      'target': target,
      'achievementRate': achievementRate,
      'notes': notes,
    };
  }
} 