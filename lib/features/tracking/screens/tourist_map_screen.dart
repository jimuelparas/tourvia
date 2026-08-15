import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../main.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/tourist_session.dart';
import '../../../core/services/location_service.dart';

/// Screen to display the live map for the Tourist (US-16).
/// Integrates a real OpenStreetMap view, live GPS tracking, and a 1 km geofence alert.
class TouristMapScreen extends StatefulWidget {
  const TouristMapScreen({super.key});

  @override
  State<TouristMapScreen> createState() => _TouristMapScreenState();
}

class _TouristMapScreenState extends State<TouristMapScreen> with RouteAware {
  final MapController _mapController = MapController();

  LatLng _touristPosition = const LatLng(14.5995, 120.9842); // Manila default
  LatLng _guidePosition = const LatLng(14.5995, 120.9842);

  double _distanceToGuide = 0.0;
  bool _isOutOfBounds = false;
  bool _isLoading = true;
  bool _hasPermission = false;

  /// Tracks whether this screen is the top visible route.
  /// Ring only triggers when true.
  bool _isScreenActive = true;

  /// Records when this tracking session was opened.
  /// Used to ignore stale Firestore-cached ring commands from previous sessions.
  late final DateTime _screenOpenedAt;

  StreamSubscription<Position>? _publishSubscription;
  StreamSubscription<Position>? _localLocSubscription;
  StreamSubscription? _ringSubscription;
  StreamSubscription<List<UserLocation>>? _allLocationsSubscription;

  @override
  void initState() {
    super.initState();
    _screenOpenedAt = DateTime.now();
    _initTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  /// Called when a new route is pushed on top of this one.
  /// The tourist has navigated away — pause the ring listener.
  @override
  void didPushNext() {
    _isScreenActive = false;
    _ringSubscription?.cancel();
    _ringSubscription = null;
  }

  /// Called when the route on top is popped and this screen becomes visible again.
  /// Resume the ring listener.
  @override
  void didPopNext() {
    _isScreenActive = true;
    _startRingListener();
  }

  Future<void> _initTracking() async {
    final hasPerm = await LocationService.checkAndRequestPermissions();
    if (!mounted) return;

    setState(() {
      _hasPermission = hasPerm;
      if (!hasPerm) _isLoading = false;
    });

    if (!hasPerm) return;

    // Get current position immediately for initial map center
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _touristPosition = LatLng(pos.latitude, pos.longitude);
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_touristPosition, 16.0);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }

    final session = TouristSessionManager.current;
    final sessionId = session?.sessionId ?? '';
    final touristId = session?.codeDocId ?? 'demo-tourist-001';
    final touristName = session?.touristName ?? 'Tourist';

    // 1. Publish location to Firestore periodically
    _publishSubscription = LocationService.startPublishingLocation(
      sessionId: sessionId,
      userId: touristId,
      userName: touristName,
      isGuide: false,
    );

    // 2. Update map marker from device position stream
    _localLocSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _touristPosition = LatLng(pos.latitude, pos.longitude);
        _calcDistance();
      });
    });

    // 3. Watch session locations to get guide position
    _allLocationsSubscription = LocationService.watchAllLocations(sessionId)
        .listen((locations) {
      if (!mounted) return;
      final guide = locations.firstWhere(
        (l) => l.isGuide || l.userId == 'guide',
        orElse: () => UserLocation(
          userId: 'guide',
          userName: 'Tour Guide',
          latitude: _touristPosition.latitude,
          longitude: _touristPosition.longitude,
          accuracy: 0,
          isGuide: true,
          ringCommand: false,
          updatedAt: DateTime.now(),
        ),
      );
      setState(() {
        _guidePosition = LatLng(guide.latitude, guide.longitude);
        _calcDistance();
      });
    });

    // 4. Listen for ring command from guide
    _startRingListener();
  }

  /// Starts the ring command listener. Extracted so it can be
  /// re-subscribed when the screen becomes visible again.
  void _startRingListener() {
    // Cancel any existing subscription first
    _ringSubscription?.cancel();

    final session = TouristSessionManager.current;
    final sessionId = session?.sessionId ?? '';
    final touristId = session?.codeDocId ?? 'demo-tourist-001';

    _ringSubscription = LocationService.listenToRingCommand(
      sessionId: sessionId,
      touristId: touristId,
      screenOpenedAt: _screenOpenedAt,
      onRingTriggered: () {
        // Only buzz if this screen is actively visible
        if (!_isScreenActive) return;
        LocationService.buzzDevice();
        _showRingSnackBar();
      },
    );
  }

  void _calcDistance() {
    _distanceToGuide = Geolocator.distanceBetween(
      _touristPosition.latitude,
      _touristPosition.longitude,
      _guidePosition.latitude,
      _guidePosition.longitude,
    );
    _isOutOfBounds = _distanceToGuide > 1000.0;
  }

  void _showRingSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.ring_volume_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ALERT: Tour Guide is ringing your device!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(label: 'Dismiss', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  Future<void> _routeToGuide() async {
    // Try geo: URI first (opens native maps app)
    final geoUri = Uri.parse(
        'geo:${_guidePosition.latitude},${_guidePosition.longitude}'
        '?q=${_guidePosition.latitude},${_guidePosition.longitude}');
    // Fallback: Google Maps directions link
    final mapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${_touristPosition.latitude},${_touristPosition.longitude}'
        '&destination=${_guidePosition.latitude},${_guidePosition.longitude}'
        '&travelmode=walking');
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

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _publishSubscription?.cancel();
    _localLocSubscription?.cancel();
    _ringSubscription?.cancel();
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
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Live Tracking'),
          iconTheme: const IconThemeData(color: AppColors.primary),
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
                  'Tourvia needs your location to display your position and ensure you stay within the safety boundary.',
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

    return Scaffold(
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _touristPosition,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tourvia.app',
              ),
              // 1 km safety circle centred on the guide
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
              // Guide + Tourist markers
              MarkerLayer(markers: [
                _buildMarker(
                  point: _guidePosition,
                  label: 'Guide',
                  icon: Icons.flag_rounded,
                  color: AppColors.primary,
                ),
                _buildMarker(
                  point: _touristPosition,
                  label: TouristSessionManager.current?.touristName ?? 'You',
                  icon: Icons.person_pin_circle_rounded,
                  color: _isOutOfBounds ? AppColors.error : AppColors.accent,
                ),
              ]),
            ],
          ),

          // Back button overlay
          Positioned(
            top: 50,
            left: 20,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Out-of-bounds warning banner
          if (_isOutOfBounds)
            Positioned(top: 0, left: 0, right: 0, child: _buildBoundaryAlert()),

          // Navigate to guide button — always visible at bottom
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Distance info card
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOutOfBounds ? Icons.warning_rounded : Icons.check_circle_rounded,
                          color: _isOutOfBounds ? AppColors.error : AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOutOfBounds
                              ? '⚠ ${(_distanceToGuide / 1000).toStringAsFixed(2)} km — Outside boundary'
                              : '✅ ${_distanceToGuide.toStringAsFixed(0)} m — Within safe zone',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _isOutOfBounds ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _routeToGuide,
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Navigate to Guide'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOutOfBounds ? AppColors.error : AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      minimumSize: const Size(double.infinity, 50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
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
  }) {
    return Marker(
      point: point,
      width: 90,
      height: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Icon(icon, color: color, size: 36),
        ],
      ),
    );
  }

  Widget _buildBoundaryAlert() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.35),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    AppStrings.boundaryAlert,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppStrings.returnToBoundary} (${(_distanceToGuide / 1000.0).toStringAsFixed(2)} km away)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
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
}
