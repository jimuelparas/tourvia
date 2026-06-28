import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';

/// Screen to display the live map for the Tour Guide (US-11 to US-15).
/// Shows all tourists as real-time markers, highlights out-of-bounds, supports ring and navigate.
class TourGuideMapScreen extends StatefulWidget {
  final String sessionId;

  const TourGuideMapScreen({
    super.key,
    this.sessionId = 'demo-session-001',
  });

  @override
  State<TourGuideMapScreen> createState() => _TourGuideMapScreenState();
}

class _TourGuideMapScreenState extends State<TourGuideMapScreen> {
  final MapController _mapController = MapController();

  LatLng _guidePosition = const LatLng(14.5995, 120.9842); // Manila default
  bool _isLoading = true;
  bool _hasPermission = false;

  StreamSubscription<Position>? _publishSubscription;
  StreamSubscription<Position>? _localLocSubscription;
  StreamSubscription<List<UserLocation>>? _allLocationsSubscription;

  List<UserLocation> _tourists = [];
  UserLocation? _selectedTourist;

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _initTracking() async {
    final hasPerm = await LocationService.checkAndRequestPermissions();
    if (!mounted) return;

    setState(() {
      _hasPermission = hasPerm;
      if (!hasPerm) _isLoading = false;
    });

    if (!hasPerm) return;

    // Get current position to set initial map centre
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _guidePosition = LatLng(pos.latitude, pos.longitude);
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_guidePosition, 15.0);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }

    // Publish guide position to Firestore
    _publishSubscription = LocationService.startPublishingLocation(
      sessionId: widget.sessionId,
      userId: 'guide',
      userName: 'Tour Guide',
      isGuide: true,
    );

    // Keep local guide marker updated
    _localLocSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (mounted) {
        setState(() => _guidePosition = LatLng(pos.latitude, pos.longitude));
      }
    });

    // Stream all tourist locations from Firestore
    _allLocationsSubscription =
        LocationService.watchAllLocations(widget.sessionId).listen((locations) {
      if (!mounted) return;
      setState(() {
        _tourists = locations
            .where((l) => !l.isGuide && l.userId != 'guide')
            .toList();

        // Keep selected tourist data fresh
        if (_selectedTourist != null) {
          final idx =
              _tourists.indexWhere((t) => t.userId == _selectedTourist!.userId);
          _selectedTourist = idx != -1 ? _tourists[idx] : null;
        }
      });
    });
  }

  double _distanceTo(UserLocation tourist) {
    return Geolocator.distanceBetween(
      _guidePosition.latitude,
      _guidePosition.longitude,
      tourist.latitude,
      tourist.longitude,
    );
  }

  Future<void> _ringTourist(UserLocation tourist) async {
    try {
      await LocationService.triggerRing(widget.sessionId, tourist.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ringing ${tourist.userName}\'s phone…')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to ring. Check connection.')),
        );
      }
    }
  }

  Future<void> _navigateTo(UserLocation tourist) async {
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${_guidePosition.latitude},${_guidePosition.longitude}'
        '&destination=${tourist.latitude},${tourist.longitude}'
        '&travelmode=walking';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _publishSubscription?.cancel();
    _localLocSubscription?.cancel();
    _allLocationsSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(AppStrings.mapTitle),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                const Text('Location Permission Denied',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Tourvia needs your location to act as the safety anchor for all tourists.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Grant Permissions'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int outsideCount = _tourists.where((t) => _distanceTo(t) > 1000.0).length;
    int safeCount = _tourists.length - outsideCount;

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
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _guidePosition,
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tourvia.app',
              ),
              // 1 km safety boundary centred on guide
              CircleLayer(circles: [
                CircleMarker(
                  point: _guidePosition,
                  radius: 1000,
                  useRadiusInMeter: true,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderColor: AppColors.primary.withValues(alpha: 0.4),
                  borderStrokeWidth: 2,
                ),
              ]),
              // All markers
              MarkerLayer(markers: [
                // Guide marker
                _buildMarker(
                  point: _guidePosition,
                  label: 'You (Guide)',
                  icon: Icons.my_location_rounded,
                  color: AppColors.primary,
                  isSelected: false,
                  onTap: null,
                ),
                // Tourist markers
                ..._tourists.map((tourist) {
                  final outside = _distanceTo(tourist) > 1000.0;
                  final selected = _selectedTourist?.userId == tourist.userId;
                  return _buildMarker(
                    point: LatLng(tourist.latitude, tourist.longitude),
                    label: tourist.userName,
                    icon: outside
                        ? Icons.warning_rounded
                        : Icons.person_pin_circle_rounded,
                    color: outside ? AppColors.error : AppColors.success,
                    isSelected: selected,
                    onTap: () => setState(() => _selectedTourist = tourist),
                  );
                }),
              ]),
            ],
          ),

          // Safe / Outside counter at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(child: _buildStatusBar(safeCount, outsideCount)),
          ),

          // Bottom panel for selected tourist
          if (_selectedTourist != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPanel(_selectedTourist!),
            ),
        ],
      ),
    );
  }

  Marker _buildMarker({
    required LatLng point,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Marker(
      point: point,
      width: 95,
      height: 74,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Icon(icon, color: color, size: isSelected ? 42 : 36),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(int safeCount, int outsideCount) {
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
          _statusItem('Safe', safeCount.toString(), AppColors.success),
          Container(width: 1, height: 30, color: AppColors.border),
          _statusItem('Outside', outsideCount.toString(), AppColors.error),
        ],
      ),
    );
  }

  Widget _statusItem(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Text(count,
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _buildBottomPanel(UserLocation tourist) {
    final dist = _distanceTo(tourist);
    final outside = dist > 1000.0;
    final elapsed = DateTime.now().difference(tourist.updatedAt);
    final timeStr =
        elapsed.inMinutes == 0 ? 'Just now' : '${elapsed.inMinutes} min ago';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (outside ? AppColors.error : AppColors.success)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  outside
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: outside ? AppColors.error : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outside
                          ? AppStrings.missingAlert
                          : 'Tourist Selected',
                      style: TextStyle(
                        color: outside
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outside
                          ? '${tourist.userName} has exited the 1 km boundary.'
                          : '${tourist.userName} is within the safe zone.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                onPressed: () => setState(() => _selectedTourist = null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('Distance', '${(dist / 1000.0).toStringAsFixed(2)} km'),
              _infoChip('Last Updated', timeStr),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _ringTourist(tourist),
                  icon: const Icon(Icons.ring_volume_rounded, size: 18),
                  label: const Text(AppStrings.ringPhone),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateTo(tourist),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(AppStrings.navigateToTourist),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}
