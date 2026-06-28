import 'package:flutter/material.dart';

import 'tour_guide_home_screen.dart';

/// The main dashboard for the Tour Guide role.
/// 
/// Refactored to remove bottom navigation as per user request.
/// The Home screen now serves as the central hub for all modules.
class TourGuideDashboardScreen extends StatelessWidget {
  const TourGuideDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TourGuideHomeScreen();
  }
}
