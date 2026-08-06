import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/weather_service.dart';

/// Fully dynamic Weather screen (US-17).
///
/// Features:
///  • Live GPS-based weather on open (device location)
///  • City search with autocomplete (OWM Geocoding API)
///  • Auto-refresh every 10 minutes
///  • Hourly (8-slot) & 5-day forecast with rain probability
///  • Sunrise / Sunset, humidity, wind, feels-like
///  • Weather advisory for high rain probability
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

  // City search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showSearch = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  Timer? _autoRefresh;

  // Currently shown city (null = GPS location)
  String? _pinnedCity;
  double? _pinnedLat;
  double? _pinnedLng;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadWeather();

    // Auto-refresh every 10 minutes
    _autoRefresh = Timer.periodic(const Duration(minutes: 10), (_) {
      _loadWeather(silent: true);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _autoRefresh?.cancel();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────

  void _loadWeather({bool silent = false}) {
    if (!silent) {
      _fadeController.reset();
      _fadeController.forward();
    }
    setState(() {
      if (_pinnedLat != null && _pinnedLng != null) {
        _weatherFuture = WeatherService.fetchByCoords(
          lat: _pinnedLat!,
          lng: _pinnedLng!,
          cityName: _pinnedCity,
        );
      } else {
        _weatherFuture = WeatherService.fetchWeather();
      }
    });
  }

  void _resetToGPS() {
    setState(() {
      _pinnedCity = null;
      _pinnedLat = null;
      _pinnedLng = null;
    });
    _loadWeather();
  }

  // ── Search ───────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await WeatherService.searchCities(q);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectCity(Map<String, dynamic> city) {
    setState(() {
      _pinnedCity = city['name'] as String;
      _pinnedLat = city['lat'] as double;
      _pinnedLng = city['lng'] as double;
      _showSearch = false;
      _suggestions = [];
      _searchController.clear();
    });
    _loadWeather();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _suggestions = [];
        _searchController.clear();
      }
    });
    if (_showSearch) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _searchFocus.requestFocus();
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: _pinnedCity != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_city_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _pinnedCity!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            : const Text('Weather'),
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          if (_pinnedCity != null)
            IconButton(
              tooltip: 'Use My Location',
              icon: const Icon(Icons.my_location_rounded,
                  color: AppColors.primary),
              onPressed: _resetToGPS,
            ),
          IconButton(
            tooltip: 'Search City',
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.primary,
            ),
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => _loadWeather(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _showSearch ? _buildSearchBar() : const SizedBox.shrink(),
          ),
          // Suggestions
          if (_suggestions.isNotEmpty)
            _buildSuggestions(),
          // Weather content
          Expanded(
            child: FutureBuilder<WeatherInfo>(
              future: _weatherFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                final weather = snapshot.data!;
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: () async => _loadWeather(),
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCurrentCard(weather),
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
                          const SizedBox(height: 20),
                          _buildLastUpdated(weather),
                          const SizedBox(height: 8),
                          _buildPoweredBy(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search city (e.g. Cebu, Davao, Boracay)...',
          hintStyle:
              const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : const Icon(Icons.search_rounded,
                  color: AppColors.textHint, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textHint, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _suggestions = []);
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: AppColors.surface,
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 56),
        itemBuilder: (_, i) {
          final city = _suggestions[i];
          final state = city['state'] as String;
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_city_rounded,
                  color: AppColors.primary, size: 18),
            ),
            title: Text(city['name'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            subtitle: Text(
              state.isNotEmpty
                  ? '$state, ${city['country']}'
                  : city['country'] as String,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            onTap: () => _selectCity(city),
          );
        },
      ),
    );
  }

  // ── Loading / Error ──────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Fetching live weather...',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError(String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Failed to load weather',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(err,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadWeather,
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

  // ── Current Weather Card ─────────────────────────────────────

  Widget _buildCurrentCard(WeatherInfo w) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                    // Location chip
                    GestureDetector(
                      onTap: _toggleSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${w.locationName}, ${w.country}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70, size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Temperature
                    Text(
                      '${w.tempC.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      w.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Weather icon
              _buildWeatherIcon(w.iconCode, size: 90),
            ],
          ),
          const SizedBox(height: 20),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat(Icons.arrow_upward_rounded, 'High',
                    '${w.highTemp.toStringAsFixed(0)}°'),
                Container(width: 1, height: 24, color: Colors.white24),
                _miniStat(Icons.arrow_downward_rounded, 'Low',
                    '${w.lowTemp.toStringAsFixed(0)}°'),
                Container(width: 1, height: 24, color: Colors.white24),
                _miniStat(Icons.water_drop_outlined, 'Rain',
                    '${w.rainProbability}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherIcon(String iconCode, {double size = 60}) {
    return Image.network(
      WeatherService.iconUrl(iconCode),
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(
        WeatherService.mapIcon(iconCode),
        size: size * 0.8,
        color: Colors.white,
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
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
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

  Widget _buildWeatherAlert(WeatherInfo w) {
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
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'High precipitation probability (${w.rainProbability}%). Consider adjusting outdoor activities.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning.withValues(alpha: 0.8),
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

  Widget _buildDetailTiles(WeatherInfo w) {
    return Row(
      children: [
        _tile(Icons.water_drop_rounded, 'Humidity',
            '${w.humidity}%', AppColors.info),
        const SizedBox(width: 12),
        _tile(Icons.air_rounded, 'Wind',
            '${w.windSpeed.toStringAsFixed(1)} m/s', AppColors.primary),
        const SizedBox(width: 12),
        _tile(Icons.thermostat_rounded, 'Feels Like',
            '${w.feelsLike.toStringAsFixed(0)}°C', AppColors.accent),
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
                    fontSize: 15,
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

  Widget _buildSunriseSunset(WeatherInfo w) {
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
          _sunItem(Icons.wb_twilight_rounded, 'Sunrise', w.sunrise,
              AppColors.accent),
          Container(width: 1, height: 40, color: AppColors.border),
          _sunItem(Icons.nights_stay_rounded, 'Sunset', w.sunset,
              AppColors.accentTeal),
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

  Widget _buildHourlyForecast(WeatherInfo w) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: w.hourly.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final h = w.hourly[i];
          final isNow = i == 0;
          return Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isNow ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
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
                Image.network(
                  WeatherService.iconUrl(h.iconCode),
                  width: 36,
                  height: 36,
                  errorBuilder: (_, __, ___) => Icon(
                    h.icon,
                    size: 24,
                    color: isNow ? Colors.white : AppColors.primary,
                  ),
                ),
                Text(
                  '${h.tempC.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isNow ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                // Rain probability
                if (h.pop > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_rounded,
                          size: 10,
                          color: isNow
                              ? Colors.white70
                              : AppColors.info),
                      const SizedBox(width: 2),
                      Text(
                        '${h.pop}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: isNow
                              ? Colors.white70
                              : AppColors.info,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 14),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Daily Forecast ────────────────────────────────────────────

  Widget _buildDailyForecast(WeatherInfo w) {
    return Column(
      children: w.daily.map((d) {
        Color dColor = AppColors.primary;
        final desc = d.description.toLowerCase();
        if (desc.contains('rain') ||
            desc.contains('drizzle') ||
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (d.pop > 0)
                      Row(
                        children: [
                          const Icon(Icons.water_drop_rounded,
                              size: 11, color: AppColors.info),
                          const SizedBox(width: 2),
                          Text('${d.pop}%',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.info)),
                        ],
                      ),
                  ],
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

  // ── Footer ────────────────────────────────────────────────────

  Widget _buildLastUpdated(WeatherInfo w) {
    final now = w.fetchedAt;
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update_rounded,
              size: 13, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            'Last updated at $time',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildPoweredBy() {
    return Center(
      child: Text(
        'Powered by OpenWeatherMap',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textHint.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
