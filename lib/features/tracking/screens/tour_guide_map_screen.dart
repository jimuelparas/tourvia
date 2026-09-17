import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/services/tour_service.dart';
import '../mixins/navigation_mixin.dart';

/// Represents an approved tourist combined with their live location (REV-005).
/// Tour membership is strictly separated from location availability.
class TouristTrackingItem {
  final String touristId;
  final String touristName;
  final String contactNumber;
  final String emergencyContact;
  final UserLocation? location;

  const TouristTrackingItem({
    required this.touristId,
    required this.touristName,
    this.contactNumber = '',
    this.emergencyContact = '',
    this.location,
  });

  bool get hasLocation =>
      location != null &&
      location!.latitude != 0.0 &&
      location!.longitude != 0.0 &&
      location!.latitude >= -90.0 &&
      location!.latitude <= 90.0 &&
      location!.longitude >= -180.0 &&
      location!.longitude <= 180.0;

  double? distanceTo(LatLng guidePos) {
    if (!hasLocation) return null;
    return Geolocator.distanceBetween(
      guidePos.latitude,
      guidePos.longitude,
      location!.latitude,
      location!.longitude,
    );
  }

  bool isOutside(LatLng guidePos) {
    final d = distanceTo(guidePos);
    if (d == null) return false;
    return d > 1000.0;
  }
}

/// Screen to display the live map for the Tour Guide (US-11 to US-15).
/// Features live OpenStreetMap, real-time tourist tracking, geofencing,
/// and a full Tourist Management Panel with per-tourist actions.
class TourGuideMapScreen extends StatefulWidget {
  final String sessionId;
  final String? tourId;

  const TourGuideMapScreen({
    super.key,
    required this.sessionId,
    this.tourId,
  });

  String get effectiveTourId =>
      (tourId != null && tourId!.isNotEmpty) ? tourId! : sessionId;

  @override
  State<TourGuideMapScreen> createState() => _TourGuideMapScreenState();
}

class _TourGuideMapScreenState extends State<TourGuideMapScreen>
    with NavigationMixin<TourGuideMapScreen> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  LatLng _guidePosition = const LatLng(14.5995, 120.9842);
  bool _isLoading = true;
  bool _hasPermission = false;

  StreamSubscription<Position>? _publishSubscription;
  StreamSubscription<Position>? _localLocSubscription;
  StreamSubscription<List<ApprovedTourist>>? _rosterSubscription;
  StreamSubscription<List<UserLocation>>? _allLocationsSubscription;

  List<ApprovedTourist> _roster = [];
  Map<String, UserLocation> _locationMap = {};
  TouristTrackingItem? _selectedTourist;
  String? _activeNavTouristId;
  bool _isStartingNavigation = false;

  // ── Sorting / Filtering state ─────────────────────────────
  String _sortMode = 'name'; // 'name' | 'distance' | 'status'
  bool _showOutsideOnly = false;

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  Future<void> _recenterOnGuide() async {
    _mapController.move(_guidePosition, 16.0);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 2),
        ),
      );
      if (RoutingService.isValidCoordinate(pos.latitude, pos.longitude)) {
        final fresh = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() => _guidePosition = fresh);
          _mapController.move(fresh, 16.0);
        }
      }
    } catch (_) {}
  }

  Future<void> _initTracking() async {
    final hasPerm = await LocationService.checkAndRequestPermissions();
    if (!mounted) return;

    setState(() {
      _hasPermission = hasPerm;
      if (!hasPerm) _isLoading = false;
    });

    if (!hasPerm) return;

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

    final effectiveId = widget.effectiveTourId;

    _publishSubscription = LocationService.startPublishingLocation(
      sessionId: effectiveId,
      userId: 'guide',
      userName: 'Tour Guide',
      isGuide: true,
    );

    _localLocSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          if (mounted) {
            final newPos = LatLng(pos.latitude, pos.longitude);
            setState(
              () => _guidePosition = newPos,
            );
            if (navIsNavigating) {
              updateNavForUserPosition(
                currentPosition: newPos,
                mapController: _mapController,
              );
            }
          }
        });

    // 1. Listen to all approved tourists in this tour (Source of Truth for Membership)
    _rosterSubscription =
        TourService.watchApprovedTourists(effectiveId).listen((roster) {
          if (!mounted) return;
          setState(() {
            _roster = roster;
            _syncSelectedTourist();
          });
        });

    // 2. Listen to all live locations in this tour
    _allLocationsSubscription =
        LocationService.watchAllLocations(effectiveId).listen((locations) {
          if (!mounted) return;
          final map = <String, UserLocation>{};
          for (final loc in locations) {
            if (!loc.isGuide && loc.userId != 'guide') {
              map[loc.userId] = loc;
            }
          }
          setState(() {
            _locationMap = map;
            _syncSelectedTourist();
          });

          // Dynamic route recalculation if the target tourist moves significantly
          if (navIsNavigating && _activeNavTouristId != null) {
            final targetLoc = map[_activeNavTouristId];
            if (targetLoc != null &&
                RoutingService.isValidCoordinate(targetLoc.latitude, targetLoc.longitude)) {
              final freshTargetPos = LatLng(targetLoc.latitude, targetLoc.longitude);
              refreshRouteIfNeeded(
                currentPosition: _guidePosition,
                newTargetPosition: freshTargetPos,
                mapController: _mapController,
                thresholdMeters: 40.0,
              );
            }
          }
        });
  }

  /// Combines the approved tour roster with real-time locations.
  List<TouristTrackingItem> get _trackingItems {
    final list = <TouristTrackingItem>[];
    final seenIds = <String>{};

    for (final member in _roster) {
      seenIds.add(member.touristId);
      final loc = _locationMap[member.touristId];
      list.add(TouristTrackingItem(
        touristId: member.touristId,
        touristName: member.touristName,
        contactNumber: member.contactNumber,
        emergencyContact: member.emergencyContact,
        location: loc,
      ));
    }

    // Also include any tourist from live locations that isn't yet in roster
    for (final loc in _locationMap.values) {
      if (!seenIds.contains(loc.userId)) {
        seenIds.add(loc.userId);
        list.add(TouristTrackingItem(
          touristId: loc.userId,
          touristName: loc.userName,
          location: loc,
        ));
      }
    }

    return list;
  }

  void _syncSelectedTourist() {
    if (_selectedTourist != null) {
      final items = _trackingItems;
      final idx = items.indexWhere(
        (t) => t.touristId == _selectedTourist!.touristId,
      );
      _selectedTourist = idx != -1 ? items[idx] : null;
    }
  }

  List<TouristTrackingItem> get _sortedTourists {
    final all = _trackingItems;
    List<TouristTrackingItem> list = _showOutsideOnly
        ? all.where((t) => t.isOutside(_guidePosition)).toList()
        : [...all];

    switch (_sortMode) {
      case 'distance':
        list.sort((a, b) {
          final distA = a.distanceTo(_guidePosition);
          final distB = b.distanceTo(_guidePosition);
          if (distA == null && distB == null) {
            return a.touristName.compareTo(b.touristName);
          }
          if (distA == null) return 1;
          if (distB == null) return -1;
          return distA.compareTo(distB);
        });
        break;
      case 'status':
        // Outside tourists first, then Safe, then Offline
        list.sort((a, b) {
          final outA =
              a.isOutside(_guidePosition) ? 0 : (a.hasLocation ? 1 : 2);
          final outB =
              b.isOutside(_guidePosition) ? 0 : (b.hasLocation ? 1 : 2);
          final cmp = outA.compareTo(outB);
          return cmp != 0
              ? cmp
              : a.touristName.toLowerCase().compareTo(b.touristName.toLowerCase());
        });
        break;
      default: // 'name'
        list.sort((a, b) =>
            a.touristName.toLowerCase().compareTo(b.touristName.toLowerCase()));
    }
    return list;
  }

  Future<void> _ringTourist(TouristTrackingItem tourist) async {
    try {
      await LocationService.triggerRing(
        widget.effectiveTourId,
        tourist.touristId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📳 Ringing ${tourist.touristName}…'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to ring tourist.')),
        );
      }
    }
  }

  Future<void> _ringAllTourists() async {
    final items = _trackingItems;
    for (final t in items) {
      try {
        await LocationService.triggerRing(
          widget.effectiveTourId,
          t.touristId,
        );
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📳 Ringing all ${items.length} tourists…'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Starts in-app navigation to a tourist using OSRM routing.
  /// Renders a polyline on the map and displays a floating Navigation HUD.
  Future<void> _navigateTo(TouristTrackingItem tourist) async {
    if (_isStartingNavigation || navIsLoading) {
      return;
    }

    // 1. Retrieve the most recent live location for this tourist from current tour
    final latestLoc = _locationMap[tourist.touristId] ?? tourist.location;
    if (latestLoc == null ||
        !RoutingService.isValidCoordinate(
          latestLoc.latitude,
          latestLoc.longitude,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot navigate: Location unavailable for ${tourist.touristName}.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final touristPos = LatLng(latestLoc.latitude, latestLoc.longitude);

    setState(() {
      _isStartingNavigation = true;
      _selectedTourist = null;
      _activeNavTouristId = tourist.touristId;
    });

    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    try {
      // 2. Fetch fresh Guide GPS location
      LatLng guidePos = _guidePosition;
      try {
        final freshGuide = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 3),
          ),
        );
        if (RoutingService.isValidCoordinate(
          freshGuide.latitude,
          freshGuide.longitude,
        )) {
          guidePos = LatLng(freshGuide.latitude, freshGuide.longitude);
          if (mounted) {
            setState(() => _guidePosition = guidePos);
          }
        }
      } catch (e) {
        debugPrint('TourGuideMap: Using current known guide position ($e)');
      }

      // 3. Validate coordinates
      if (!RoutingService.isValidCoordinate(
            guidePos.latitude,
            guidePos.longitude,
          ) ||
          !RoutingService.isValidCoordinate(
            touristPos.latitude,
            touristPos.longitude,
          )) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Unable to calculate route: Invalid coordinates.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      // 4. Calculate route and begin navigation
      await startNavigation(
        start: guidePos,
        end: touristPos,
        targetLabel: tourist.touristName,
        mapController: _mapController,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingNavigation = false;
        });
      }
    }
  }

  @override
  void endNavigation() {
    super.endNavigation();
    _activeNavTouristId = null;
    if (mounted) {
      setState(() {
        _selectedTourist = null;
      });
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Centres the map on a specific tourist and selects them.
  void _focusOnTourist(TouristTrackingItem tourist) {
    if (!tourist.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location unavailable for ${tourist.touristName}.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedTourist = tourist;
    });
    _mapController.move(
      LatLng(tourist.location!.latitude, tourist.location!.longitude),
      17.0,
    );
    // Hide the panel so the quick action card is visible
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void deactivate() {
    _publishSubscription?.cancel();
    _localLocSubscription?.cancel();
    _rosterSubscription?.cancel();
    _allLocationsSubscription?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _publishSubscription?.cancel();
    _localLocSubscription?.cancel();
    _rosterSubscription?.cancel();
    _allLocationsSubscription?.cancel();
    _sheetController.dispose();
    _mapController.dispose();
    disposeNavigation();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasPermission) {
      return _buildPermissionScreen();
    }

    final allItems = _trackingItems;
    final withLoc = allItems.where((t) => t.hasLocation).toList();
    final outsideCount =
        withLoc.where((t) => t.isOutside(_guidePosition)).length;
    final safeCount = withLoc.length - outsideCount;
    final offlineCount = allItems.length - withLoc.length;

    return PopScope(
      canPop: !_sheetController.isAttached || _sheetController.size <= 0.05,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_sheetController.isAttached && _sheetController.size > 0.05) {
          _sheetController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeIn,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (_sheetController.isAttached && _sheetController.size > 0.05) {
                _sheetController.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeIn,
                );
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: const Text(AppStrings.mapTitle),
          iconTheme: const IconThemeData(color: AppColors.primary),
          actions: [
            IconButton(
              tooltip: 'Manage Tourists',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.people_rounded, color: AppColors.primary),
                  if (outsideCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$outsideCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                if (_sheetController.isAttached) {
                  if (_sheetController.size > 0.05) {
                    _sheetController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeIn,
                    );
                  } else {
                    if (_selectedTourist != null) {
                      setState(() => _selectedTourist = null);
                    }
                    _sheetController.animateTo(
                      0.45,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                }
              },
            ),
          ],
        ),
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _guidePosition,
              initialZoom: 14.5,
              onTap: (_, __) => setState(() => _selectedTourist = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tourvia.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _guidePosition,
                    radius: 1000,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderColor: AppColors.primary.withValues(alpha: 0.4),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // In-app navigation polyline (REV-003)
              buildNavPolylineLayer(),
              MarkerLayer(
                markers: [
                  _mapMarker(
                    point: _guidePosition,
                    label: 'You',
                    icon: Icons.my_location_rounded,
                    color: AppColors.primary,
                  ),
                  ...withLoc.map((t) {
                    final outside = t.isOutside(_guidePosition);
                    final selected = _selectedTourist?.touristId == t.touristId;
                    return _mapMarker(
                      point: LatLng(
                        t.location!.latitude,
                        t.location!.longitude,
                      ),
                      label: t.touristName,
                      icon: outside
                          ? Icons.warning_rounded
                          : Icons.person_pin_circle_rounded,
                      color: outside ? AppColors.error : AppColors.success,
                      selected: selected,
                      onTap: () => setState(() => _selectedTourist = t),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── Safe / Outside / Offline counter bar ─────────────────────────
          Positioned(
            key: const ValueKey('tour_guide_status_bar'),
            top: 12,
            left: 16,
            child: SafeArea(
              child: _buildStatusBar(safeCount, outsideCount, offlineCount),
            ),
          ),

          // ── Recenter button ────────────────────────────────────
          Positioned(
            key: const ValueKey('tour_guide_recenter_btn'),
            bottom: _selectedTourist != null ? 200 : 24,
            right: 16,
            child: (!navIsNavigating && !navIsLoading)
                ? FloatingActionButton.small(
                    heroTag: 'recenter',
                    tooltip: 'Recenter on my location',
                    backgroundColor: Colors.white,
                    onPressed: _recenterOnGuide,
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── In-App Navigation HUD (REV-003) ─────────────────
          Positioned(
            key: const ValueKey('tour_guide_nav_hud'),
            bottom: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: (navIsNavigating || navIsLoading)
                  ? buildNavigationHUD(
                      currentPosition: _guidePosition,
                      mapController: _mapController,
                      onRecenter: _recenterOnGuide,
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // ── Selected tourist quick-action card ────────────────
          Positioned(
            key: const ValueKey('tour_guide_quick_card'),
            bottom: 16,
            left: 16,
            right: 16,
            child: (!navIsNavigating && !navIsLoading)
                ? AnimatedBuilder(
                    animation: _sheetController,
                    builder: (context, _) {
                      final bool isPanelOpen =
                          _sheetController.isAttached &&
                          _sheetController.size > 0.05;
                      final bool isVisible =
                          _selectedTourist != null && !isPanelOpen;
                      return IgnorePointer(
                        ignoring: !isVisible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isVisible ? 1.0 : 0.0,
                          child: SafeArea(
                            child: _selectedTourist != null
                                ? _buildQuickCard(_selectedTourist!)
                                : const SizedBox.shrink(),
                          ),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),

          // ── Tourist Management Draggable Panel ─────────────────
          Positioned.fill(
            key: const ValueKey('tour_guide_panel_positioned'),
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.0,
              minChildSize: 0.0,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.0, 0.45, 0.85],
              builder: (context, scrollCtrl) {
                return _buildManagementPanel(context, scrollCtrl);
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Map Marker ──────────────────────────────────────────────
  Marker _mapMarker({
    required LatLng point,
    required String label,
    required IconData icon,
    required Color color,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: point,
      width: 100,
      height: 74,
      child: SizedBox(
        width: 100,
        height: 74,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 96),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: selected ? 2 : 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Icon(icon, color: color, size: selected ? 42 : 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status counter bar ──────────────────────────────────────
  Widget _buildStatusBar(int safe, int outside, int offline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(AppColors.success),
          const SizedBox(width: 6),
          Text(
            '$safe Safe',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 1,
            height: 18,
            color: AppColors.border,
          ),
          _dot(AppColors.error),
          const SizedBox(width: 6),
          Text(
            '$outside Outside',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: outside > 0 ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          if (offline > 0) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 1,
              height: 18,
              color: AppColors.border,
            ),
            _dot(AppColors.textHint),
            const SizedBox(width: 6),
            Text(
              '$offline Offline',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── Quick action card (when tourist tapped on map) ──────────
  Widget _buildQuickCard(TouristTrackingItem tourist) {
    final dist = tourist.distanceTo(_guidePosition);
    final outside = tourist.isOutside(_guidePosition);
    final distText = dist != null
        ? (outside
            ? '⚠ ${(dist / 1000).toStringAsFixed(2)} km — Outside boundary'
            : '✅ ${(dist / 1000).toStringAsFixed(2)} km — Safe')
        : '📍 Location unavailable';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: outside
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      (outside
                              ? AppColors.error
                              : (tourist.hasLocation
                                  ? AppColors.success
                                  : AppColors.textHint))
                          .withValues(alpha: 0.12),
                  child: Icon(
                    outside
                        ? Icons.warning_rounded
                        : (tourist.hasLocation
                            ? Icons.person_rounded
                            : Icons.location_off_rounded),
                    color: outside
                        ? AppColors.error
                        : (tourist.hasLocation
                            ? AppColors.success
                            : AppColors.textHint),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tourist.touristName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        distText,
                        style: TextStyle(
                          fontSize: 12,
                          color: outside
                              ? AppColors.error
                              : (tourist.hasLocation
                                  ? AppColors.success
                                  : AppColors.textHint),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _selectedTourist = null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    icon: Icons.ring_volume_rounded,
                    label: 'Ring',
                    color: AppColors.primary,
                    onTap: () => _ringTourist(tourist),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    icon: Icons.navigation_rounded,
                    label: (_isStartingNavigation || navIsLoading)
                        ? 'Loading…'
                        : 'Navigate',
                    color: (tourist.hasLocation && !_isStartingNavigation && !navIsLoading)
                        ? AppColors.accent
                        : AppColors.textHint,
                    filled: true,
                    onTap: (_isStartingNavigation || navIsLoading || !tourist.hasLocation)
                        ? () {}
                        : () => _navigateTo(tourist),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return filled
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
  }

  Widget _buildManagementPanel(BuildContext ctx, ScrollController scrollCtrl) {
    final sorted = _sortedTourists;
    final allItems = _trackingItems;
    final withLoc = allItems.where((t) => t.hasLocation).toList();
    final outsideCount =
        withLoc.where((t) => t.isOutside(_guidePosition)).length;
    final offlineCount = allItems.length - withLoc.length;
    final screenWidth = MediaQuery.sizeOf(ctx).width;

    return SizedBox(
      width: screenWidth,
      child: Material(
        color: AppColors.surface,
        elevation: 16,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.hardEdge,
        child: CustomScrollView(
          controller: scrollCtrl,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                width: screenWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    // Panel header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Tourist Management',
                                  softWrap: false,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  offlineCount > 0
                                      ? '${allItems.length} total · $outsideCount outside · $offlineCount offline'
                                      : '${allItems.length} total · $outsideCount outside',
                                  softWrap: false,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: outsideCount > 0
                                        ? AppColors.error
                                        : AppColors.textHint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Ring All button
                          if (allItems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ElevatedButton.icon(
                                onPressed: _ringAllTourists,
                                icon: const Icon(
                                  Icons.campaign_rounded,
                                  size: 16,
                                ),
                                label: const Text('Ring All'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Filter & Sort bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Filter chip
                          FilterChip(
                            label: const Text('Outside Only'),
                            selected: _showOutsideOnly,
                            onSelected: (v) =>
                                setState(() => _showOutsideOnly = v),
                            selectedColor: AppColors.error.withValues(
                              alpha: 0.15,
                            ),
                            checkmarkColor: AppColors.error,
                            labelStyle: TextStyle(
                              color: _showOutsideOnly
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: _showOutsideOnly
                                  ? AppColors.error
                                  : AppColors.border,
                            ),
                          ),
                          // Sort dropdown
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortMode,
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'name',
                                  child: Text('Sort: Name'),
                                ),
                                DropdownMenuItem(
                                  value: 'distance',
                                  child: Text('Sort: Distance'),
                                ),
                                DropdownMenuItem(
                                  value: 'status',
                                  child: Text('Sort: Status'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _sortMode = v ?? 'name'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ),

            // Tourist list
            if (sorted.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showOutsideOnly
                            ? Icons.check_circle_outline_rounded
                            : Icons.people_outline_rounded,
                        size: 48,
                        color: AppColors.success.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _showOutsideOnly
                            ? 'All tourists are within the safe zone!'
                            : 'No tourists have joined yet.',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverList.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _buildTouristTile(sorted[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouristTile(TouristTrackingItem tourist) {
    final hasLoc = tourist.hasLocation;
    final dist = tourist.distanceTo(_guidePosition);
    final outside = tourist.isOutside(_guidePosition);

    final String distStr;
    final String timeStr;
    final Color statusColor;
    final String statusLabel;

    if (hasLoc) {
      final elapsed = DateTime.now().difference(tourist.location!.updatedAt);
      timeStr = elapsed.inMinutes == 0
          ? 'Just now'
          : '${elapsed.inMinutes} min ago';
      distStr = dist! < 1000
          ? '${dist.toStringAsFixed(0)} m'
          : '${(dist / 1000).toStringAsFixed(2)} km';
      statusColor = outside ? AppColors.error : AppColors.success;
      statusLabel = outside ? 'Outside' : 'Safe';
    } else {
      timeStr = 'No GPS signal';
      distStr = 'Location unavailable';
      statusColor = AppColors.textHint;
      statusLabel = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: outside
              ? AppColors.error.withValues(alpha: 0.25)
              : AppColors.border,
          width: outside ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar / status dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Text(
                      tourist.touristName.isNotEmpty
                          ? tourist.touristName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tourist.touristName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          hasLoc
                              ? Icons.location_on_rounded
                              : Icons.location_off_rounded,
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            distStr,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons row
          Row(
            children: [
              // Focus on map
              Expanded(
                child: _tileAction(
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Focus',
                  color: hasLoc ? AppColors.primary : AppColors.textHint,
                  onTap: () => _focusOnTourist(tourist),
                ),
              ),
              const SizedBox(width: 8),
              // Ring tourist
              Expanded(
                child: _tileAction(
                  icon: Icons.ring_volume_rounded,
                  label: 'Ring',
                  color: AppColors.warning,
                  onTap: () => _ringTourist(tourist),
                ),
              ),
              const SizedBox(width: 8),
              // Navigate to tourist
              Expanded(
                child: _tileAction(
                  icon: Icons.navigation_rounded,
                  label: (_isStartingNavigation || navIsLoading)
                      ? 'Loading…'
                      : 'Navigate',
                  color: (hasLoc && !_isStartingNavigation && !navIsLoading)
                      ? AppColors.accent
                      : AppColors.textHint,
                  filled: true,
                  onTap: (_isStartingNavigation || navIsLoading || !hasLoc)
                      ? () {}
                      : () => _navigateTo(tourist),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tileAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return filled
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 13),
            label: Text(label, style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 13),
            label: Text(label, style: const TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
  }

  // ── Permission denied screen ────────────────────────────────
  Widget _buildPermissionScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mapTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Permission Denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tourvia needs your location to act as the safety anchor for all tourists in the session.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Grant Permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
