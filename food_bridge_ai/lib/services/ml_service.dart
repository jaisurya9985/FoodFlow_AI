import 'dart:convert';
import 'package:http/http.dart' as http;

class MLService {
  static String baseUrl = _normalizeBaseUrl(
    const String.fromEnvironment(
      'ML_SERVER_URL',
      defaultValue: 'https://foodflow-ai-mlaa.onrender.com',
    ),
  );

  static void setBaseUrl(String url) {
    baseUrl = _normalizeBaseUrl(url);
  }

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    final withScheme = trimmed.startsWith('http') ? trimmed : 'http://$trimmed';
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }

  static Future<Map<String, dynamic>> predictFoodRisk({
    required String category,
    required double storageTemperatureC,
    required double maxFridgeDays,
    required double timeSinceCooked,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/predict/food-risk'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'category': category,
              'storage_temperature_C': storageTemperatureC,
              'max_fridge_days': maxFridgeDays,
              'time_since_cooked': timeSinceCooked,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return _fallbackRisk(category, storageTemperatureC, timeSinceCooked, maxFridgeDays);
    } catch (_) {
      return _fallbackRisk(category, storageTemperatureC, timeSinceCooked, maxFridgeDays);
    }
  }

  static Future<List<dynamic>> matchVolunteers({
    required double pickupLat,
    required double pickupLng,
    required double foodWeightKg,
    required int riskScore,
    required double expiryHours,
    required List<Map<String, dynamic>> volunteers,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/predict/volunteer-match'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pickup_lat': pickupLat,
              'pickup_lng': pickupLng,
              'food_weight_kg': foodWeightKg,
              'risk_score': riskScore,
              'expiry_hours': expiryHours,
              'volunteers': volunteers,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['matches'] as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _fallbackRisk(
      String category, double temp, double timeSinceCooked, double maxFridgeDays) {
    
    final totalShelfHours = maxFridgeDays > 0 ? maxFridgeDays * 24 : 12.0;
    final shelfUsedRatio = timeSinceCooked / totalShelfHours;

    final isPerishable = category == 'cooked_meal' || category == 'dairy';

    double tempDangerScore = 0.0;
    if (temp > 35) {
      tempDangerScore = 0.8;
    } else if (temp > 25) {
      tempDangerScore = 0.5;
    } else if (temp > 15) {
      tempDangerScore = 0.2;
    }

    double perishableExposureScore = 0.0;
    if (isPerishable && temp > 10) {
      final safeHours = temp < 30 ? 4.0 : 2.0;
      perishableExposureScore = timeSinceCooked / safeHours;
    }

    double combined = (shelfUsedRatio * 0.4) + (tempDangerScore * 0.3) + (perishableExposureScore * 0.6);

    if (isPerishable && timeSinceCooked > 6.0 && temp > 20) {
      if (combined < 1.0) combined = 1.0;
    }

    if (shelfUsedRatio >= 1.0) {
      if (combined < 1.0) combined = 1.0;
    }

    if (combined >= 1.0) {
      return {'risk': 3, 'risk_label': 'SPOILED', 'confidence': 92.0, 'expiry_minutes': 0};
    } else if (combined >= 0.75) {
      return {'risk': 2, 'risk_label': 'HIGH', 'confidence': 80.0, 'expiry_minutes': 60};
    } else if (combined >= 0.4) {
      return {'risk': 1, 'risk_label': 'MEDIUM', 'confidence': 75.0, 'expiry_minutes': 240};
    } else {
      return {'risk': 0, 'risk_label': 'LOW', 'confidence': 85.0, 'expiry_minutes': 720};
    }
  }
}
