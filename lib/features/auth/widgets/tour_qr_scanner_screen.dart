import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

/// Full-screen camera scanner for tourists to scan the Tour Guide's QR code.
///
/// Features:
/// - Camera permission detection with user-friendly fallback messaging
/// - Viewfinder frame with scanning animation
/// - Torch toggle and camera switch controls
/// - Seamless fallback to manual access code entry
class TourQrScannerScreen extends StatefulWidget {
  const TourQrScannerScreen({super.key});

  /// Opens the scanner screen and returns the scanned raw string,
  /// or null if dismissed without scanning.
  static Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const TourQrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<TourQrScannerScreen> createState() => _TourQrScannerScreenState();
}

class _TourQrScannerScreenState extends State<TourQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _hasDetected = false;
  MobileScannerException? _scannerError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _hasDetected = true;
        _controller.stop();
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Feed ───────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _scannerError != error) {
                  setState(() => _scannerError = error);
                }
              });
              return _buildErrorState(error);
            },
          ),

          // ── Viewfinder Overlay (when camera is running) ───
          if (_scannerError == null) ...[
            _buildDarkVignette(),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildScanTargetBox(),
                  const Spacer(),
                  _buildBottomInstructions(),
                ],
              ),
            ),
          ] else ...[
            // When error (e.g. permission denied), top bar stays visible
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Scan Tour QR Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) {
                    final isTorchOn = state.torchState == TorchState.on;
                    return Icon(
                      isTorchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: isTorchOn ? Colors.amber : Colors.white70,
                    );
                  },
                ),
                onPressed: () => _controller.toggleTorch(),
              ),
              IconButton(
                icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
                onPressed: () => _controller.switchCamera(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanTargetBox() {
    final size = min(MediaQuery.of(context).size.width * 0.72, 280.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
        ),

        // Corner accents
        _buildCornerCorners(size),

        // Animated laser scan line
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final yOffset = (_animController.value * (size - 30)) - ((size - 30) / 2);
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Container(
                width: size - 32,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.0),
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCornerCorners(double size) {
    const cornerLength = 24.0;
    const cornerWidth = 3.5;
    const color = AppColors.primary;
    const radius = 24.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Top-left
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerLength,
              height: cornerLength,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: color, width: cornerWidth),
                  left: BorderSide(color: color, width: cornerWidth),
                ),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(radius)),
              ),
            ),
          ),
          // Top-right
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerLength,
              height: cornerLength,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: color, width: cornerWidth),
                  right: BorderSide(color: color, width: cornerWidth),
                ),
                borderRadius: BorderRadius.only(topRight: Radius.circular(radius)),
              ),
            ),
          ),
          // Bottom-left
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerLength,
              height: cornerLength,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: color, width: cornerWidth),
                  left: BorderSide(color: color, width: cornerWidth),
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(radius)),
              ),
            ),
          ),
          // Bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerLength,
              height: cornerLength,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: color, width: cornerWidth),
                  right: BorderSide(color: color, width: cornerWidth),
                ),
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(radius)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInstructions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Point camera at the Tour Guide\'s QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white70, size: 18),
            label: const Text(
              'Enter Access Code Manually',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkVignette() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildErrorState(MobileScannerException error) {
    final isPermission = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isPermission ? 'Camera Permission Required' : 'Camera Unavailable',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isPermission
                    ? 'Camera access is required to scan the Tour QR code. Please enable camera permission in your device settings, or enter the Access Code manually.'
                    : 'Unable to start camera scanner (${error.errorDetails?.message ?? error.errorCode.name}). You can still enter the Access Code manually.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'Enter Access Code Manually',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
