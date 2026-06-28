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
  });
}

class HourlyForecast {
  final String time;
  final double tempC;
  final IconData icon;
  final String description;
  final String iconCode;

  const HourlyForecast({
    required this.time,
    required this.tempC,
    required this.icon,
    required this.description,
    required this.iconCode,
  });
}

class DailyForecast {
  final String dayName;
  final IconData icon;
  final double highC;
  final double lowC;
  final String description;
  final String iconCode;

  const DailyForecast({
    required this.dayName,
    required this.icon,
    required this.highC,
    required this.lowC,
    required this.description,
    required this.iconCode,
  });
}

// ── Service ─────────────────────────────────────────────────────

/// Service that uses OpenWeatherMap API to fetch live weather.
/// Uses One Call API 3.0 for current + hourly + daily data.
class WeatherService {
  WeatherService._();

  static const String _apiKey = 'a507040527cbd4f3789c88c18b8c32c3';
  static const String _currentUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String _forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';

  // ── Icon mapper ─────────────────────────────────────────────

  /// Maps OpenWeatherMap icon code to Flutter IconData.
  static IconData mapIcon(String iconCode) {
    final code = iconCode.replaceAll('n', 'd'); // day/night same icon
    switch (code) {
      case '01d':
        return Icons.wb_sunny_rounded;
      case '02d':
        return Icons.cloud_queue_rounded;
      case '03d':
      case '04d':
        return Icons.cloud_rounded;
      case '09d':
        return Icons.water_drop_rounded;
      case '10d':
        return Icons.umbrella_rounded;
      case '11d':
        return Icons.thunderstorm_rounded;
      case '13d':
        return Icons.ac_unit_rounded;
      case '50d':
        return Icons.filter_drama_rounded;
      default:
        return Icons.cloud_queue_rounded;
    }
  }

  /// Returns full URL to OWM icon PNG (50×50).
  static String iconUrl(String iconCode) =>
      'https://openweathermap.org/img/wn/$iconCode@2x.png';

  // ── Location helper ─────────────────────────────────────────

  /// Tries to get the device's real GPS position.
  /// Returns null if permissions are denied or unavailable.
  static Future<({double lat, double lng})?> _getDevicePosition() async {
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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  // ── Format time ─────────────────────────────────────────────

  static String _formatUnixTime(int unix, {int offsetSeconds = 0}) {
    final dt =
        DateTime.fromMillisecondsSinceEpoch((unix + offsetSeconds) * 1000,
            isUtc: true);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  // ── Main fetch ──────────────────────────────────────────────

  /// Fetches real-time weather using device GPS (or falls back to Manila).
  static Future<WeatherInfo> fetchWeather({
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    double lat = latitude ?? 14.5995;
    double lng = longitude ?? 120.9842;
    String city = locationName ?? 'Manila';

    // Try to auto-detect user's GPS if no coordinates supplied
    if (latitude == null && longitude == null) {
      final pos = await _getDevicePosition();
      if (pos != null) {
        lat = pos.lat;
        lng = pos.lng;
      }
    }

    // ── 1. Current weather ──────────────────────────────────
    final currentUri = Uri.parse(
        '$_currentUrl?lat=$lat&lon=$lng&units=metric&appid=$_apiKey');
    final currentResp = await http.get(currentUri);

    if (currentResp.statusCode != 200) {
      throw Exception(
          'OpenWeatherMap current error ${currentResp.statusCode}: ${currentResp.body}');
    }
    final cur = json.decode(currentResp.body) as Map<String, dynamic>;

    city = cur['name'] as String? ?? city;
    final countryCode = (cur['sys']?['country'] as String?) ?? 'PH';
    final timezoneOffset = cur['timezone'] as int? ?? 28800; // +8 Manila

    final curWeather = (cur['weather'] as List).first as Map<String, dynamic>;
    final curIconCode = curWeather['icon'] as String? ?? '01d';
    final curDesc = _capitalize(curWeather['description'] as String? ?? '');
    final main = cur['main'] as Map<String, dynamic>;
    final tempC = (main['temp'] as num).toDouble();
    final feelsLike = (main['feels_like'] as num).toDouble();
    final humidity = main['humidity'] as int? ?? 70;
    final highTemp = (main['temp_max'] as num).toDouble();
    final lowTemp = (main['temp_min'] as num).toDouble();
    final windSpeed = ((cur['wind']?['speed'] as num?) ?? 0).toDouble();
    final sunrise = _formatUnixTime(
        (cur['sys']?['sunrise'] as int?) ?? 0,
        offsetSeconds: timezoneOffset);
    final sunset = _formatUnixTime(
        (cur['sys']?['sunset'] as int?) ?? 0,
        offsetSeconds: timezoneOffset);

    // ── 2. 5-day / 3-hour forecast ─────────────────────────
    final forecastUri = Uri.parse(
        '$_forecastUrl?lat=$lat&lon=$lng&units=metric&cnt=40&appid=$_apiKey');
    final forecastResp = await http.get(forecastUri);

    if (forecastResp.statusCode != 200) {
      throw Exception(
          'OpenWeatherMap forecast error ${forecastResp.statusCode}');
    }
    final forecastData =
        json.decode(forecastResp.body) as Map<String, dynamic>;
    final forecastList = forecastData['list'] as List;

    // Hourly — next 8 entries (every 3h)
    final List<HourlyForecast> hourly = [];
    final now = DateTime.now();
    for (final item in forecastList) {
      if (hourly.length >= 8) break;
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (item['dt'] as int) * 1000);
      if (dt.isBefore(now.subtract(const Duration(minutes: 30)))) continue;

      final w = (item['weather'] as List).first as Map<String, dynamic>;
      final iconCode = w['icon'] as String? ?? '01d';
      final desc = _capitalize(w['description'] as String? ?? '');
      final t = (item['main']['temp'] as num).toDouble();

      final localDt = dt.toLocal();
      final h = localDt.hour % 12 == 0 ? 12 : localDt.hour % 12;
      final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
      final label = hourly.isEmpty ? 'Now' : '$h $ampm';

      hourly.add(HourlyForecast(
        time: label,
        tempC: t,
        icon: mapIcon(iconCode),
        description: desc,
        iconCode: iconCode,
      ));
    }

    // Daily — group by calendar day, pick first entry per day
    final Map<String, Map<String, dynamic>> dailyMap = {};
    for (final item in forecastList) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (item['dt'] as int) * 1000).toLocal();
      final key = '${dt.year}-${dt.month}-${dt.day}';
      if (!dailyMap.containsKey(key)) {
        dailyMap[key] = item as Map<String, dynamic>;
      }
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
      final w = (item['weather'] as List).first as Map<String, dynamic>;
      final iconCode = w['icon'] as String? ?? '01d';
      final desc = _capitalize(w['description'] as String? ?? '');
      final itemMain = item['main'] as Map<String, dynamic>;

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
        icon: mapIcon(iconCode),
        highC: (itemMain['temp_max'] as num).toDouble(),
        lowC: (itemMain['temp_min'] as num).toDouble(),
        description: desc,
        iconCode: iconCode,
      ));
      dayIdx++;
    }

    // Rain probability from today's forecast entries
    int rainProb = 0;
    for (final item in forecastList.take(8)) {
      final prob = ((item['pop'] as num?) ?? 0) * 100;
      if (prob.toInt() > rainProb) rainProb = prob.toInt();
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
      uvIndex: 0, // UV requires One Call API (paid tier); set to 0 gracefully
      sunrise: sunrise,
      sunset: sunset,
      hourly: hourly,
      daily: daily,
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
