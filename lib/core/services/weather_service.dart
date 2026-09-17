import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ── Models ──────────────────────────────────────────────────────

class WeatherInfo {
  final String locationName;
  final String country;
  final double tempC;
  final double feelsLike;
  final String description;
  final String iconCode;
  final double highTemp;
  final double lowTemp;
  final int humidity;
  final double windSpeed;
  final int rainProbability;
  final int uvIndex;
  final String sunrise;
  final String sunset;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final double lat;
  final double lng;
  final DateTime fetchedAt;

  const WeatherInfo({
    required this.locationName,
    required this.country,
    required this.tempC,
    required this.feelsLike,
    required this.description,
    required this.iconCode,
    required this.highTemp,
    required this.lowTemp,
    required this.humidity,
    required this.windSpeed,
    required this.rainProbability,
    required this.uvIndex,
    required this.sunrise,
    required this.sunset,
    required this.hourly,
    required this.daily,
    required this.lat,
    required this.lng,
    required this.fetchedAt,
  });
}

class HourlyForecast {
  final String time;
  final double tempC;
  final IconData icon;
  final String description;
  final String iconCode;
  final int pop; // precipitation probability 0-100

  const HourlyForecast({
    required this.time,
    required this.tempC,
    required this.icon,
    required this.description,
    required this.iconCode,
    required this.pop,
  });
}

class DailyForecast {
  final String dayName;
  final IconData icon;
  final double highC;
  final double lowC;
  final String description;
  final String iconCode;
  final int pop;

  const DailyForecast({
    required this.dayName,
    required this.icon,
    required this.highC,
    required this.lowC,
    required this.description,
    required this.iconCode,
    required this.pop,
  });
}

// ── Exceptions ──────────────────────────────────────────────────

class LocationServiceDisabledException implements Exception {
  final String message;
  const LocationServiceDisabledException([this.message = 'Location service is unavailable.']);
  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException([this.message = 'Enable location to view local weather.']);
  @override
  String toString() => message;
}

// ── Service ─────────────────────────────────────────────────────

/// Fully live weather service backed by OpenWeatherMap free-tier APIs:
///   - data/2.5/weather  → current conditions
///   - data/2.5/forecast → 3-hour / 5-day forecast
class WeatherService {
  WeatherService._();

  static const String _apiKey = 'a507040527cbd4f3789c88c18b8c32c3';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _geoUrl  = 'https://api.openweathermap.org/geo/1.0';

  // ── Icon mapper ─────────────────────────────────────────────

  static IconData mapIcon(String iconCode) {
    final code = iconCode.replaceAll('n', 'd');
    switch (code) {
      case '01d': return Icons.wb_sunny_rounded;
      case '02d': return Icons.cloud_queue_rounded;
      case '03d':
      case '04d': return Icons.cloud_rounded;
      case '09d': return Icons.water_drop_rounded;
      case '10d': return Icons.umbrella_rounded;
      case '11d': return Icons.thunderstorm_rounded;
      case '13d': return Icons.ac_unit_rounded;
      case '50d': return Icons.filter_drama_rounded;
      default:    return Icons.cloud_queue_rounded;
    }
  }

  /// Outline icons for sleek dashboard panel
  static IconData mapOutlineIcon(String iconCode) {
    final isNight = iconCode.endsWith('n');
    final code = iconCode.replaceAll('n', 'd');
    switch (code) {
      case '01d':
        return isNight ? Icons.nightlight_outlined : Icons.wb_sunny_outlined;
      case '02d':
        return isNight ? Icons.nights_stay_outlined : Icons.cloud_outlined;
      case '03d':
      case '04d':
        return Icons.cloud_outlined;
      case '09d':
        return Icons.water_drop_outlined;
      case '10d':
        return Icons.umbrella_outlined;
      case '11d':
        return Icons.thunderstorm_outlined;
      case '13d':
        return Icons.ac_unit_rounded;
      case '50d':
        return Icons.filter_drama_outlined;
      default:
        return Icons.cloud_outlined;
    }
  }

  /// Full OWM PNG icon URL (2x = 100×100).
  static String iconUrl(String iconCode) =>
      'https://openweathermap.org/img/wn/$iconCode@2x.png';

  // ── Geocoding: city name → coordinates ──────────────────────

  /// Returns coordinates for a city name. Throws if not found.
  static Future<({double lat, double lng, String city, String country})>
      geocodeCity(String cityName) async {
    final uri = Uri.parse(
        '$_geoUrl/direct?q=${Uri.encodeComponent(cityName)}&limit=1&appid=$_apiKey');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Geocoding failed: ${resp.statusCode}');
    }
    final list = json.decode(resp.body) as List;
    if (list.isEmpty) throw Exception('City "$cityName" not found.');
    final data = list.first as Map<String, dynamic>;
    return (
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lon'] as num).toDouble(),
      city: data['name'] as String,
      country: data['country'] as String,
    );
  }

  // ── Cache for current location weather ────────────────────────
  static WeatherInfo? _cachedWeather;
  static double? _cachedLat;
  static double? _cachedLng;
  static DateTime? _lastFetchTime;

  // ── Location helper ─────────────────────────────────────────

  /// Gets the user's current GPS position via [Geolocator].
  /// Throws [LocationServiceDisabledException] if GPS/location service is disabled.
  /// Throws [LocationPermissionDeniedException] if permission is not granted.
  static Future<({double lat, double lng})> getCurrentDevicePosition() async {
    // 1. Check if location service is enabled
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      serviceEnabled = true;
    }
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    // 2. Check and request location permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException();
    }

    // 3. Get device position
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  }

  /// Legacy helper returning null on failure (for tracking / map)
  static Future<({double lat, double lng})?> getDevicePosition() async {
    try {
      return await getCurrentDevicePosition();
    } catch (_) {
      return null;
    }
  }

  // ── Format helpers ──────────────────────────────────────────

  static String _formatUnixTime(int unix, {int offsetSeconds = 0}) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
        (unix + offsetSeconds) * 1000,
        isUtc: true);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Main fetch (by coordinates) ─────────────────────────────

  /// Fetches live weather for [lat]/[lng].
  /// Optionally override the displayed [cityName].
  static Future<WeatherInfo> fetchByCoords({
    required double lat,
    required double lng,
    String? cityName,
  }) async {
    // 1. Current weather
    final curUri = Uri.parse(
        '$_baseUrl/weather?lat=$lat&lon=$lng&units=metric&appid=$_apiKey');
    final curResp = await http.get(curUri);
    if (curResp.statusCode != 200) {
      throw Exception(
          'Weather error ${curResp.statusCode}: ${curResp.body}');
    }
    final cur = json.decode(curResp.body) as Map<String, dynamic>;

    String city = (cityName != null && cityName.isNotEmpty)
        ? cityName
        : (cur['name'] as String? ?? '').trim();

    // If city name is empty or unknown, reverse-geocode via OpenWeatherMap geo API
    if (city.isEmpty || city.toLowerCase() == 'unknown') {
      try {
        final revUri = Uri.parse(
            '$_geoUrl/reverse?lat=$lat&lon=$lng&limit=1&appid=$_apiKey');
        final revResp = await http.get(revUri);
        if (revResp.statusCode == 200) {
          final list = json.decode(revResp.body) as List;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            final revCity = (first['name'] as String? ?? '').trim();
            if (revCity.isNotEmpty) {
              city = revCity;
            }
          }
        }
      } catch (_) {}
    }
    if (city.isEmpty) {
      city = 'Current Location';
    }

    final countryCode = (cur['sys']?['country'] as String?) ?? 'PH';
    final timezoneOffset = cur['timezone'] as int? ?? 28800;

    final curWeather =
        (cur['weather'] as List).first as Map<String, dynamic>;
    final curIconCode = curWeather['icon'] as String? ?? '01d';
    final curDesc = _capitalize(
        curWeather['description'] as String? ?? '');
    final main = cur['main'] as Map<String, dynamic>;
    final tempC = (main['temp'] as num).toDouble();
    final feelsLike = (main['feels_like'] as num).toDouble();
    final humidity = main['humidity'] as int? ?? 70;
    final highTemp = (main['temp_max'] as num).toDouble();
    final lowTemp = (main['temp_min'] as num).toDouble();
    final windSpeed =
        ((cur['wind']?['speed'] as num?) ?? 0).toDouble();
    final sunrise = _formatUnixTime(
        (cur['sys']?['sunrise'] as int?) ?? 0,
        offsetSeconds: timezoneOffset);
    final sunset = _formatUnixTime(
        (cur['sys']?['sunset'] as int?) ?? 0,
        offsetSeconds: timezoneOffset);

    // 2. 5-day / 3-hour forecast (40 entries)
    final fcUri = Uri.parse(
        '$_baseUrl/forecast?lat=$lat&lon=$lng&units=metric&cnt=40&appid=$_apiKey');
    final fcResp = await http.get(fcUri);
    if (fcResp.statusCode != 200) {
      throw Exception('Forecast error ${fcResp.statusCode}');
    }
    final fcData =
        json.decode(fcResp.body) as Map<String, dynamic>;
    final fcList = fcData['list'] as List;

    // Hourly — next 8 entries starting from now
    final List<HourlyForecast> hourly = [];
    final now = DateTime.now();
    for (final item in fcList) {
      if (hourly.length >= 8) break;
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (item['dt'] as int) * 1000);
      if (dt.isBefore(now.subtract(const Duration(minutes: 30)))) continue;

      final w = (item['weather'] as List).first as Map<String, dynamic>;
      final ic = w['icon'] as String? ?? '01d';
      final desc = _capitalize(w['description'] as String? ?? '');
      final t = (item['main']['temp'] as num).toDouble();
      final pop = (((item['pop'] as num?) ?? 0) * 100).toInt();

      final localDt = dt.toLocal();
      final h = localDt.hour % 12 == 0 ? 12 : localDt.hour % 12;
      final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
      final label = hourly.isEmpty ? 'Now' : '$h $ampm';

      hourly.add(HourlyForecast(
        time: label,
        tempC: t,
        icon: mapIcon(ic),
        description: desc,
        iconCode: ic,
        pop: pop,
      ));
    }

    // Daily — one entry per calendar day, pick first per day
    final Map<String, Map<String, dynamic>> dailyMap = {};
    final Map<String, List<double>> dailyTemps = {};
    for (final item in fcList) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
              (item['dt'] as int) * 1000)
          .toLocal();
      final key = '${dt.year}-${dt.month}-${dt.day}';
      dailyMap.putIfAbsent(key, () => item as Map<String, dynamic>);
      dailyTemps.putIfAbsent(key, () => []);
      dailyTemps[key]!
          .add((item['main']['temp'] as num).toDouble());
    }

    final List<DailyForecast> daily = [];
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    int dayIdx = 0;
    for (final entry in dailyMap.entries) {
      if (daily.length >= 5) break;
      final parts = entry.key.split('-');
      final date = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final item = entry.value;
      final w =
          (item['weather'] as List).first as Map<String, dynamic>;
      final ic = w['icon'] as String? ?? '01d';
      final desc =
          _capitalize(w['description'] as String? ?? '');
      final temps = dailyTemps[entry.key]!;
      final pop = (((item['pop'] as num?) ?? 0) * 100).toInt();

      String dayLabel;
      if (dayIdx == 0) {
        dayLabel = 'Today';
      } else if (dayIdx == 1) {
        dayLabel = 'Tomorrow';
      } else {
        dayLabel = weekdays[date.weekday - 1];
      }

      daily.add(DailyForecast(
        dayName: dayLabel,
        icon: mapIcon(ic),
        highC: temps.reduce((a, b) => a > b ? a : b),
        lowC: temps.reduce((a, b) => a < b ? a : b),
        description: desc,
        iconCode: ic,
        pop: pop,
      ));
      dayIdx++;
    }

    // Max rain probability from next 8 forecast slots
    int rainProb = 0;
    for (final item in fcList.take(8)) {
      final prob = (((item['pop'] as num?) ?? 0) * 100).toInt();
      if (prob > rainProb) rainProb = prob;
    }

    return WeatherInfo(
      locationName: city,
      country: countryCode,
      tempC: tempC,
      feelsLike: feelsLike,
      description: curDesc,
      iconCode: curIconCode,
      highTemp: highTemp,
      lowTemp: lowTemp,
      humidity: humidity,
      windSpeed: windSpeed,
      rainProbability: rainProb,
      uvIndex: 0,
      sunrise: sunrise,
      sunset: sunset,
      hourly: hourly,
      daily: daily,
      lat: lat,
      lng: lng,
      fetchedAt: DateTime.now(),
    );
  }

  // ── Convenience: GPS weather with caching ────────────────────

  /// Fetches weather using the user's current GPS location.
  /// If [latitude] and [longitude] are provided, fetches for those coordinates.
  /// Otherwise, retrieves the device's physical GPS location.
  /// Throws [LocationServiceDisabledException] or [LocationPermissionDeniedException]
  /// if location is unavailable or denied.
  static Future<WeatherInfo> fetchWeather({
    double? latitude,
    double? longitude,
    String? locationName,
    bool forceRefresh = false,
  }) async {
    if (latitude != null && longitude != null) {
      return fetchByCoords(lat: latitude, lng: longitude, cityName: locationName);
    }

    // Must use user's physical GPS location
    final pos = await getCurrentDevicePosition();

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedWeather != null &&
        _lastFetchTime != null &&
        _cachedLat != null &&
        _cachedLng != null &&
        now.difference(_lastFetchTime!).inMinutes < 10) {
      final dist = Geolocator.distanceBetween(
          _cachedLat!, _cachedLng!, pos.lat, pos.lng);
      if (dist < 1000) {
        return _cachedWeather!;
      }
    }

    final info = await fetchByCoords(
      lat: pos.lat,
      lng: pos.lng,
      cityName: locationName,
    );

    _cachedWeather = info;
    _cachedLat = pos.lat;
    _cachedLng = pos.lng;
    _lastFetchTime = now;
    return info;
  }

  // ── City search suggestions ──────────────────────────────────

  /// Returns up to [limit] city suggestions for the given partial name.
  static Future<List<Map<String, dynamic>>> searchCities(
      String query, {int limit = 5}) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.parse(
        '$_geoUrl/direct?q=${Uri.encodeComponent(query)}&limit=$limit&appid=$_apiKey');
    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];
      final list = json.decode(resp.body) as List;
      return list
          .map((e) => {
                'name': e['name'] as String,
                'country': e['country'] as String,
                'state': (e['state'] as String?) ?? '',
                'lat': (e['lat'] as num).toDouble(),
                'lng': (e['lon'] as num).toDouble(),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }
}
