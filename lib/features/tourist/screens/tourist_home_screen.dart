import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/models/tourist_session.dart';
import '../../../core/services/tour_session_service.dart';
import '../../../core/services/attendance_service.dart';
import '../../tracking/screens/tourist_map_screen.dart';
import 'tourist_itinerary_screen.dart';
import '../../chat/screens/group_chat_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../weather/screens/weather_screen.dart';
import '../../sos/screens/sos_screen.dart';
import '../../chatbot/screens/chatbot_screen.dart';

/// The central hub for the Tourist experience.
/// Features a grid of modules for easy access.
class TouristHomeScreen extends StatefulWidget {
  const TouristHomeScreen({super.key});

  @override
  State<TouristHomeScreen> createState() => _TouristHomeScreenState();
}

class _TouristHomeScreenState extends State<TouristHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildMainActionCard(),
              const SizedBox(height: 32),
              const Text(
                'Explore Tour',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final touristName = TouristSessionManager.current?.touristName ?? 'Traveler';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $touristName!',
              style: const TextStyle(color: AppColors.textHint, fontSize: 16),
            ),
            Text(
              'Your Adventure',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
            ),
          ],
        ),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          borderRadius: BorderRadius.circular(26),
          child: const CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accentLight,
            child: Icon(Icons.settings_rounded, color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionCard() {
    final sessionId = TouristSessionManager.current?.sessionId ?? 'demo-session-001';

    return StreamBuilder<TourSession>(
      stream: TourSessionService.watchSession(sessionId),
      builder: (context, sessionSnapshot) {
        final session = sessionSnapshot.data;
        final tourName = session?.tourName ?? 'Unnamed Tour';
        final dayStr = session != null
            ? 'Day ${session.currentDay} of ${session.totalDays}'
            : 'Day 1 of 3';

        return StreamBuilder<List<TouristRecord>>(
          stream: AttendanceService.watchRoster(sessionId),
          builder: (context, rosterSnapshot) {
            final touristCount = rosterSnapshot.data?.length ?? 0;
            final countStr =
                '$touristCount ${touristCount == 1 ? 'tourist' : 'tourists'}';

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TouristItineraryScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A9E0), Color(0xFF0077B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A9E0).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Tour',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tourName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$countStr • $dayStr',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (session?.guideName != null && session!.guideName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Guide: ${session.guideName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildModuleCard(
          'Tracking',
          Icons.location_on_rounded,
          const Color(0xFF6366F1),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TouristMapScreen()),
          ),
        ),
        _buildModuleCard(
          'Group Chat',
          Icons.chat_bubble_rounded,
          const Color(0xFFF59E0B),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupChatScreen(
                isCurrentUserGuide: false,
                sessionId: TouristSessionManager.current?.sessionId ?? 'demo-session-001',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          'Weather',
          Icons.wb_sunny_rounded,
          const Color(0xFF10B981),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()),
          ),
        ),
        _buildModuleCard(
          'SOS / Help',
          Icons.emergency_rounded,
          AppColors.error,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SosScreen(
                sessionId: TouristSessionManager.current?.sessionId ?? 'demo-session-001',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          'AI Assistant',
          Icons.smart_toy_rounded,
          const Color(0xFF8B5CF6),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
