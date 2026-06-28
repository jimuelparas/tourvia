import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/attendance_service.dart';

/// Screen to display the live map for the Tour Guide (US-11 to US-15).
class TourGuideMapScreen extends StatefulWidget {
  const TourGuideMapScreen({super.key});

  @override
  State<TourGuideMapScreen> createState() => _TourGuideMapScreenState();
}

class _TourGuideMapScreenState extends State<TourGuideMapScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.mapTitle),
        backgroundColor: AppColors.surface,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: StreamBuilder<List<TouristRecord>>(
        stream: AttendanceService.watchRoster('demo-session-001'),
        builder: (context, snapshot) {
          final roster = snapshot.data ?? [];
          final markers = <Widget>[];

          // Guide Marker
          markers.add(
            _buildMarker(
              label: 'You',
              top: 250,
              left: 200,
              color: AppColors.primary,
              icon: Icons.my_location_rounded,
              isGuide: true,
            ),
          );

          bool hasMissingTourist = false;
          String missingTouristName = '';
          int outsideCount = 0;

          for (int i = 0; i < roster.length; i++) {
            final tourist = roster[i];
            // Simulate that the second tourist (or any named Jose Rizal) is out-of-bounds
            final isMissing = i == 1 || tourist.touristName.toLowerCase().contains('rizal');
            if (isMissing) {
              hasMissingTourist = true;
              missingTouristName = tourist.touristName;
              outsideCount++;
            }

            markers.add(
              _buildMarker(
                label: tourist.touristName,
                top: isMissing ? 340 : (120 + (i * 70) % 200).toDouble(),
                left: isMissing ? 60 : (100 + (i * 90) % 180).toDouble(),
                color: isMissing ? AppColors.error : AppColors.success,
                icon: isMissing ? Icons.warning_rounded : Icons.person_pin_circle_rounded,
              ),
            );
          }

          final safeCount = roster.length - outsideCount;

          return Stack(
            children: [
              // Simulated Map Background
              _buildSimulatedMap(),

              ...markers,

              // Simulated Boundary Outline (US-11)
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

              // Bottom Panel for Missing Tourist Alert
              if (hasMissingTourist)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildAlertPanel(missingTouristName),
                ),

              // Safe vs Outside Counter Bar
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: _buildStatusIndicators(safeCount, outsideCount),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusIndicators(int safeCount, int outsideCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem('Safe', safeCount.toString(), AppColors.success),
          Container(width: 1, height: 30, color: AppColors.border),
          _buildStatusItem('Outside', outsideCount.toString(), AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Text(
          count,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color),
        ),
      ],
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
    bool isGuide = false,
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
                fontWeight: isGuide ? FontWeight.w800 : FontWeight.w600,
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

  Widget _buildAlertPanel(String touristName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.missingAlert,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$touristName has exited the 1 km boundary.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Information Details (US-13)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip('Distance', '1.2 km'),
              _buildInfoChip('Last Seen', '2 mins ago'),
            ],
          ),
          const SizedBox(height: 16),
          // Actions (US-14, US-15)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ringing $touristName\'s phone...')),
                    );
                  },
                  icon: const Icon(Icons.ring_volume_rounded, size: 18),
                  label: const Text(AppStrings.ringPhone),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Routing to $touristName\'s location...')),
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(AppStrings.navigateToTourist),
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
          const SizedBox(height: 8), // For safe area
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
