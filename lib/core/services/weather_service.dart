import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Models for weather representation.
class WeatherInfo {
  final String locationName;
  final double tempC;
  final String description;
  final double highTemp;
  final double lowTemp;
  final int rainProbability;
  final int humidity;
  final double windSpeed;
  final double feelsLike;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  const WeatherInfo({
    required this.locationName,
    required this.tempC,
    required this.description,
    required this.highTemp,
    required this.lowTemp,
    required this.rainProbability,
    required this.humidity,
    required this.windSpeed,
    required this.feelsLike,
    required this.hourly,
    required this.daily,
  });
}

class HourlyForecast {
  final String time;
  final double tempC;
  final IconData icon;
  final String description;

  const HourlyForecast({
    required this.time,
    required this.tempC,
    required this.icon,
    required this.description,
  });
}

class DailyForecast {
  final String dayName;
  final IconData icon;
  final double highC;
  final double lowC;
  final String description;

  const DailyForecast({
    required this.dayName,
    required this.icon,
    required this.highC,
    required this.lowC,
    required this.description,
  });
}

/// Service that interacts with Open-Meteo to fetch live weather data.
class WeatherService {
  WeatherService._();

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Maps WMO Weather Code to Description and IconData.
  static (String, IconData) _mapWeatherCode(int code) {
    switch (code) {
      case 0:
        return ('Clear Sky', Icons.wb_sunny_rounded);
      case 1:
      case 2:
      case 3:
        return ('Partly Cloudy', Icons.cloud_queue_rounded);
      case 45:
      case 48:
        return ('Foggy', Icons.filter_drama_rounded);
      case 51:
      case 53:
      case 55:
        return ('Drizzle', Icons.water_drop_rounded);
      case 61:
      case 63:
      case 65:
        return ('Rainy', Icons.water_drop_rounded);
      case 71:
      case 73:
      case 75:
        return ('Snowy', Icons.ac_unit_rounded);
      case 80:
      case 81:
      case 82:
        return ('Showers', Icons.water_drop_rounded);
      case 95:
      case 96:
      case 99:
        return ('Thunderstorm', Icons.thunderstorm_rounded);
      default:
        return ('Cloudy', Icons.cloud_rounded);
    }
  }

  /// Fetches real-time weather information for given coordinates.
  /// Defaults to Manila, Philippines coordinates.
  static Future<WeatherInfo> fetchWeather({
    double latitude = 14.5995,
    double longitude = 120.9842,
    String locationName = 'Manila, Philippines',
  }) async {
    final url = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m'
        '&hourly=temperature_2m,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
        '&timezone=Asia%2FManila');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch weather data: ${response.body}');
    }

    final data = json.decode(response.body);

    final current = data['current'];
    final hourlyData = data['hourly'];
    final dailyData = data['daily'];

    // Map current
    final currentCode = current['weather_code'] as int? ?? 0;
    final (desc, icon) = _mapWeatherCode(currentCode);

    // Map hourly (limit to next 8 hours for display)
    final List<HourlyForecast> hourlyList = [];
    final nowHour = DateTime.now().hour;
    final timeList = hourlyData['time'] as List;
    final temp2mList = hourlyData['temperature_2m'] as List;
    final codeList = hourlyData['weather_code'] as List;

    for (int i = 0; i < timeList.length; i++) {
      final dateTime = DateTime.parse(timeList[i] as String);
      // Only keep forecast starting from this hour
      if (dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 1)))) {
        final (hDesc, hIcon) = _mapWeatherCode(codeList[i] as int? ?? 0);
        final hourStr = dateTime.hour == nowHour
            ? 'Now'
            : '${dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour)} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
        hourlyList.add(HourlyForecast(
          time: hourStr,
          tempC: (temp2mList[i] as num).toDouble(),
          icon: hIcon,
          description: hDesc,
        ));
        if (hourlyList.length >= 8) break; // 8 hours is enough for UI
      }
    }

    // Map daily (limit to 3 days)
    final List<DailyForecast> dailyList = [];
    final dTimeList = dailyData['time'] as List;
    final dMaxTempList = dailyData['temperature_2m_max'] as List;
    final dMinTempList = dailyData['temperature_2m_min'] as List;
    final dCodeList = dailyData['weather_code'] as List;

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (int i = 0; i < dTimeList.length; i++) {
      final date = DateTime.parse(dTimeList[i] as String);
      final (dDesc, dIcon) = _mapWeatherCode(dCodeList[i] as int? ?? 0);
      
      String dayLabel;
      if (i == 0) {
        dayLabel = 'Today';
      } else if (i == 1) {
        dayLabel = 'Tomorrow';
      } else {
        dayLabel = weekdays[date.weekday - 1];
      }

      dailyList.add(DailyForecast(
        dayName: dayLabel,
        icon: dIcon,
        highC: (dMaxTempList[i] as num).toDouble(),
        lowC: (dMinTempList[i] as num).toDouble(),
        description: dDesc,
      ));
      if (dailyList.length >= 3) break;
    }

    final rainProb = (dailyData['precipitation_probability_max'] as List).first as int? ?? 0;

    return WeatherInfo(
      locationName: locationName,
      tempC: (current['temperature_2m'] as num).toDouble(),
      description: desc,
      highTemp: (dailyData['temperature_2m_max'] as List).first as double? ?? 31.0,
      lowTemp: (dailyData['temperature_2m_min'] as List).first as double? ?? 24.0,
      rainProbability: rainProb,
      humidity: current['relative_humidity_2m'] as int? ?? 70,
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      hourly: hourlyList,
      daily: dailyList,
    );
  }
}
