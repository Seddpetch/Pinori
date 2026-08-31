import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class GeocodingService {
  static Future<LatLng?> findCoordinates(
    String query, {
    String? destination,
  }) async {
    final cleanedQuery = query
        .replaceAll(
          RegExp(
            r'\b(B\d+|\d+F|\d+(st|nd|rd|th)\s+Floor|Floor\s+\d+|Unit\s+\w+|Suite\s+\w+|Rooftop|\d+층)\b\s*,?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    final addressParts = cleanedQuery
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final streetIndex = addressParts.indexWhere(
      (part) => RegExp(
        r'\d+\s+.*(?:-ro|-gil|-daero)\b',
        caseSensitive: false,
      ).hasMatch(part),
    );

    final streetFirstQuery = streetIndex >= 0
        ? addressParts.sublist(streetIndex).join(', ')
        : cleanedQuery;

    final cleanDestination = destination?.trim() ?? '';

    final queryAlreadyHasDestination =
        cleanDestination.isNotEmpty &&
        cleanedQuery.toLowerCase().contains(cleanDestination.toLowerCase());

    final destinationAwareQuery =
        cleanDestination.isNotEmpty && !queryAlreadyHasDestination
        ? '$cleanedQuery, $cleanDestination'
        : cleanedQuery;

    final searches = [
      destinationAwareQuery,
      query,
      cleanedQuery,
      streetFirstQuery,
    ];

    for (final search in searches) {
      debugPrint('Trying geocode: $search');

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': search,
        'format': 'jsonv2',
        'limit': '1',
        'accept-language': 'en',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Pinori/0.1 personal travel app'},
      );

      if (response.statusCode != 200) {
        continue;
      }

      final results = jsonDecode(response.body) as List;

      if (results.isEmpty) {
        continue;
      }

      final result = results.first as Map<String, dynamic>;

      final latitude = double.tryParse(result['lat'].toString());

      final longitude = double.tryParse(result['lon'].toString());

      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }

    debugPrint('No location found for any version of: $query');

    return null;
  }

  static Future<LatLng?> findCoordinatesKorea({
    required String name,
    required String address,
  }) async {
    try {
      debugPrint('Trying Kakao geocode: $name | $address');

      final response = await http.post(
        Uri.parse('https://pinori-backend.onrender.com/geocode-korea'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'address': address}),
      );

      if (response.statusCode != 200) {
        debugPrint('Kakao geocode failed: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['found'] != true) {
        debugPrint('Kakao could not find the place');
        return null;
      }

      final latitude = (data['latitude'] as num?)?.toDouble();

      final longitude = (data['longitude'] as num?)?.toDouble();

      if (latitude == null || longitude == null) {
        return null;
      }

      debugPrint(
        'Kakao found coordinates: '
        '$latitude, $longitude',
      );

      return LatLng(latitude, longitude);
    } catch (error) {
      debugPrint('Kakao geocoding error: $error');

      return null;
    }
  }
}
