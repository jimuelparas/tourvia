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
/// Features live OpenStreetMap, real-time tourist tracking, geofencing,
/// and a full Tourist Management Panel with per-tourist actions.
class TourGuideMapScreen extends StatefulWidget {
  final String sessionId;

  const TourGuideMapScreen({super.key, required this.sessionId});

  @override
  State<TourGuideMapScreen> createState() => _TourGuideMapScreenState();
}

class _TourGuideMapScreenState extends State<TourGuideMapScreen> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  LatLng _guidePosition = const LatLng(14.5995, 120.9842);
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _showPanel = false;

  StreamSubscription<Position>? _publishSubscription;
  StreamSubscription<Position>? _localLocSubscription;
  StreamSubscription<List<UserLocation>>? _allLocationsSubscription;

  List<UserLocation> _tourists = [];
  UserLocation? _selectedTourist;

  // ── Sorting / Filtering state ─────────────────────────────
  String _sortMode = 'name'; // 'name' | 'distance' | 'status'
  bool _showOutsideOnly = false;

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

    _publishSubscription = LocationService.startPublishingLocation(
      sessionId: widget.sessionId,
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
            setState(
              () => _guidePosition = LatLng(pos.latitude, pos.longitude),
            );
          }
        });

    _allLocationsSubscription =
        LocationService.watchAllLocations(widget.sessionId).listen((locations) {
          if (!mounted) return;
          setState(() {
            _tourists = locations
                .where((l) => !l.isGuide && l.userId != 'guide')
                .toList();
            if (_selectedTourist != null) {
              final idx = _tourists.indexWhere(
                (t) => t.userId == _selectedTourist!.userId,
              );
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

  bool _isOutside(UserLocation t) => _distanceTo(t) > 1000.0;

  List<UserLocation> get _sortedTourists {
    List<UserLocation> list = _showOutsideOnly
        ? _tourists.where(_isOutside).toList()
        : [..._tourists];
    switch (_sortMode) {
      case 'distance':
        list.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
        break;
      case 'status':
        // Outside tourists first
        list.sort((a, b) {
          final aOut = _isOutside(a) ? 0 : 1;
          final bOut = _isOutside(b) ? 0 : 1;
          return aOut.compareTo(bOut);
        });
        break;
      default: // 'name'
        list.sort((a, b) => a.userName.compareTo(b.userName));
    }
    return list;
  }

  Future<void> _ringTourist(UserLocation tourist) async {
    try {
      await LocationService.triggerRing(widget.sessionId, tourist.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📳 Ringing ${tourist.userName}…'),
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
    for (final t in _tourists) {
      try {
        await LocationService.triggerRing(widget.sessionId, t.userId);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📳 Ringing all ${_tourists.length} tourists…'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _navigateTo(UserLocation tourist) async {
    // Try geo: URI first (opens native maps app)
    final geoUri = Uri.parse(
        'geo:${tourist.latitude},${tourist.longitude}'
        '?q=${tourist.latitude},${tourist.longitude}');
    // Fallback: Google Maps directions link
    final mapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${_guidePosition.latitude},${_guidePosition.longitude}'
        '&destination=${tourist.latitude},${tourist.longitude}'
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

  /// Centres the map on a specific tourist and selects them.
  void _focusOnTourist(UserLocation tourist) {
    setState(() {
      _selectedTourist = tourist;
      _showPanel = false;
    });
    _mapController.move(LatLng(tourist.latitude, tourist.longitude), 17.0);
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
  void dispose() {
    _publishSubscription?.cancel();
    _localLocSubscription?.cancel();
    _allLocationsSubscription?.cancel();
    _mapController.dispose();
    _sheetController.dispose();
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

    final outsideCount = _tourists.where(_isOutside).length;
    final safeCount = _tourists.length - outsideCount;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
              setState(() => _showPanel = !_showPanel);
              if (_showPanel) {
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(
                    0.45,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
              } else {
                if (_sheetController.isAttached) {
                  _sheetController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
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
              MarkerLayer(
                markers: [
                  _mapMarker(
                    point: _guidePosition,
                    label: 'You',
                    icon: Icons.my_location_rounded,
                    color: AppColors.primary,
                  ),
                  ..._tourists.map((t) {
                    final outside = _isOutside(t);
                    final selected = _selectedTourist?.userId == t.userId;
                    return _mapMarker(
                      point: LatLng(t.latitude, t.longitude),
                      label: t.userName,
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

          // ── Safe / Outside counter bar ─────────────────────────
          Positioned(
            top: 12,
            left: 16,
            child: SafeArea(child: _buildStatusBar(safeCount, outsideCount)),
          ),

          // ── Recenter button ────────────────────────────────────
          Positioned(
            bottom: _selectedTourist != null ? 200 : 24,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              tooltip: 'Recenter on my location',
              backgroundColor: Colors.white,
              onPressed: () => _mapController.move(_guidePosition, 15.0),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColors.primary,
              ),
            ),
          ),

          // ── Selected tourist quick-action card ────────────────
          if (_selectedTourist != null && !_showPanel)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: _buildQuickCard(_selectedTourist!),
              ),
            ),

          // ── Tourist Management Draggable Panel ─────────────────
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showPanel,
              child: NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  if (notification.extent <= 0.01 && _showPanel) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _showPanel = false);
                    });
                  } else if (notification.extent > 0.01 && !_showPanel) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _showPanel = true);
                    });
                  }
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.0,
                  minChildSize: 0.0,
                  maxChildSize: 0.85,
                  snap: true,
                  snapSizes: const [0.0, 0.45, 0.85],
                  builder: (context, scrollCtrl) {
                    // Don't render panel content when collapsed to prevent
                    // text from overflowing vertically at zero height.
                    if (!_showPanel) {
                      return ListView(controller: scrollCtrl);
                    }
                    return _buildManagementPanel(scrollCtrl);
                  },
                ),
              ),
            ),
          ),
        ],
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
      width: 90,
      height: 74,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
                overflow: TextOverflow.ellipsis,
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
    );
  }

  // ── Status counter bar ──────────────────────────────────────
  Widget _buildStatusBar(int safe, int outside) {
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
  Widget _buildQuickCard(UserLocation tourist) {
    final dist = _distanceTo(tourist);
    final outside = dist > 1000.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: outside
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (outside ? AppColors.error : AppColors.success)
                    .withValues(alpha: 0.12),
                child: Icon(
                  outside ? Icons.warning_rounded : Icons.person_rounded,
                  color: outside ? AppColors.error : AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tourist.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      outside
                          ? '⚠ ${(dist / 1000).toStringAsFixed(2)} km — Outside boundary'
                          : '✅ ${(dist / 1000).toStringAsFixed(2)} km — Safe',
                      style: TextStyle(
                        fontSize: 12,
                        color: outside ? AppColors.error : AppColors.success,
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
                  label: 'Navigate',
                  color: AppColors.accent,
                  filled: true,
                  onTap: () => _navigateTo(tourist),
                ),
              ),
            ],
          ),
        ],
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

  // ── Tourist Management Panel ────────────────────────────────
  Widget _buildManagementPanel(ScrollController scrollCtrl) {
    final sorted = _sortedTourists;
    final outsideCount = _tourists.where(_isOutside).length;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Panel header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tourist Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_tourists.length} total · $outsideCount outside',
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
                if (_tourists.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _ringAllTourists,
                    icon: const Icon(Icons.campaign_rounded, size: 16),
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
              ],
            ),
          ),

          // Filter & Sort bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Filter chip
                FilterChip(
                  label: const Text('Outside Only'),
                  selected: _showOutsideOnly,
                  onSelected: (v) => setState(() => _showOutsideOnly = v),
                  selectedColor: AppColors.error.withValues(alpha: 0.15),
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
                const Spacer(),
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
                    onChanged: (v) => setState(() => _sortMode = v ?? 'name'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Tourist list
          Expanded(
            child: sorted.isEmpty
                ? Center(
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
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildTouristTile(sorted[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouristTile(UserLocation tourist) {
    final dist = _distanceTo(tourist);
    final outside = dist > 1000.0;
    final elapsed = DateTime.now().difference(tourist.updatedAt);
    final timeStr = elapsed.inMinutes == 0
        ? 'Just now'
        : '${elapsed.inMinutes} min ago';
    final distStr = dist < 1000
        ? '${dist.toStringAsFixed(0)} m'
        : '${(dist / 1000).toStringAsFixed(2)} km';

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
                    backgroundColor:
                        (outside ? AppColors.error : AppColors.success)
                            .withValues(alpha: 0.12),
                    child: Text(
                      tourist.userName.isNotEmpty
                          ? tourist.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: outside ? AppColors.error : AppColors.success,
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
                        color: outside ? AppColors.error : AppColors.success,
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
                      tourist.userName,
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
                          Icons.location_on_rounded,
                          size: 12,
                          color: outside ? AppColors.error : AppColors.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          distStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: outside
                                ? AppColors.error
                                : AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
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
                  color: (outside ? AppColors.error : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  outside ? 'Outside' : 'Safe',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: outside ? AppColors.error : AppColors.success,
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
                  color: AppColors.primary,
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
                  label: 'Navigate',
                  color: AppColors.accent,
                  filled: true,
                  onTap: () => _navigateTo(tourist),
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
      appBar: AppBar(
        title: const Text(AppStrings.mapTitle),
      ),
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
