import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// References screen (US-24).
/// Displays sources and citations used in the project.
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('References'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.library_books_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sources & Citations',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Resources and technologies used in this project.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DATA SOURCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textHint,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildReferenceCard(
              icon: Icons.travel_explore_rounded,
              title: 'Department of Tourism Philippines',
              description: 'Official tourism data, destination information, '
                  'and tourist statistics for the Philippines.',
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'TECHNOLOGIES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textHint,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildReferenceCard(
              icon: Icons.map_rounded,
              title: 'Mapbox SDK',
              description: 'Maps, geolocation, and real-time GPS tracking '
                  'for tourist and guide location services.',
              color: AppColors.accentTeal,
            ),
            _buildReferenceCard(
              icon: Icons.place_rounded,
              title: 'Google Maps API',
              description: 'Places information, geocoding, and location-based '
                  'search functionality.',
              color: AppColors.success,
            ),
            _buildReferenceCard(
              icon: Icons.cloud_rounded,
              title: 'Firebase (Google)',
              description: 'Authentication, Firestore real-time database, '
                  'Cloud Functions, and push notifications.',
              color: AppColors.accent,
            ),
            _buildReferenceCard(
              icon: Icons.flutter_dash_rounded,
              title: 'Flutter Framework',
              description: 'Cross-platform mobile UI framework by Google '
                  'used for building the entire application.',
              color: AppColors.info,
            ),
            _buildReferenceCard(
              icon: Icons.smart_toy_rounded,
              title: 'OpenAI API',
              description: 'AI-powered chatbot for answering tourist queries '
                  'about Philippine destinations.',
              color: AppColors.primary,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
