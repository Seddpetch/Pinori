import 'package:hive_ce/hive.dart';

import '../models/place.dart';

class PlaceStorageService {
  static const String _placeBoxName = 'places';

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PlaceAdapter());
    }

    await Hive.openBox<Place>(_placeBoxName);
  }

  static Box<Place> get _placeBox => Hive.box<Place>(_placeBoxName);

  static List<Place> getAllPlaces() {
    return _placeBox.values.toList();
  }

  static List<Place> getPlacesForTrip(String tripId) {
    return _placeBox.values.where((place) => place.tripId == tripId).toList();
  }

  static Future<void> savePlace(Place place) async {
    await _placeBox.put(place.id, place);
  }

  static Future<void> deletePlace(String placeId) async {
    await _placeBox.delete(placeId);
  }

  static Future<void> deletePlacesForTrip(String tripId) async {
    final placeIds = _placeBox.values
        .where((place) => place.tripId == tripId)
        .map((place) => place.id)
        .toList();

    await _placeBox.deleteAll(placeIds);
  }
}
