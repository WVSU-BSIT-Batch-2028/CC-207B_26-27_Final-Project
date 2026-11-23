import 'dart:convert';

import 'package:http/http.dart' as http;

class StrapiService {
  static const String baseUrl = String.fromEnvironment(
    'STRAPI_BASE_URL',
    defaultValue: 'http://localhost:1337',
  );

  static Future<List<Map<String, dynamic>>> fetchFoodItems() async {
    final url = Uri.parse('$baseUrl/api/food-items')
        .replace(queryParameters: {'populate': '*'});

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Strapi error: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    final List<dynamic> data = decoded['data'];

    return data
        .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
