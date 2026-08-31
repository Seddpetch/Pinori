import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/extracted_place.dart';

class AiService {
  static Future<ExtractedPlace> extractPlaceFromText(String input) async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/extract-place'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'input': input}),
    );

    if (response.statusCode != 200) {
      throw Exception('AI extraction failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return ExtractedPlace(
      name: data['name'] ?? '',
      city: data['city'],
      neighbourhood: data['neighbourhood'],
      nearestStation: data['nearestStation'],
      category: data['category'] ?? 'Other',
      address: data['address'],
      imageUrl: data['imageUrl'],
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static Future<String> getHeyGirlSuggestion({
    required String tripName,
    required String destination,
    required String localInsight,
    required List<Map<String, dynamic>> places,
  }) async {
    final response = await http.post(
      Uri.parse('http://localhost:3000/hey-girl'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripName': tripName,
        'destination': destination,
        'localInsight': localInsight,
        'places': places,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('HEY GIRL suggestion failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return data['suggestion']?.toString() ?? '';
  }
}
