import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_colors.dart';

/// Mixin that provides shared in-app navigation state and UI components
/// for both [TourGuideMapScreen] and [TouristMapScreen].
///
/// The host widget must call [disposeNavigation] in its own [dispose].
mixin NavigationMixin<T extends StatefulWidget> on State<T> {
  // ── Navigation State ─────────────────────────────────────
  bool navIsNavigating = false;
  bool navIsLoading = false;
  List<LatLng> navRoutePoints = [];
  double navRouteDistance = 0.0; // meters
  int navRouteDuration = 0; // seconds
  String navTravelMode = 'foot'; // 'foot' | 'driving'
  String navTargetLabel = '';
  LatLng? navTargetPosition;
  LatLng? navStartPosition;
  bool navHasArrived = false;

  DateTime? _lastRouteFetchTime;
  bool _isRecalculating = false;
  MapController? _cachedMapController;

  // ── Start Navigation ─────────────────────────────────────

  /// Fetches a route from OSRM and activates in-app navigation.
  /// [mapController] is used to auto-frame the camera.
  Future<void> startNavigation({
    required LatLng start,
    required LatLng end,
    required String targetLabel,
    required MapController mapController,
  }) async {
    _cachedMapController = mapController;

    // 1. Validate start and destination coordinates
    if (!RoutingService.isValidCoordinate(start.latitude, start.longitude) ||
        !RoutingService.isValidCoordinate(end.latitude, end.longitude)) {
      debugPrint(
        'NavigationMixin: Aborting navigation due to invalid coordinates. '
        'start=(${start.latitude}, ${start.longitude}), end=(${end.latitude}, ${end.longitude})',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to calculate route: Invalid coordinates.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      navIsLoading = true;
      navTargetLabel = targetLabel;
      navTargetPosition = end;
      navStartPosition = start;
      navHasArrived = false;
    });

    final result = await RoutingService.getRouteWithMode(
      startLat: start.latitude,
      startLng: start.longitude,
      endLat: end.latitude,
      endLng: end.longitude,
      mode: navTravelMode,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        navIsLoading = false;
        navIsNavigating = false;
        navRoutePoints = [];
        navRouteDistance = 0.0;
        navRouteDuration = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.routeError),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final rawPoints = (result['points'] as List<LatLng>?) ?? [];
    // Ensure every single route point is valid
    final validPoints = rawPoints.where((p) =>
        RoutingService.isValidCoordinate(p.latitude, p.longitude)).toList();

    // Road snapping: connect real GPS points to snapped road network
    final finalRoute = <LatLng>[];
    if (validPoints.isNotEmpty) {
      final dStart = const Distance().as(LengthUnit.Meter, start, validPoints.first);
      if (dStart > 5.0) {
        finalRoute.add(start);
      }
      finalRoute.addAll(validPoints);
      final dEnd = const Distance().as(LengthUnit.Meter, end, validPoints.last);
      if (dEnd > 5.0) {
        finalRoute.add(end);
      }
    } else {
      finalRoute.addAll([start, end]);
    }

    final totalDist = result['distance'] as double;
    final totalDur = result['duration'] as int;

    setState(() {
      navIsNavigating = true;
      navIsLoading = false;
      navRoutePoints = finalRoute;
      navRouteDistance = totalDist;
      navRouteDuration = totalDur;
      navTravelMode = result['mode'] as String;
      navHasArrived = totalDist < 15.0;
    });

    _lastRouteFetchTime = DateTime.now();

    // Auto-frame the camera to fit the valid route points
    _fitCameraToRoute(mapController, finalRoute);
  }

  // ── End Navigation ───────────────────────────────────────

  /// Clears the active route and resets navigation state.
  void endNavigation() {
    navIsNavigating = false;
    navIsLoading = false;
    _isRecalculating = false;
    navRoutePoints = [];
    navRouteDistance = 0.0;
    navRouteDuration = 0;
    navTargetLabel = '';
    navTargetPosition = null;
    navStartPosition = null;
    navHasArrived = false;

    if (!mounted) return;
    setState(() {});
  }

  // ── Switch Travel Mode ───────────────────────────────────

  /// Toggles between walking and driving and re-fetches the route.
  Future<void> switchTravelMode({
    required LatLng currentPosition,
    required MapController mapController,
  }) async {
    if (!mounted || navTargetPosition == null) return;

    setState(() {
      navTravelMode = navTravelMode == 'foot' ? 'driving' : 'foot';
    });

    await startNavigation(
      start: currentPosition,
      end: navTargetPosition!,
      targetLabel: navTargetLabel,
      mapController: mapController,
    );
  }

  // ── Dynamic Route Recalculation (Internal) ───────────────

  Future<void> _recalculateRoute({
    required LatLng start,
    required LatLng end,
    MapController? mapController,
  }) async {
    if (!mounted || _isRecalculating) return;
    _isRecalculating = true;
    _lastRouteFetchTime = DateTime.now();

    try {
      final result = await RoutingService.getRouteWithMode(
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: end.latitude,
        endLng: end.longitude,
        mode: navTravelMode,
      );

      if (!mounted || !navIsNavigating) return;

      if (result != null) {
        final rawPoints = (result['points'] as List<LatLng>?) ?? [];
        final validPoints = rawPoints.where((p) =>
            RoutingService.isValidCoordinate(p.latitude, p.longitude)).toList();

        final updatedRoute = <LatLng>[];
        if (validPoints.isNotEmpty) {
          final dStart = const Distance().as(LengthUnit.Meter, start, validPoints.first);
          if (dStart > 5.0) updatedRoute.add(start);
          updatedRoute.addAll(validPoints);
          final dEnd = const Distance().as(LengthUnit.Meter, end, validPoints.last);
          if (dEnd > 5.0) updatedRoute.add(end);
        } else {
          updatedRoute.addAll([start, end]);
        }

        final dist = result['distance'] as double;
        final dur = result['duration'] as int;

        if (!mounted) return;
        setState(() {
          navRoutePoints = updatedRoute;
          navRouteDistance = dist;
          navRouteDuration = dur;
          navHasArrived = dist < 15.0;
        });
      }
    } catch (e) {
      debugPrint('NavigationMixin: Recalculation error: $e');
    } finally {
      _isRecalculating = false;
    }
  }

  // ── Refresh Route (for moving targets) ───────────────────

  /// Re-fetches the route when the target has moved significantly.
  /// Only triggers if the target moved > [thresholdMeters] from last known (default 40m).
  Future<void> refreshRouteIfNeeded({
    required LatLng currentPosition,
    required LatLng newTargetPosition,
    required MapController mapController,
    double thresholdMeters = 40.0,
  }) async {
    if (!mounted || !navIsNavigating || navTargetPosition == null || _isRecalculating) return;

    final dist = const Distance().as(
      LengthUnit.Meter,
      navTargetPosition!,
      newTargetPosition,
    );

    if (dist > thresholdMeters) {
      final now = DateTime.now();
      if (_lastRouteFetchTime != null &&
          now.difference(_lastRouteFetchTime!) < const Duration(seconds: 4)) {
        return; // Debounce rapid GPS updates
      }

      navTargetPosition = newTargetPosition;
      await _recalculateRoute(
        start: currentPosition,
        end: newTargetPosition,
        mapController: mapController,
      );
    }
  }

  // ── Update live navigation for user movement ─────────────

  /// Dynamically updates road distance and ETA along the route.
  /// If user deviates > 50m off the current route, triggers route recalculation.
  void updateNavForUserPosition({
    required LatLng currentPosition,
    MapController? mapController,
  }) {
    if (!mounted || !navIsNavigating || navTargetPosition == null || _isRecalculating) return;

    final target = navTargetPosition!;
    final directDist = const Distance().as(LengthUnit.Meter, currentPosition, target);

    // Arrival detection threshold (< 15 meters)
    if (directDist <= 15.0) {
      if (!navHasArrived && mounted) {
        setState(() {
          navHasArrived = true;
          navRouteDistance = directDist;
          navRouteDuration = 0;
        });
      }
      return;
    }

    if (navRoutePoints.isEmpty) {
      if (mounted) {
        setState(() {
          navRouteDistance = directDist;
          navRouteDuration = (directDist / ((navTravelMode == 'foot') ? 1.3 : 8.3)).round();
          navHasArrived = false;
        });
      }
      return;
    }

    // Find closest point along route polyline
    double minDistanceToRoute = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < navRoutePoints.length; i++) {
      final d = const Distance().as(LengthUnit.Meter, currentPosition, navRoutePoints[i]);
      if (d < minDistanceToRoute) {
        minDistanceToRoute = d;
        closestIndex = i;
      }
    }

    // Off-route check (> 50m off polyline)
    if (minDistanceToRoute > 50.0) {
      final now = DateTime.now();
      if (_lastRouteFetchTime == null ||
          now.difference(_lastRouteFetchTime!) > const Duration(seconds: 4)) {
        _recalculateRoute(
          start: currentPosition,
          end: target,
          mapController: mapController ?? _cachedMapController,
        );
      }
      return;
    }

    // Accumulate remaining road distance from closest point along polyline
    double remaining = const Distance().as(
      LengthUnit.Meter,
      currentPosition,
      navRoutePoints[closestIndex],
    );
    for (int i = closestIndex; i < navRoutePoints.length - 1; i++) {
      remaining += const Distance().as(
        LengthUnit.Meter,
        navRoutePoints[i],
        navRoutePoints[i + 1],
      );
    }

    final speedMps = (navTravelMode == 'foot') ? 1.3 : 8.3;
    final remainingSeconds = (remaining / speedMps).round();

    if (!mounted) return;
    setState(() {
      navRouteDistance = remaining;
      navRouteDuration = remainingSeconds > 0 ? remainingSeconds : 0;
      navHasArrived = remaining < 15.0;
    });
  }

  /// Backward compatible wrapper for [updateNavForUserPosition].
  void updateNavDistance(LatLng currentPosition) {
    updateNavForUserPosition(
      currentPosition: currentPosition,
      mapController: _cachedMapController,
    );
  }

  // ── Dispose ──────────────────────────────────────────────

  void disposeNavigation() {
    // Currently stateless — reserved for future timer cleanup.
  }

  // ── UI: Polyline Layer ───────────────────────────────────

  /// Returns a [PolylineLayer] to be added to [FlutterMap.children].
  /// Returns an empty layer when not navigating.
  PolylineLayer buildNavPolylineLayer() {
    if (!navIsNavigating || navRoutePoints.isEmpty) {
      return const PolylineLayer(polylines: []);
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: navRoutePoints,
          strokeWidth: 5.0,
          color: const Color(0xFF0D47A1), // Brand deep blue
        ),
      ],
    );
  }

  // ── UI: Navigation HUD ──────────────────────────────────

  /// Builds the floating navigation HUD card.
  /// [onRecenter] should re-center the map on the user.
  Widget buildNavigationHUD({
    required LatLng currentPosition,
    required MapController mapController,
    required VoidCallback onRecenter,
  }) {
    if (!navIsNavigating && !navIsLoading) {
      return const SizedBox.shrink();
    }

    if (navIsLoading) {
      return _buildLoadingHUD();
    }

    final bool isUnavailable =
        navRoutePoints.isEmpty && navRouteDistance <= 0.0 && !navHasArrived;

    final String distStr;
    final String etaStr;

    if (navHasArrived || navRouteDistance < 15.0) {
      distStr = 'Arrived';
      etaStr = '0 min';
    } else if (isUnavailable) {
      distStr = 'Route unavailable';
      etaStr = '--';
    } else if (navRouteDistance < 1000) {
      distStr = '${navRouteDistance.toStringAsFixed(0)} m';
      etaStr = _formatDuration(navRouteDuration);
    } else {
      distStr = '${(navRouteDistance / 1000).toStringAsFixed(1)} km';
      etaStr = _formatDuration(navRouteDuration);
    }
    final modeLabel =
        navTravelMode == 'foot' ? AppStrings.walkingMode : AppStrings.drivingMode;
    final modeIcon =
        navTravelMode == 'foot' ? Icons.directions_walk_rounded : Icons.directions_car_rounded;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target label row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFF0D47A1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppStrings.headingTo}:',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        navTargetLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Distance / ETA / Mode row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Distance
                  Icon(
                    navHasArrived
                        ? Icons.check_circle_rounded
                        : (isUnavailable
                            ? Icons.error_outline_rounded
                            : Icons.straighten_rounded),
                    size: 16,
                    color: navHasArrived
                        ? AppColors.success
                        : (isUnavailable
                            ? AppColors.error
                            : const Color(0xFF0D47A1)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    distStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: navHasArrived
                          ? AppColors.success
                          : (isUnavailable
                              ? AppColors.error
                              : const Color(0xFF0D47A1)),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 1,
                    height: 16,
                    color: AppColors.border,
                  ),
                  // ETA
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUnavailable
                        ? '--'
                        : (navHasArrived ? 'Arrived' : '~$etaStr $modeLabel'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // Travel mode toggle
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => switchTravelMode(
                      currentPosition: currentPosition,
                      mapController: mapController,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(modeIcon, size: 18, color: const Color(0xFF0D47A1)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action buttons: Recenter + End Route
            Row(
              children: [
                // Recenter button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRecenter,
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: const Text(AppStrings.recenterMap),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // End Route button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: endNavigation,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text(AppStrings.endNavigation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading HUD ──────────────────────────────────────────

  Widget _buildLoadingHUD() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF0D47A1),
              ),
            ),
            SizedBox(width: 14),
            Text(
              AppStrings.routeCalculating,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  void _fitCameraToRoute(
    MapController mapController,
    List<LatLng> points,
  ) {
    if (points.isEmpty) return;

    final valid = points.where((p) =>
        RoutingService.isValidCoordinate(p.latitude, p.longitude)).toList();
    if (valid.isEmpty) return;

    try {
      final bounds = LatLngBounds.fromPoints(valid);
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (_) {
      // Controller may not be ready yet — silently ignore
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '< 1 min';
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining > 0 ? '${hours}h ${remaining}m' : '${hours}h';
  }
}
