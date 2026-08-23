import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/sos_service.dart';

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
  StreamSubscription<List<SosAlert>>? _sosSubscription;
  List<SosAlert> _activeAlerts = [];

  @override
  void initState() {
    super.initState();
    // Try immediately; also retry after first frame in case
    // TouristSessionManager hasn't loaded the session yet at startup.
    _setupSosSubscription();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSosSubscription();
    });
  }

  // Sets up the Firestore SOS subscription if the session is available
  // and the subscription hasn't been created yet.
  void _setupSosSubscription() {
    if (_sosSubscription != null) return; // already running
    final sessionId = TouristSessionManager.current?.sessionId ?? '';
    if (sessionId.isEmpty) return;

    _sosSubscription = SosService.watchActiveAlerts(sessionId).listen((alerts) {
      if (!mounted) return;
      setState(() => _activeAlerts = alerts);

      if (alerts.isNotEmpty) {
        LocationService.startEmergencyRing();
      } else {
        LocationService.stopEmergencyRing();
      }
    });
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    LocationService.stopEmergencyRing();
    super.dispose();
  }

  Widget _buildSosAlertBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SosScreen(
            sessionId: TouristSessionManager.current?.sessionId ?? '',
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 Emergency from Guide!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'The tour guide needs immediate assistance! Tap to view details.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              if (_activeAlerts.isNotEmpty) ...[
                _buildSosAlertBanner(),
                const SizedBox(height: 16),
              ],
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
          child: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
            child: const Icon(Icons.settings_rounded, color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionCard() {
    final sessionId = TouristSessionManager.current?.sessionId ?? '';

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
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                      GestureDetector(
                        onTap: session.guideId != null
                            ? () => _showGuideProfile(session.guideId!, session.guideName!)
                            : null,
                        child: Row(
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
                            if (session.guideId != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                            ],
                          ],
                        ),
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

  void _showGuideProfile(String guideId, String guideName) async {
    // Show loading bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: AuthService.getGuideProfile(guideId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final profile = snapshot.data;
              if (profile == null) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Could not load guide profile.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              // Build name from available fields
              final firstName = profile['firstName'] as String? ?? '';
              final middleName = profile['middleName'] as String? ?? '';
              final lastName = profile['lastName'] as String? ?? '';
              final fullName = profile['fullName'] as String? ?? guideName;
              final displayName = firstName.isNotEmpty
                  ? [firstName, if (middleName.isNotEmpty) middleName, lastName]
                      .join(' ')
                  : fullName;

              final username = profile['username'] as String? ?? '';
              final email = profile['email'] as String? ?? '';
              final phone = profile['contactNumber'] as String? ?? '';
              final address = profile['address'] as String? ?? '';
              final age = profile['age'];
              final tourGuideId = profile['tourGuideId'] as String? ?? '';
              final profilePhotoUrl = profile['profilePhotoUrl'] as String? ?? '';
              final idPhotoUrl = profile['idPhotoUrl'] as String? ?? '';

              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Avatar
                      Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primarySurface,
                            backgroundImage: profilePhotoUrl.isNotEmpty
                                ? NetworkImage(profilePhotoUrl)
                                : null,
                            child: profilePhotoUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name
                      Center(
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Username & Badge
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (username.isNotEmpty) ...[
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppColors.textHint)),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: (idPhotoUrl.isNotEmpty
                                        ? AppColors.success
                                        : const Color(0xFF0288D1))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (idPhotoUrl.isNotEmpty
                                          ? AppColors.success
                                          : const Color(0xFF0288D1))
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    idPhotoUrl.isNotEmpty
                                        ? Icons.verified_rounded
                                        : Icons.explore_rounded,
                                    size: 14,
                                    color: idPhotoUrl.isNotEmpty
                                        ? AppColors.success
                                        : const Color(0xFF0288D1),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    idPhotoUrl.isNotEmpty
                                        ? 'Verified Tour Guide'
                                        : 'Local Tour Guide',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: idPhotoUrl.isNotEmpty
                                          ? AppColors.success
                                          : const Color(0xFF0288D1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Guide Information section
                      const Text(
                        'GUIDE INFORMATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHint,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (username.isNotEmpty)
                        _buildGuideInfoRow(Icons.alternate_email_rounded, 'Username', username),
                      if (email.isNotEmpty)
                        _buildGuideInfoRow(Icons.email_outlined, 'Email Address', email),
                      if (phone.isNotEmpty)
                        _buildGuideInfoRow(Icons.phone_outlined, 'Contact Number', phone),
                      if (address.isNotEmpty)
                        _buildGuideInfoRow(Icons.location_on_outlined, 'Address', address),
                      if (age != null)
                        _buildGuideInfoRow(Icons.cake_outlined, 'Age', '$age years old'),
                      if (tourGuideId.isNotEmpty)
                        _buildGuideInfoRow(Icons.badge_outlined, 'DOT Tour Guide ID', tourGuideId),

                      // Uploaded ID Photo preview
                      if (idPhotoUrl.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'DOT ACCREDITATION CARD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHint,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    idPhotoUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('Unable to load ID preview'),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    idPhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 40, color: AppColors.textHint),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Tap to view', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGuideInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.95,
      children: [
        _buildModuleCard(
          title: 'Tracking',
          subtitle: 'Live location',
          iconAsset: 'assets/icons/location.png',
          color: AppColors.accentTeal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TouristMapScreen()),
          ),
        ),
        _buildModuleCard(
          title: 'Group Chat',
          subtitle: 'Messages',
          iconAsset: 'assets/icons/groupchat.png',
          color: AppColors.accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupChatScreen(
                isCurrentUserGuide: false,
                sessionId: TouristSessionManager.current?.sessionId ?? '',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          title: 'Weather',
          subtitle: 'Current forecast',
          iconAsset: 'assets/icons/weather.png',
          color: AppColors.success,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()),
          ),
        ),
        _SosBlinkingModuleCard(
          isActive: _activeAlerts.isNotEmpty,
          title: 'SOS / Help',
          subtitle: 'Emergency logs',
          iconAsset: 'assets/icons/sos.png',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SosScreen(
                sessionId: TouristSessionManager.current?.sessionId ?? '',
              ),
            ),
          ),
        ),
        _buildModuleCard(
          title: 'AI Assistant',
          subtitle: 'Smart help',
          iconAsset: 'assets/icons/ai.png',
          color: AppColors.accentTeal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required String iconAsset,
    required Color color,
    required VoidCallback onTap,
  }) {
    const double containerSize = 56;
    const double iconSize = 32;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: containerSize,
                height: containerSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(iconAsset,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Self-contained SOS blinking card widget (Tourist dashboard).
// ─────────────────────────────────────────────────────────────────────────────
class _SosBlinkingModuleCard extends StatefulWidget {
  final bool isActive;
  final String title;
  final String subtitle;
  final String iconAsset;
  final VoidCallback onTap;

  const _SosBlinkingModuleCard({
    required this.isActive,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  State<_SosBlinkingModuleCard> createState() => _SosBlinkingModuleCardState();
}

class _SosBlinkingModuleCardState extends State<_SosBlinkingModuleCard> {
  Timer? _timer;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _startBlink();
  }

  @override
  void didUpdateWidget(_SosBlinkingModuleCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive == old.isActive) return;
    if (widget.isActive) {
      _startBlink();
    } else {
      _stopBlink();
    }
  }

  void _startBlink() {
    _timer?.cancel();
    setState(() => _lit = true);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _lit = !_lit);
    });
  }

  void _stopBlink() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _lit = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double containerSize = 56;
    const double iconSize = 32;

    return Material(
      color: _lit ? AppColors.error.withValues(alpha: 0.15) : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _lit ? AppColors.error : AppColors.border,
              width: _lit ? 3.0 : 1.0,
            ),
            boxShadow: _lit
                ? [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: containerSize,
                height: containerSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _lit
                        ? AppColors.error.withValues(alpha: 0.22)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Image.asset(widget.iconAsset,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _lit ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _lit ? '🚨 EMERGENCY' : widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _lit ? FontWeight.bold : FontWeight.normal,
                  color: _lit ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

