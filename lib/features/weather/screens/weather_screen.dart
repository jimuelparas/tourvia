import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/weather_service.dart';

/// Screen for Real-Time Weather Updates (US-17).
///
/// Powered by OpenWeatherMap API — shows current weather with real GPS location,
/// 8-hour forecast, 5-day outlook, sunrise/sunset, and weather advisory.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late Future<WeatherInfo> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = WeatherService.fetchWeather();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _weatherFuture = WeatherService.fetchWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weather'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<WeatherInfo>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 56, color: AppColors.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load weather',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final weather = snapshot.data!;
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentWeatherCard(weather),
                  if (weather.rainProbability > 50) ...[
                    const SizedBox(height: 16),
                    _buildWeatherAlert(weather),
                  ],
                  const SizedBox(height: 20),
                  _buildDetailTiles(weather),
                  const SizedBox(height: 16),
                  _buildSunriseSunset(weather),
                  const SizedBox(height: 28),
                  _buildSectionTitle('8-Hour Forecast'),
                  const SizedBox(height: 12),
                  _buildHourlyForecast(weather),
                  const SizedBox(height: 28),
                  _buildSectionTitle('5-Day Outlook'),
                  const SizedBox(height: 12),
                  _buildDailyForecast(weather),
                  const SizedBox(height: 24),
                  _buildPoweredBy(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Current Weather Card ─────────────────────────────────────
  Widget _buildCurrentWeatherCard(WeatherInfo weather) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00A9E0), Color(0xFF0077B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A9E0).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${weather.locationName}, ${weather.country}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Temperature
                    Text(
                      '${weather.tempC.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 68,
                        fontWeight: FontWeight.w200,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weather.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // OWM Weather Icon
              Image.network(
                WeatherService.iconUrl(weather.iconCode),
                width: 80,
                height: 80,
                errorBuilder: (_, __, ___) => Icon(
                  WeatherService.mapIcon(weather.iconCode),
                  size: 70,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // H/L/Rain stat row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat(Icons.arrow_upward_rounded, 'High',
                    '${weather.highTemp.toStringAsFixed(0)}°'),
                Container(width: 1, height: 24, color: Colors.white24),
                _miniStat(Icons.arrow_downward_rounded, 'Low',
                    '${weather.lowTemp.toStringAsFixed(0)}°'),
                Container(width: 1, height: 24, color: Colors.white24),
                _miniStat(Icons.water_drop_outlined, 'Rain',
                    '${weather.rainProbability}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // ── Weather Advisory ─────────────────────────────────────────
  Widget _buildWeatherAlert(WeatherInfo weather) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather Advisory',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'High precipitation probability (${weather.rainProbability}%). Consider adjusting outdoor activities.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        const Color(0xFF92400E).withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail Tiles ─────────────────────────────────────────────
  Widget _buildDetailTiles(WeatherInfo weather) {
    return Row(
      children: [
        _tile(Icons.water_drop_rounded, 'Humidity',
            '${weather.humidity}%', AppColors.info),
        const SizedBox(width: 12),
        _tile(Icons.air_rounded, 'Wind',
            '${weather.windSpeed.toStringAsFixed(1)} m/s', AppColors.primary),
        const SizedBox(width: 12),
        _tile(Icons.thermostat_rounded, 'Feels Like',
            '${weather.feelsLike.toStringAsFixed(0)}°C', AppColors.accent),
      ],
    );
  }

  Widget _tile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Sunrise / Sunset ─────────────────────────────────────────
  Widget _buildSunriseSunset(WeatherInfo weather) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sunItem(Icons.wb_twilight_rounded, 'Sunrise', weather.sunrise,
              const Color(0xFFF59E0B)),
          Container(width: 1, height: 40, color: AppColors.border),
          _sunItem(Icons.nights_stay_rounded, 'Sunset', weather.sunset,
              const Color(0xFF6366F1)),
        ],
      ),
    );
  }

  Widget _sunItem(IconData icon, String label, String time, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textHint)),
            Text(time,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  // ── Section Title ─────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── Hourly Forecast ───────────────────────────────────────────
  Widget _buildHourlyForecast(WeatherInfo weather) {
    return SizedBox(
      height: 115,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weather.hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final h = weather.hourly[i];
          final isNow = i == 0;
          return Container(
            width: 72,
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isNow ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isNow ? AppColors.primary : AppColors.border,
              ),
              boxShadow: isNow
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  h.time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isNow ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                // OWM icon image
                Image.network(
                  WeatherService.iconUrl(h.iconCode),
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) =>
                      Icon(h.icon, size: 24,
                          color: isNow ? Colors.white : AppColors.primary),
                ),
                Text(
                  '${h.tempC.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isNow ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Daily Forecast ────────────────────────────────────────────
  Widget _buildDailyForecast(WeatherInfo weather) {
    return Column(
      children: weather.daily.map((d) {
        Color dColor = AppColors.primary;
        final desc = d.description.toLowerCase();
        if (desc.contains('rain') || desc.contains('drizzle') ||
            desc.contains('shower')) {
          dColor = AppColors.info;
        } else if (desc.contains('thunder') || desc.contains('storm')) {
          dColor = AppColors.error;
        } else if (desc.contains('cloud')) {
          dColor = AppColors.textHint;
        } else if (desc.contains('sun') || desc.contains('clear')) {
          dColor = AppColors.accent;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  d.dayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Image.network(
                WeatherService.iconUrl(d.iconCode),
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) =>
                    Icon(d.icon, color: dColor, size: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${d.highC.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${d.lowC.toStringAsFixed(0)}°',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textHint),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Powered by footer ─────────────────────────────────────────
  Widget _buildPoweredBy() {
    return Center(
      child: Text(
        'Powered by OpenWeatherMap',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textHint.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
