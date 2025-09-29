import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LiveBarcodeScannerController extends GetxController {
  // Dependencies
  late final BarcodeScanner _barcodeScanner;
  AudioPlayer? _audioPlayer;
  CameraController? _cameraController;

  // Observable state
  final RxBool isInitialized = false.obs;
  final RxBool isProcessing = false.obs;
  final RxBool isStreamActive = false.obs;
  final RxInt scannedCount = 0.obs;
  final RxString statusMessage = 'جاري تهيئة الكاميرا...'.obs;

  // Private state
  final Set<String> _processedBarcodes = {};
  DateTime? _lastProcessTime;

  // Parameters
  late String selectedArea;
  late String collectorId;
  late String collectorName;

  void initialize({
    required String area,
    required String collector,
    required String collectorNameParam,
  }) {
    selectedArea = area;
    collectorId = collector;
    collectorName = collectorNameParam;
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      // Initialize barcode scanner
      _barcodeScanner = BarcodeScanner();

      // Initialize audio player
      _audioPlayer = AudioPlayer();

      // Request camera permission
      var status = await Permission.camera.request();
      if (status.isDenied) {
        statusMessage.value = 'تم رفض إذن الكاميرا. يرجى السماح بالوصول إلى الكاميرا.';
        return;
      }

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        statusMessage.value = 'لم يتم العثور على كاميرا متاحة.';
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Use high resolution for better quality like native camera app
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.veryHigh, // Use highest resolution for native camera quality
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      isInitialized.value = true;
      statusMessage.value = '🔍 المسح المباشر نشط!\n\n📱 وجه الكاميرا نحو الباركود\n🔊 سيتم تشغيل الصوت عند الاكتشاف';

      // Start image stream
      startImageStream();
    } catch (e) {
      debugPrint('LiveBarcodeScanner - Error initializing: $e');
      statusMessage.value = 'خطأ في تهيئة الماسح: $e\n\nيرجى إعادة تشغيل التطبيق.';
    }
  }

  void startImageStream() {
    if (!isInitialized.value || _cameraController == null || isStreamActive.value) return;

    isStreamActive.value = true;
    _cameraController!.startImageStream((CameraImage image) {
      if (isProcessing.value || !isStreamActive.value) return;

      // Throttle processing more aggressively
      final now = DateTime.now();
      if (_lastProcessTime != null &&
          now.difference(_lastProcessTime!).inMilliseconds < 2000) {
        return;
      }
      _lastProcessTime = now;

      _processImageForBarcodes(image);
    });
  }

  Future<void> _processImageForBarcodes(CameraImage cameraImage) async {
    if (isProcessing.value) return;

    isProcessing.value = true;

    try {
      // Convert CameraImage to InputImage using the improved method
      final inputImage = _buildInputImageFromCameraImage(cameraImage);
      if (inputImage == null) {
        debugPrint('Failed to create InputImage from CameraImage');
        return;
      }

      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        for (final barcode in barcodes) {
          String barcodeText = _getBarcodeContent(barcode);

          // Check if this barcode was already processed recently
          if (_processedBarcodes.contains(barcodeText)) {
            continue;
          }

          debugPrint('LiveBarcodeScanner - 🎯 Barcode detected: ${barcode.format} - $barcodeText');

          // Add to processed set with expiration
          _processedBarcodes.add(barcodeText);
          _clearProcessedBarcode(barcodeText);

          // Play success sound
          await _playSuccessSound();

          statusMessage.value = '🎯 تم اكتشاف باركود!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeText)}\n⏳ جاري رفع البيانات تلقائياً...';

          // Automatically upload the barcode data
          await _submitBarcodeData(barcode, barcodeText);

          // Process only one barcode at a time
          break;
        }
      }
    } catch (e) {
      debugPrint('LiveBarcodeScanner - Error processing image: $e');
      // If we get repeated errors, try to restart the camera
      if (e.toString().contains('IllegalArgumentException')) {
        debugPrint('IllegalArgumentException detected, attempting to restart image stream...');
        _restartImageStream();
      }
    } finally {
      isProcessing.value = false;
    }
  }

  InputImage? _buildInputImageFromCameraImage(CameraImage cameraImage) {
    try {
      // Validate image data first
      if (cameraImage.planes.isEmpty) {
        debugPrint('CameraImage has no planes');
        return null;
      }

      final firstPlane = cameraImage.planes.first;
      if (firstPlane.bytes.isEmpty) {
        debugPrint('CameraImage first plane has no data');
        return null;
      }

      // Get camera info
      final camera = _cameraController!.description;
      final rotation = _getRotation(camera.sensorOrientation);

      // Handle different image formats more carefully
      InputImageFormat format;
      Uint8List bytes;
      int bytesPerRow;

      if (Platform.isAndroid) {
        // For Android, handle YUV420 and NV21 formats
        switch (cameraImage.format.group) {
          case ImageFormatGroup.yuv420:
            format = InputImageFormat.yuv420;
            // For YUV420, we need to concatenate all three planes
            bytes = _concatenateYuv420Planes(cameraImage.planes);
            bytesPerRow = firstPlane.bytesPerRow;
            break;
          case ImageFormatGroup.nv21:
            format = InputImageFormat.nv21;
            // For NV21, usually just the first plane or concatenated
            bytes = _concatenateAllPlanes(cameraImage.planes);
            bytesPerRow = firstPlane.bytesPerRow;
            break;
          default:
          // Fallback to NV21
            format = InputImageFormat.nv21;
            bytes = firstPlane.bytes;
            bytesPerRow = firstPlane.bytesPerRow;
        }
      } else {
        // iOS
        format = InputImageFormat.bgra8888;
        bytes = firstPlane.bytes;
        bytesPerRow = firstPlane.bytesPerRow;
      }

      debugPrint('Processing image: ${cameraImage.width}x${cameraImage.height}, '
          'format: $format, rotation: $rotation, bytesPerRow: $bytesPerRow, '
          'dataSize: ${bytes.length}');

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('Error building InputImage: $e');
      return null;
    }
  }

  Uint8List _concatenateYuv420Planes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();

    // YUV420 has three planes: Y, U, V
    for (int i = 0; i < planes.length; i++) {
      allBytes.putUint8List(planes[i].bytes);
    }

    return allBytes.done().buffer.asUint8List();
  }

  Uint8List _concatenateAllPlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();

    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return allBytes.done().buffer.asUint8List();
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    if (Platform.isAndroid) {
      // For Android, we might need to adjust rotation based on device orientation
      // For now, let's try with no rotation to see if that fixes the issue
      return InputImageRotation.rotation0deg;
    } else {
      return InputImageRotation.rotation0deg;
    }
  }

  void _restartImageStream() {
    try {
      stopScanning();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (isInitialized.value && !isStreamActive.value) {
          startImageStream();
        }
      });
    } catch (e) {
      debugPrint('Error restarting image stream: $e');
    }
  }

  // Clear processed barcode after 3 seconds to allow re-scanning
  void _clearProcessedBarcode(String barcodeText) {
    Future.delayed(const Duration(seconds: 3), () {
      _processedBarcodes.remove(barcodeText);
    });
  }

  String _getBarcodeContent(Barcode barcode) {
    // Try different ways to get barcode content
    String content = '';

    // First try raw value
    if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
      content = barcode.rawValue!;
    }
    // Then try display value
    else if (barcode.displayValue != null && barcode.displayValue!.isNotEmpty) {
      content = barcode.displayValue!;
    }
    // Finally, convert raw bytes to hex if available
    else if (barcode.rawBytes != null && barcode.rawBytes!.isNotEmpty) {
      content = barcode.rawBytes!.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    }
    // Fallback
    else {
      content = 'لا يوجد محتوى مقروء';
    }

    return content;
  }

  String _truncateBarcodeContent(String content) {
    if (content.length <= 100) {
      return content;
    }

    // Split content into lines
    List<String> lines = content.split('\n');

    if (lines.length <= 3) {
      // If 3 lines or less, just truncate the content
      return content.length > 100 ? '${content.substring(0, 100)}...' : content;
    } else {
      // Take first 3 lines and add ellipsis
      return '${lines.take(3).join('\n')}\n...';
    }
  }

  bool _isValidNationalID(String content) {
    // Convert content to bits (assuming ASCII encoding)
    int contentSizeInBits = content.length * 8;

    // Check if content size is between 6000 and 10000 bits
    return contentSizeInBits >= 6000 && contentSizeInBits <= 10000;
  }

  Future<void> _playSuccessSound() async {
    try {
      // Play a simple beep sound using system audio
      await _audioPlayer?.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint('LiveBarcodeScanner - Could not play sound: $e');
      // Fallback: just print to console
      debugPrint('LiveBarcodeScanner - 🔊 BEEP! Barcode detected!');
    }
  }

  Future<void> _submitBarcodeData(Barcode barcode, String barcodeContent) async {
    // Validate if this is a valid national ID
    if (!_isValidNationalID(barcodeContent)) {
      int contentSizeInBits = barcodeContent.length * 8;
      statusMessage.value = '❌ هذا ليس هوية وطنية صحيحة!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}\n📏 الحجم: $contentSizeInBits بت\n⚠️ يجب أن يكون الحجم بين 6000-10000 بت';

      Get.snackbar(
        'خطأ',
        'هذا ليس هوية وطنية صحيحة. يجب أن يكون الحجم بين 6000-10000 بت',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      // Reset status after a delay
      Future.delayed(const Duration(seconds: 4), () {
        statusMessage.value = '🔍 المسح المباشر نشط!\n\n📱 وجه الكاميرا نحو الباركود\n🔊 سيتم تشغيل الصوت عند الاكتشاف';
      });
      return;
    }

    try {
      final FirebaseService firebaseService = Get.find<FirebaseService>();
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final barcodeSize = barcode.rawBytes?.length ?? 0;
      final barcodeHash = sha256.convert(utf8.encode(barcodeContent)).toString();
      final docRef = firestore.collection('nationalIDs').doc(barcodeHash);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final prevCollector = docSnapshot.data()?['collectorName'] ?? 'مستخدم آخر';
        statusMessage.value = '⚠️ تحذير: هذا الباركود تم مسحه مسبقاً بواسطة $prevCollector\n\n📄 المحتوى: $barcodeContent';

        Get.snackbar(
          'تحذير',
          'هذا الباركود تم مسحه مسبقاً بواسطة $prevCollector',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        await docRef.set({
          'barcodeContent': barcodeContent,
          'barcodeSize': barcodeSize,
          'barcodeHash': barcodeHash,
          'collectorId': collectorId,
          'collectorName': collectorName,
          'area': selectedArea,
          'collectorAssignedArea': selectedArea,
          'barcodeFormat': barcode.format.toString(),
          'barcodeType': barcode.type.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        await firebaseService.updateCollectorPerformance(
          collectorId: collectorId,
          area: selectedArea,
          votesCollected: 1,
        );

        scannedCount.value++;
        statusMessage.value = '✅ تم رفع البيانات بنجاح!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}\n📊 إجمالي المسح: ${scannedCount.value}';

        Get.snackbar(
          'نجح',
          'تم رفع بيانات الباركود بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );

        // Reset status after a short delay
        Future.delayed(const Duration(seconds: 3), () {
          statusMessage.value = '🔍 المسح المباشر نشط!\n\n📱 وجه الكاميرا نحو الباركود\n🔊 سيتم تشغيل الصوت عند الاكتشاف';
        });
      }
    } catch (e) {
      statusMessage.value = '❌ فشل في رفع البيانات: $e\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}';

      Get.snackbar(
        'خطأ',
        'فشل في رفع بيانات الباركود: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void stopScanning() {
    isStreamActive.value = false;
    _cameraController?.stopImageStream().catchError((error) {
      debugPrint('Error stopping image stream: $error');
    });
  }

  CameraController? get cameraController => _cameraController;

  @override
  void onClose() {
    stopScanning();
    _audioPlayer?.dispose();
    _cameraController?.dispose();
    _barcodeScanner.close();
    super.onClose();
  }
}