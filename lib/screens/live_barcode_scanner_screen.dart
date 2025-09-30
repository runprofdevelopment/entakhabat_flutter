import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import '../controllers/live_barcode_scanner_controller.dart';

class LiveBarcodeScannerScreen extends StatefulWidget {
  final String selectedArea;
  final String collectorId;
  final String collectorName;

  const LiveBarcodeScannerScreen({
    super.key,
    required this.selectedArea,
    required this.collectorId,
    required this.collectorName,
  });

  @override
  State<LiveBarcodeScannerScreen> createState() =>
      _LiveBarcodeScannerScreenState();
}

class _LiveBarcodeScannerScreenState extends State<LiveBarcodeScannerScreen> {
  late final LiveBarcodeScannerController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(LiveBarcodeScannerController());
    controller.initialize(
      area: widget.selectedArea,
      collector: widget.collectorId,
      collectorNameParam: widget.collectorName,
    );
  }

  @override
  void dispose() {
    Get.delete<LiveBarcodeScannerController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight =
        screenHeight * 0.15 + MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(
        () => Stack(
          children: [
            // Camera Preview
            if (controller.isInitialized.value &&
                controller.cameraController != null)
              Positioned.fill(
                child: CameraPreview(controller.cameraController!),
              )
            else
              const SizedBox.shrink(),

            // Scanning Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
                child: Center(
                  child: Container(
                    width: screenWidth * 0.7,
                    height: screenWidth * 0.7,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        // _buildCornerIndicator(top: 0, left: 0),
                        // _buildCornerIndicator(top: 0, right: 0),
                        // _buildCornerIndicator(bottom: 0, left: 0),
                        // _buildCornerIndicator(bottom: 0, right: 0),

                        // Processing spinner overlay (only when processing)
                        Obx(
                          () => controller.isProcessing.value
                              ? Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Header
            _buildHeader(screenWidth, screenHeight, headerHeight),

            // Status Message
            _buildStatusMessage(screenWidth, screenHeight),

            // Capture Status
            _buildCaptureStatus(screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerIndicator({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top != null
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: bottom != null
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            left: left != null
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: right != null
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    double screenWidth,
    double screenHeight,
    double headerHeight,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: headerHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
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
                        'المسح المباشر',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${controller.scannedCount.value}',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
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
    );
  }

  Widget _buildStatusMessage(double screenWidth, double screenHeight) {
    return Positioned(
      bottom: screenHeight * 0.1,
      left: screenWidth * 0.04,
      right: screenWidth * 0.04,
      child: Obx(
        () => Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            controller.statusMessage.value,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureStatus(double screenWidth, double screenHeight) {
    return Positioned(
      top: screenHeight * 0.25,
      left: screenWidth * 0.04,
      right: screenWidth * 0.04,
      child: Obx(
        () => controller.captureStatus.value.isNotEmpty
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenWidth * 0.02,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  controller.captureStatus.value,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
