
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food.dart';

class StrapiService {
  static const String baseUrl = String.fromEnvironment(
    'STRAPI_BASE_URL',
    defaultValue: 'http://localhost:1337',
  );

  static Future<List<Food>> fetchFoodItems() async {
    final url = Uri.parse('$baseUrl/api/food-items').replace(
      queryParameters: {'populate': '*'},
    );

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    // Validate HTTP status BEFORE decoding the response.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        404 => 'Food items endpoint not found (404).',
        500 => 'Strapi server error (500). Please try again later.',
        _ => 'Failed to load food items. HTTP status: ${response.statusCode}.',
      };

      throw Exception(message);
    }

    // Decode the response only if the HTTP request was successful.
    final decoded = jsonDecode(response.body);
    final List<dynamic> data = decoded['data'];

    return data
        .map<Food>(
          (item) => Food.fromJson(
            Map<String, dynamic>.from(item),
            baseUrl,
          ),
        )
        .toList();
  }
}