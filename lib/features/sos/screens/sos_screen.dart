import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/tourist_session.dart';
import '../../../core/services/sos_service.dart';
import '../../../core/services/location_service.dart';

/// Screen for SOS Emergency Alerts (US-18).
/// Features a pulsing SOS button, real GPS location, live alert log, and safety tips.
class SosScreen extends StatefulWidget {
  final String sessionId;

  const SosScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Get real GPS position ──────────────────────────────────
  Future<Position?> _getPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  // ── SOS confirmation dialog ────────────────────────────────
  void _triggerSos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Emergency SOS'),
          ],
        ),
        content: const Text(
          'This will send your real-time GPS location to your tour guide and all session members. '
          'Only use this in a genuine emergency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _doSendSos();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm SOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _doSendSos() async {
    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);

    // Get real GPS coords
    final pos = await _getPosition();
    final lat = pos?.latitude ?? 0.0;
    final lng = pos?.longitude ?? 0.0;

    final isTourist = TouristSessionManager.isLoggedIn;
    final senderId = isTourist
        ? (TouristSessionManager.current?.codeDocId ?? 'tourist')
        : (AuthService.currentUser?.uid ?? 'guide');
    final senderName = isTourist
        ? (TouristSessionManager.current?.touristName ?? 'Tourist')
        : (AuthService.currentUser?.displayName ?? 'Tour Guide');

    try {
      await SosService.sendAlert(
        sessionId: widget.sessionId,
        senderId: senderId,
        senderName: senderName,
        lat: lat,
        lng: lng,
      );

      if (mounted) {
        // Vibrate/ring to confirm SOS was sent
        LocationService.buzzDevice();
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SOS alert sent! Your guide has been notified.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to send SOS. Check your connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Open map at GPS coordinates ────────────────────────────
  Future<void> _openMap(SosAlert alert) async {
    // Try geo: URI first (opens native maps app)
    final geoUri = Uri.parse('geo:${alert.lat},${alert.lng}?q=${alert.lat},${alert.lng}');
    // Fallback: Google Maps web link
    final mapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${alert.lat},${alert.lng}');
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else {
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Final fallback — force external browser
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Resolve alert (guides only) ────────────────────────────
  Future<void> _resolveAlert(SosAlert alert) async {
    try {
      await SosService.resolveAlert(
        sessionId: widget.sessionId,
        alertId: alert.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Alert from ${alert.senderName} marked as resolved.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isGuide = !TouristSessionManager.isLoggedIn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('SOS / Emergency'),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // ── SOS Button ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Scale the button to fit smaller screens
                      final screenH = MediaQuery.of(context).size.height;
                      final outerSize = screenH < 700 ? 140.0 : 180.0;
                      final innerSize = screenH < 700 ? 108.0 : 140.0;
                      final fontSize  = screenH < 700 ? 34.0  : 42.0;
                      return GestureDetector(
                        onTap: _isSending ? null : _triggerSos,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                height: outerSize,
                                width: outerSize,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    height: innerSize,
                                    width: innerSize,
                                    decoration: BoxDecoration(
                                      color: _isSending
                                          ? AppColors.error.withValues(alpha: 0.5)
                                          : AppColors.error,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.error
                                              .withValues(alpha: 0.4),
                                          blurRadius: 30,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isSending
                                          ? const CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 3)
                                          : Text(
                                              'SOS',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: fontSize,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSending
                        ? 'Sending SOS with your GPS location…'
                        : 'Tap to send immediate alert',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),

            // ── Logs + Safety Tips ─────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textHint,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: 'SOS Logs'),
                          Tab(text: 'Safety Tips'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildLogsTab(isGuide: isGuide),
                            _buildSafetyTipsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SOS Logs tab ───────────────────────────────────────────
  Widget _buildLogsTab({required bool isGuide}) {
    return StreamBuilder<List<SosAlert>>(
      stream: SosService.watchAlerts(widget.sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded,
                    size: 48,
                    color: AppColors.success.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'No recent SOS alerts',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your safety log is clear',
                  style:
                      TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildAlertTile(log, isGuide: isGuide);
          },
        );
      },
    );
  }

  Widget _buildAlertTile(SosAlert log, {required bool isGuide}) {
    final hour = log.timestamp.hour % 12 == 0 ? 12 : log.timestamp.hour % 12;
    final min = log.timestamp.minute.toString().padLeft(2, '0');
    final ampm = log.timestamp.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$min $ampm';
    final resolved = log.isResolved;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: resolved
            ? AppColors.success.withValues(alpha: 0.04)
            : AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: resolved
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.error.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (resolved ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  resolved
                      ? Icons.check_circle_rounded
                      : Icons.emergency_rounded,
                  color: resolved ? AppColors.success : AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          log.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      log.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: resolved ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // GPS coordinates
                    if (log.lat != 0.0 || log.lng != 0.0)
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            log.locationLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons (view on map + resolve for guide)
          if (!resolved || isGuide) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // View on map
                if (log.lat != 0.0 || log.lng != 0.0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openMap(log),
                      icon: const Icon(Icons.map_rounded, size: 14),
                      label: const Text('View on Map',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                // Resolve (guide only)
                if (isGuide && !resolved) ...[
                  if (log.lat != 0.0 || log.lng != 0.0)
                    const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _resolveAlert(log),
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text('Resolve',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Safety Tips tab ────────────────────────────────────────
  Widget _buildSafetyTipsTab() {
    final tips = [
      _SafetyTip(Icons.group_rounded, 'Stay with the group',
          'Always remain within sight of your tour guide and fellow tourists.'),
      _SafetyTip(Icons.battery_full_rounded, 'Keep your phone charged',
          'Ensure your device is charged for GPS tracking and emergency calls.'),
      _SafetyTip(Icons.badge_rounded, 'Carry identification',
          'Always have your ID and tour booking confirmation with you.'),
      _SafetyTip(Icons.local_hospital_rounded, 'Know nearby hospitals',
          'Familiarize yourself with the nearest medical facilities.'),
      _SafetyTip(Icons.water_drop_rounded, 'Stay hydrated',
          'Carry water and take breaks during outdoor activities.'),
      _SafetyTip(Icons.phone_rounded, 'Emergency numbers',
          'Philippines: 911 (National Emergency Hotline), 117 (Police), 161 (Fire).'),
    ];

    return ListView.separated(
      itemCount: tips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final tip = tips[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tip.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 3),
                    Text(tip.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SafetyTip {
  final IconData icon;
  final String title;
  final String description;
  const _SafetyTip(this.icon, this.title, this.description);
}
