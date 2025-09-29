import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:async';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String selectedArea;
  final String collectorId;
  final String collectorName;

  const BarcodeScannerScreen({
    super.key, 
    required this.selectedArea,
    required this.collectorId,
    required this.collectorName,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late final BarcodeScanner _barcodeScanner;
  AudioPlayer? _audioPlayer;
  String _scannedBarcode = 'لم يتم مسح أي باركود بعد';
  bool _isScanning = false;
  bool _isLiveScanning = false;
  bool _isSubmitting = false;
  final List<Barcode> _scannedBarcodes = [];
  File? _selectedImage;
  String _lastScannedBarcode = '';

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      // Initialize barcode scanner
      _barcodeScanner = BarcodeScanner();
      debugPrint('BarcodeScanner - Barcode scanner initialized successfully');
      
      // Initialize audio player
      _audioPlayer = AudioPlayer();
      
      // Request camera permission
      var status = await Permission.camera.request();
      if (status.isDenied) {
        setState(() {
          _scannedBarcode = 'تم رفض إذن الكاميرا. يرجى السماح بالوصول إلى الكاميرا.';
        });
        return;
      }

      setState(() {
        _scannedBarcode = '✅ الماسح جاهز!\n\n📱 اضغط "مسح سريع" للبدء\n💡 تأكد من الإضاءة الجيدة والباركود الواضح';
      });
    } catch (e) {
      debugPrint('BarcodeScanner - Error initializing scanner: $e');
      setState(() {
        _scannedBarcode = 'خطأ في تهيئة الماسح: $e\n\nيرجى إعادة تشغيل التطبيق.';
      });
    }
  }

  Future<void> _scanFromCamera() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scannedBarcode = 'جاري فتح الكاميرا...';
    });

    try {
      // Take a photo using camera with higher quality settings
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 3840, // Higher resolution for better detection
        maxHeight: 2160,
        imageQuality: 100, // Maximum quality
        preferredCameraDevice: CameraDevice.rear, // Use back camera
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _scannedBarcode = 'جاري معالجة الصورة عالية الجودة للباركود...';
        });

        // Scan the captured image for barcodes
        await _scanImageForBarcodes(photo.path);
      } else {
        setState(() {
          _scannedBarcode = 'لم يتم التقاط صورة';
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _scannedBarcode = 'خطأ في التقاط الصورة: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _scanFromGallery() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scannedBarcode = 'جاري فتح المعرض...';
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 3840,
        maxHeight: 2160,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _scannedBarcode = 'جاري معالجة الصورة من المعرض للباركود...';
        });

        await _scanImageForBarcodes(image.path);
      } else {
        setState(() {
          _scannedBarcode = 'لم يتم اختيار صورة';
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _scannedBarcode = 'خطأ في اختيار الصورة: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _scanImageForBarcodes(String imagePath) async {
    try {
      final List<Barcode> barcodes = await _barcodeScanner.processImage(
        InputImage.fromFilePath(imagePath)
      );

      if (barcodes.isNotEmpty) {
        for (final barcode in barcodes) {
          String barcodeText = _getBarcodeContent(barcode);
          
          debugPrint('BarcodeScanner - 🎯 Barcode detected: ${barcode.format} - $barcodeText');
          debugPrint('BarcodeScanner - Barcode raw bytes: ${barcode.rawBytes?.length ?? 0} bytes');
          debugPrint('BarcodeScanner - Barcode display value: ${barcode.displayValue}');
          debugPrint('BarcodeScanner - Barcode raw value: ${barcode.rawValue}');
          
          // Play success sound
          await _playSuccessSound();
          
          setState(() {
            _scannedBarcode = '🎯 تم اكتشاف باركود!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeText)}\n🏷️ النوع: ${barcode.format}\n📊 الفئة: ${barcode.type}\n📏 الحجم: ${barcode.rawBytes?.length ?? 0} بايت\n\n⏳ جاري رفع البيانات تلقائياً...';
            _scannedBarcodes.add(barcode);
          });

          // Automatically upload the barcode data
          await _submitBarcodeData();
        }
      } else {
        setState(() {
          _scannedBarcode = '❌ لم يتم العثور على باركود في الصورة\n\n💡 تأكد من أن الباركود واضح ومضاء جيداً';
        });
      }
    } catch (e) {
      debugPrint('BarcodeScanner - Error scanning image: $e');
      setState(() {
        _scannedBarcode = 'خطأ في مسح الصورة: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _startLiveScanner() async {
    setState(() {
      _isLiveScanning = true;
      _scannedBarcode = '🔍 المسح المباشر نشط!\n\n📱 اضغط "مسح سريع" لالتقاط صورة\n🔊 سيتم تشغيل الصوت عند الاكتشاف\n💡 تأكد من الإضاءة الجيدة والباركود الواضح';
    });
  }

  Future<void> _stopLiveScanner() async {
    setState(() {
      _isLiveScanning = false;
      _scannedBarcode = 'تم إيقاف المسح المباشر.';
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
      debugPrint('BarcodeScanner - Could not play sound: $e');
      // Fallback: just print to console
      debugPrint('BarcodeScanner - 🔊 BEEP! Barcode detected!');
    }
  }

  Future<void> _submitBarcodeData() async {
    if (_scannedBarcodes.isEmpty) {
      Get.snackbar(
        'خطأ',
        'لا يوجد باركود لرفعه',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final FirebaseService firebaseService = Get.find<FirebaseService>();
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final barcode = _scannedBarcodes.last;
      final barcodeContent = _getBarcodeContent(barcode);
      
      // Validate if this is a valid national ID
      if (!_isValidNationalID(barcodeContent)) {
        int contentSizeInBits = barcodeContent.length * 8;
        setState(() {
          _scannedBarcode = '❌ هذا ليس هوية وطنية صحيحة!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}\n📏 الحجم: $contentSizeInBits بت\n⚠️ يجب أن يكون الحجم بين 6000-10000 بت';
        });
        Get.snackbar(
          'خطأ',
          'هذا ليس هوية وطنية صحيحة. يجب أن يكون الحجم بين 6000-10000 بت',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }
      
      final barcodeSize = barcode.rawBytes?.length ?? 0;
      final barcodeHash = sha256.convert(utf8.encode(barcodeContent)).toString();
      final docRef = firestore.collection('nationalIDs').doc(barcodeHash);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final prevCollector = docSnapshot.data()?['collectorName'] ?? 'مستخدم آخر';
        setState(() {
          _scannedBarcode = '⚠️ تحذير: هذا الباركود تم مسحه مسبقاً بواسطة $prevCollector\n\n';
        });
        Get.snackbar(
          'تحذير',
          'هذا الباركود تم مسحه مسبقاً بواسطة $prevCollector',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      } else {
        await docRef.set({
          'barcodeContent': barcodeContent,
          'barcodeSize': barcodeSize,
          'barcodeHash': barcodeHash,
          'collectorId': widget.collectorId,
          'collectorName': widget.collectorName,
          'area': widget.selectedArea,
          'collectorAssignedArea': widget.selectedArea, // Add collector's assigned area
          'barcodeFormat': barcode.format.toString(),
          'barcodeType': barcode.type.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        await firebaseService.updateCollectorPerformance(
          collectorId: widget.collectorId,
          area: widget.selectedArea,
          votesCollected: 1,
        );
        setState(() {
          _scannedBarcode = '✅ تم رفع البيانات بنجاح!\n\n📄 المحتوى: ${_truncateBarcodeContent(barcodeContent)}\n🏷️ النوع: ${barcode.format}\n📊 الفئة: ${barcode.type}\n⏰ تم الرفع تلقائياً';
        });
        Get.snackbar(
          'نجح',
          'تم رفع بيانات الباركود بنجاح',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        // Reset scanning info after successful upload
        setState(() {
          _scannedBarcodes.clear();
          _selectedImage = null;
        });
        
        // Reset to ready state after a short delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
          _scannedBarcode = '✅ الماسح جاهز!\n\n📱 اضغط "مسح سريع" للبدء\n💡 تأكد من الإضاءة الجيدة والباركود الواضح';
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _scannedBarcode = '❌ فشل في رفع البيانات: $e\n\n📄 المحتوى: ${_truncateBarcodeContent(_getBarcodeContent(_scannedBarcodes.last))}';
      });
      Get.snackbar(
        'خطأ',
        'فشل في رفع بيانات الباركود: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.17 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          // Scrollable content with top margin
          Positioned.fill(
            top: headerHeight,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: screenHeight * 0.025),
                    // Camera Preview Container
                    Container(
                      width: double.infinity,
                      height: screenHeight * 0.35,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.black87,
                      ),
                      child: _isLiveScanning
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Container(
                                color: Colors.black,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        color: Colors.white54,
                                        size: 48,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'المسح المباشر نشط',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'اضغط "مسح سريع" لالتقاط صورة',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.green, width: 3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.check_circle, size: 48, color: Colors.green),
                                              SizedBox(height: screenHeight * 0.01),
                                              Text(
                                                'تم التقاط الصورة',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, size: 64, color: Colors.white54),
                                      SizedBox(height: screenHeight * 0.02),
                                      Text(
                                        'الماسح جاهز',
                                        style: TextStyle(fontSize: 18, color: Colors.white54),
                                      ),
                                      SizedBox(height: screenHeight * 0.01),
                                      Text(
                                        'اضغط "مسح سريع"',
                                        style: TextStyle(fontSize: 14, color: Colors.blue),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scanFromCamera,
                            icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.photo_camera),
                            label: Text(_isScanning ? 'جاري المسح...' : 'مسح سريع', style: TextStyle(fontSize: screenWidth * 0.04)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.018),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue, size: screenWidth * 0.05),
                              SizedBox(width: screenWidth * 0.02),
                              Text(
                                'معلومات المسح',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          Text(
                            _scannedBarcode,
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ),
            ),
          ),
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromRGBO(225, 34, 34, 1),
                    const Color.fromRGBO(225, 34, 34, 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              'ماسح الباركود',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: screenWidth * 0.055,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.12),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        '${widget.collectorName} - ${widget.selectedArea}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 