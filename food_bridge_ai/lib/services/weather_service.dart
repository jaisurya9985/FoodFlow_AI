import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WeatherService {
  /// Fetches current temperature (Celsius) for a given lat/lng using Open-Meteo.
  /// No API key required. Returns null if fetching fails.
  static Future<double?> getCurrentTemperature(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data['current']['temperature_2m'] as num?;
        return temp?.toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
    return null;
  }
}
