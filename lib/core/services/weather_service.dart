import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // ── Location helper ─────────────────────────────────────────

  /// Gets real GPS on mobile; uses browser Geolocation API on web.
  static Future<({double lat, double lng})?> getDevicePosition() async {
    try {
      if (kIsWeb) {
        return await _getWebPosition();
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Browser Geolocation via Geolocator (works on Flutter Web too).
  static Future<({double lat, double lng})?> _getWebPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
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

    final city = cityName ?? (cur['name'] as String? ?? 'Unknown');
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

  // ── Convenience: auto-detect GPS ────────────────────────────

  /// Fetches weather using device GPS; falls back to Manila if unavailable.
  static Future<WeatherInfo> fetchWeather({
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    double lat = latitude ?? 14.5995;
    double lng = longitude ?? 120.9842;
    String? city = locationName;

    if (latitude == null && longitude == null) {
      final pos = await getDevicePosition();
      if (pos != null) {
        lat = pos.lat;
        lng = pos.lng;
      }
    }

    return fetchByCoords(lat: lat, lng: lng, cityName: city);
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
