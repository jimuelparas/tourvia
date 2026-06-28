import 'package:flutter/material.dart';

import 'tourist_home_screen.dart';

/// The main dashboard for the Tourist role.
/// 
/// Refactored to remove bottom navigation as per user request.
/// The Home screen now serves as the central hub for all modules.
class TouristDashboardScreen extends StatelessWidget {
  const TouristDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TouristHomeScreen();
  }
}
