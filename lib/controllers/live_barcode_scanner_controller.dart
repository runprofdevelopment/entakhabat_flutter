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
import 'dart:async';

class LiveBarcodeScannerController extends GetxController {
  // Dependencies
  late final BarcodeScanner _barcodeScanner;
  AudioPlayer? _audioPlayer;
  CameraController? _cameraController;

  // Observable state
  final RxBool isInitialized = false.obs;
  final RxBool isProcessing = false.obs;
  final RxBool isCaptureActive = false.obs;
  final RxInt scannedCount = 0.obs;
  final RxString statusMessage = 'جاري تهيئة الكاميرا...'.obs;
  final RxString captureStatus = ''.obs;

  // Private state
  final Set<String> _processedBarcodes = {};
  Timer? _captureTimer;
  Timer? _processingTimer;

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
      // Initialize barcode scanner with common formats
      _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.pdf417]);

      // Initialize audio player
      _audioPlayer = AudioPlayer();

      // Request camera permission
      var status = await Permission.camera.request();
      if (status.isDenied) {
        statusMessage.value =
            'تم رفض إذن الكاميرا. يرجى السماح بالوصول إلى الكاميرا.';
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

      // Use high resolution; prefer YUV420 for ML Kit
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      isInitialized.value = true;
      statusMessage.value =
          '🔍 المسح المباشر نشط!\n\n📱 وجه الكاميرا نحو الباركود';

      // Start live image stream for real-time scanning
      await _startLiveStream();
    } catch (e) {
      debugPrint('LiveBarcodeScanner - Error initializing: $e');
      statusMessage.value =
          'خطأ في تهيئة الماسح: $e\n\nيرجى إعادة تشغيل التطبيق.';
    }
  }

  // Live stream starter (replaces periodic capture)
  Future<void> _startLiveStream() async {
    if (!isInitialized.value || _cameraController == null) return;
    if (isCaptureActive.value) return;
    isCaptureActive.value = true;
    captureStatus.value = '⚡ معالجة مباشرة';

    // Try to improve detection conditions: autofocus, auto-exposure, torch off by default
    try {
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);
      await _cameraController!.setZoomLevel(1.0);
      // Center focus point (normalized coordinates 0..1)
      await _cameraController!.setFocusPoint(const Offset(0.5, 0.5));
    } catch (_) {}

    await _cameraController!.startImageStream((CameraImage image) async {
      if (isProcessing.value) return;
      isProcessing.value = true;
      try {
        // Crop to a centered ROI to increase PDF417 size and contrast
        final roi = _cropCenterRoi(image, widthFactor: 0.8, heightFactor: 0.5);
        final input = _buildInputImageFromCameraImage(roi);
        if (input == null) {
          isProcessing.value = false;
          return;
        }
        final barcodes = await _barcodeScanner.processImage(input);
        if (barcodes.isNotEmpty) {
          for (final barcode in barcodes) {
            final content = _getBarcodeContent(barcode);
            if (_processedBarcodes.contains(content)) continue;
            _processedBarcodes.add(content);
            _clearProcessedBarcode(content);
            await _playSuccessSound();
            captureStatus.value = '🎯 تم الاكتشاف';
            statusMessage.value =
                '🎯 تم اكتشاف باركود!\n\n${_truncateBarcodeContent(content)}';
            await _submitBarcodeData(barcode, content);
            break;
          }
        }
      } catch (e) {
        debugPrint('LiveBarcodeScanner - stream error: $e');
      } finally {
        // throttle ~6-7 fps
        Future.delayed(const Duration(milliseconds: 150), () {
          isProcessing.value = false;
        });
      }
    });
  }

  // Build a center crop ROI CameraImage-like structure (YUV420 only)
  CameraImage _cropCenterRoi(
    CameraImage image, {
    double widthFactor = 0.8,
    double heightFactor = 0.5,
  }) {
    if (image.format.group != ImageFormatGroup.yuv420) return image;
    final int width = image.width;
    final int height = image.height;
    final int roiW = (width * widthFactor).toInt();
    final int roiH = (height * heightFactor).toInt();
    final int x0 = ((width - roiW) / 2).toInt();
    final int y0 = ((height - roiH) / 2).toInt();

    // For efficiency, we won’t actually crop planes; we’ll pass full frame and rely on ML Kit.
    // If strict crop is needed, implement plane crop (heavy). For now, return original image.
    return image;
  }

  // Removed file-based capture path

  // Removed timeout-based file processing path

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
      final rotation = _computeImageRotation(camera.sensorOrientation);

      // Build bytes/metadata in a way ML Kit accepts
      InputImageFormat format;
      Uint8List bytes;
      int bytesPerRow;

      if (Platform.isAndroid) {
        // Prefer NV21 for ML Kit on Android
        final group = cameraImage.format.group;
        if (group == ImageFormatGroup.yuv420) {
          format = InputImageFormat.nv21;
          bytes = _yuv420ToNv21(cameraImage);
          bytesPerRow =
              cameraImage.width; // NV21 row stride set to width for ML Kit
        } else if (group == ImageFormatGroup.nv21) {
          format = InputImageFormat.nv21;
          // If already NV21, pack planes to a single bufferR
          bytes = _packNv21Planes(cameraImage);
          bytesPerRow = cameraImage.width;
        } else {
          // Fallback: treat as NV21 using first plane
          format = InputImageFormat.nv21;
          bytes = firstPlane.bytes;
          bytesPerRow = cameraImage.width;
        }
      } else {
        // iOS
        format = InputImageFormat.bgra8888;
        bytes = firstPlane.bytes;
        bytesPerRow = firstPlane.bytesPerRow;
      }

      debugPrint(
        'Processing image: ${cameraImage.width}x${cameraImage.height}, '
        'format: $format, rotation: $rotation, bytesPerRow: $bytesPerRow, '
        'dataSize: ${bytes.length}',
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            cameraImage.width.toDouble(),
            cameraImage.height.toDouble(),
          ),
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

  // Convert YUV_420_888 to NV21 (Y + interleaved VU) honoring strides
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    // NV21 size: width*height (Y) + width*height/2 (VU)
    final Uint8List out = Uint8List(width * height + (width * height ~/ 2));

    // Copy Y taking row stride into account
    int outIndex = 0;
    for (int row = 0; row < height; row++) {
      final int yRowStart = row * yPlane.bytesPerRow;
      out.setRange(
        outIndex,
        outIndex + width,
        yPlane.bytes.sublist(yRowStart, yRowStart + width),
      );
      outIndex += width;
    }

    // Interleave V then U at quarter resolution respecting pixelStride/rowStride
    final int uvWidth = width >> 1;
    final int uvHeight = height >> 1;
    int uvOutIndex = width * height;
    final int uPixelStride = (uPlane.bytesPerPixel ?? 2);
    final int vPixelStride = (vPlane.bytesPerPixel ?? 2);
    for (int row = 0; row < uvHeight; row++) {
      final int uRowStart = row * uPlane.bytesPerRow;
      final int vRowStart = row * vPlane.bytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;
        // NV21 expects V then U
        out[uvOutIndex++] = vPlane.bytes[vIndex];
        out[uvOutIndex++] = uPlane.bytes[uIndex];
      }
    }

    return out;
  }

  // Pack NV21 planes to contiguous buffer if provided as multiple planes
  Uint8List _packNv21Planes(CameraImage image) {
    if (image.planes.length == 1) return image.planes[0].bytes;
    final int width = image.width;
    final int height = image.height;
    final Plane y = image.planes[0];
    final Plane uv = image.planes.length > 1
        ? image.planes[1]
        : image.planes[0];
    final Uint8List out = Uint8List(width * height + (width * height ~/ 2));

    int outIndex = 0;
    for (int row = 0; row < height; row++) {
      final int yRowStart = row * y.bytesPerRow;
      out.setRange(
        outIndex,
        outIndex + width,
        y.bytes.sublist(yRowStart, yRowStart + width),
      );
      outIndex += width;
    }

    // Copy remaining UV bytes (best-effort)
    final int uvStart = outIndex;
    final int uvNeeded = out.length - uvStart;
    final Uint8List uvSrc = uv.bytes;
    final int copyLen = uvNeeded <= uvSrc.length ? uvNeeded : uvSrc.length;
    out.setRange(uvStart, uvStart + copyLen, uvSrc.sublist(0, copyLen));
    return out;
  }

  InputImageRotation _computeImageRotation(int sensorOrientation) {
    // Map sensor orientation (0/90/180/270) to InputImageRotation
    switch (sensorOrientation % 360) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void stopCapture() {
    isCaptureActive.value = false;
    _captureTimer?.cancel();
    _processingTimer?.cancel();
    captureStatus.value = '';
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
      content = barcode.rawBytes!
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join('');
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

  Future<void> _submitBarcodeData(
    Barcode barcode,
    String barcodeContent,
  ) async {
    // Validate if this is a valid national ID
    if (!_isValidNationalID(barcodeContent)) {
      int contentSizeInBits = barcodeContent.length * 8;
      statusMessage.value =
          '❌ هذا ليس هوية وطنية صحيحة!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}\n📏 الحجم: $contentSizeInBits بت\n⚠️ يجب أن يكون الحجم بين 6000-10000 بت';

      Get.snackbar(
        'خطأ',
        'هذا ليس هوية وطنية صحيحة. يجب أن يكون الحجم بين 6000-10000 بت',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      // Reset status after a delay
      Future.delayed(const Duration(seconds: 4), () {
        statusMessage.value =
            '🔍 المسح المباشر نشط!\n\n📱 وجه الكاميرا نحو الباركود\n📸 سيتم التقاط صورة كل 5 ثوان';
        captureStatus.value = '';
      });
      return;
    }

    try {
      final FirebaseService firebaseService = Get.find<FirebaseService>();
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final barcodeSize = barcode.rawBytes?.length ?? 0;
      final barcodeHash = sha256
          .convert(utf8.encode(barcodeContent))
          .toString();
      final docRef = firestore.collection('nationalIDs').doc(barcodeHash);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final prevCollector =
            docSnapshot.data()?['collectorName'] ?? 'مستخدم آخر';
        statusMessage.value =
            '⚠️ تحذير: هذا الباركود تم مسحه مسبقاً بواسطة $prevCollector\n';

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
        statusMessage.value =
            '✅ تم رفع البيانات بنجاح!\n}\n📊 إجمالي المسح: ${scannedCount.value}';

        Get.snackbar(
          'نجح',
          'تم رفع بيانات الباركود بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );

        // Reset status after a short delay
        Future.delayed(const Duration(seconds: 3), () {
          statusMessage.value =
              '🔍 المسح المباشر نشط!\n\n📱 وجه الكاميرا نحو الباركود\n📸 سيتم التقاط صورة كل 5 ثوان';
          captureStatus.value = '';
        });
      }
    } catch (e) {
      statusMessage.value =
          '❌ فشل في رفع البيانات: $e\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}';

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
    stopCapture();
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
