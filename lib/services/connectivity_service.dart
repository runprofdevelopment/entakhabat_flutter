import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxController {
  static ConnectivityService get to => Get.find();
  
  final _isConnected = true.obs;
  final _isFirebaseInitialized = false.obs;
  final _isChecking = false.obs;
  
  bool get isConnected => _isConnected.value;
  bool get isFirebaseInitialized => _isFirebaseInitialized.value;
  bool get isChecking => _isChecking.value;
  
  Stream<bool> get connectivityStream => _isConnected.stream;
  Stream<bool> get firebaseStream => _isFirebaseInitialized.stream;

  @override
  void onInit() {
    super.onInit();
    _initializeConnectivity();
    _initializeFirebase();
  }

  void _initializeConnectivity() {
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkInternetConnection();
    });
    
    // Initial check
    _checkInternetConnection();
  }

  Future<void> _checkInternetConnection() async {
    _isChecking.value = true;
    
    try {
      // Check if we can reach a reliable host
      final result = await InternetAddress.lookup('google.com');
      _isConnected.value = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isConnected.value = false;
    } catch (_) {
      _isConnected.value = false;
    }
    
    _isChecking.value = false;
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      _isFirebaseInitialized.value = true;
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      _isFirebaseInitialized.value = false;
      debugPrint('Firebase initialization failed: $e');
    }
  }

  Future<bool> checkFirebaseAndInternet() async {
    // If Firebase is already initialized, we have internet
    if (_isFirebaseInitialized.value) {
      _isConnected.value = true;
      return true;
    }
    
    // Try to initialize Firebase (this will fail if no internet)
    await _initializeFirebase();
    
    // If Firebase initialized successfully, we have internet
    if (_isFirebaseInitialized.value) {
      _isConnected.value = true;
      return true;
    }
    
    // If Firebase failed, check internet separately
    await _checkInternetConnection();
    return isConnected && isFirebaseInitialized;
  }

  void retryConnection() {
    _initializeFirebase();
    _checkInternetConnection();
  }
} 