import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;

import '../services/weather_service.dart';
import '../theme/app_colors.dart';
import '../../features/weather/screens/weather_screen.dart';

/// Compact weather panel for dashboard tops.
///
/// Uses the device/user's CURRENT physical GPS location.
/// Shows: current detected location, temperature, weather condition, outline icon, rain %.
/// Tapping navigates to the full [WeatherScreen].
/// Auto-refreshes every 10 minutes.
class WeatherPanel extends StatefulWidget {
  const WeatherPanel({super.key});

  @override
  State<WeatherPanel> createState() => _WeatherPanelState();
}

class _WeatherPanelState extends State<WeatherPanel> {
  late Future<WeatherInfo> _weatherFuture;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _weatherFuture = WeatherService.fetchWeather();
    _autoRefresh = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        setState(() {
          _weatherFuture = WeatherService.fetchWeather();
        });
      }
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  void _refreshWeather() {
    if (!mounted) return;
    setState(() {
      _weatherFuture = WeatherService.fetchWeather(forceRefresh: true);
    });
  }

  Future<void> _requestPermissionAndRefresh() async {
    try {
      await Geolocator.requestPermission();
    } catch (_) {}
    _refreshWeather();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherInfo>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeleton();
        }

        if (snapshot.hasError) {
          final err = snapshot.error;
          if (err is LocationPermissionDeniedException) {
            return _buildStatusState(
              icon: Icons.location_off_outlined,
              message: 'Enable location to view local weather.',
              actionLabel: 'Enable',
              onTap: _requestPermissionAndRefresh,
            );
          }
          if (err is LocationServiceDisabledException) {
            return _buildStatusState(
              icon: Icons.location_disabled_outlined,
              message: 'Location service is unavailable.',
              actionLabel: 'Retry',
              onTap: _refreshWeather,
            );
          }
          return _buildStatusState(
            icon: Icons.cloud_off_outlined,
            message: 'Weather unavailable',
            actionLabel: 'Retry',
            onTap: _refreshWeather,
          );
        }

        if (!snapshot.hasData) {
          return _buildStatusState(
            icon: Icons.cloud_off_outlined,
            message: 'Weather unavailable',
            actionLabel: 'Retry',
            onTap: _refreshWeather,
          );
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeatherScreen()),
          ),
          child: _buildWeatherCard(snapshot.data!),
        );
      },
    );
  }

  Widget _buildWeatherCard(WeatherInfo weather) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // White outline weather icon
          Icon(
            WeatherService.mapOutlineIcon(weather.iconCode),
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(width: 14),
          // Location and Temp • Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weather.locationName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${weather.tempC.round()}°C  •  ${weather.description}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Rain pill badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Rain ${weather.rainProbability}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined, color: Colors.black26, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: 75,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionLabel == 'Retry') ...[
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                  ] else ...[
                    const Icon(Icons.near_me_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
}
