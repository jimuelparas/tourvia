import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/tourist_session.dart';

/// Screen to display the live map for the Tourist (US-16).
class TouristMapScreen extends StatefulWidget {
  const TouristMapScreen({super.key});

  @override
  State<TouristMapScreen> createState() => _TouristMapScreenState();
}

class _TouristMapScreenState extends State<TouristMapScreen> {
  // Simulating the boundary breach alert
  final bool _isOutOfBounds = true; // Set to true to show US-16

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Simulated Map Background
          _buildSimulatedMap(),

          // Guide Marker
          _buildMarker(
            label: 'Tour Guide',
            top: 250,
            left: 200,
            color: AppColors.primary,
            icon: Icons.flag_rounded,
          ),

          // Tourist Marker (Self)
          _buildMarker(
            label: TouristSessionManager.current?.touristName ?? 'You',
            top: _isOutOfBounds ? 100 : 260,
            left: _isOutOfBounds ? 60 : 180,
            color: _isOutOfBounds ? AppColors.error : AppColors.accent,
            icon: Icons.person_pin_circle_rounded,
          ),

          // Simulated Boundary Outline
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),

          // Warning UI if out of bounds (US-16)
          if (_isOutOfBounds)
            Positioned(top: 0, left: 0, right: 0, child: _buildBoundaryAlert()),

          // Route to Guide Action
          if (_isOutOfBounds)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.directions_rounded),
                label: const Text(AppStrings.routeToGuide),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimulatedMap() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE8F4F8), // Light water/map color
      child: CustomPaint(painter: _GridPainter()),
    );
  }

  Widget _buildMarker({
    required String label,
    required double top,
    required double left,
    required Color color,
    required IconData icon,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            icon,
            color: color,
            size: 36,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoundaryAlert() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        60,
        24,
        24,
      ), // Extra top padding for status bar
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.boundaryAlert,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.returnToBoundary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
