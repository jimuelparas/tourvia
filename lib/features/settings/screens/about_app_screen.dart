import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// About the Application screen (US-22).
/// Displays Tourvia's purpose, features, and scope in a rich layout.
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: const BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.explore_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tourvia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const Text(
                        'Version 1.0.0',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  'About Tourvia',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tourvia is a Mobile-Based Tour Management & Assistance system '
                  'designed for Tourists and Tourist Guides in the Philippines. '
                  'It streamlines the tour experience by providing real-time '
                  'communication, tracking, and itinerary management tools.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'KEY FEATURES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHint,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFeature(
                  Icons.location_on_rounded,
                  'Real-Time Tracking',
                  'Monitor tourist locations with boundary alerts and live map view.',
                  AppColors.primary,
                ),
                _buildFeature(
                  Icons.chat_bubble_rounded,
                  'Group Communication',
                  'Dedicated group chat for tour guides and tourists with media sharing.',
                  AppColors.accent,
                ),
                _buildFeature(
                  Icons.map_rounded,
                  'Itinerary Management',
                  'Create, edit, and share tour itineraries with per-stop attendance tracking.',
                  AppColors.accentTeal,
                ),
                _buildFeature(
                  Icons.emergency_rounded,
                  'SOS Emergency Alerts',
                  'One-tap emergency alerts with real-time location sharing.',
                  AppColors.error,
                ),
                _buildFeature(
                  Icons.wb_sunny_rounded,
                  'Weather Updates',
                  'Real-time weather data and forecasts for tour destinations.',
                  AppColors.success,
                ),
                _buildFeature(
                  Icons.smart_toy_rounded,
                  'AI Chatbot Assistant',
                  'Ask questions about Philippine tourist destinations and get instant answers.',
                  AppColors.primary,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.school_rounded,
                          color: AppColors.primary, size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        'Academic Project',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This application was developed as part of an academic '
                        'capstone project focused on improving tourism experiences '
                        'in the Philippines.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeature(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
          const SizedBox(width: 16),
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
                  style: TextStyle(
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
