import 'package:hive_ce/hive.dart';

import '../models/trip.dart';

class TripStorageService {
  static const String _tripBoxName = 'trips';
  static const String _settingsBoxName = 'settings';
  static const String _selectedTripKey = 'selected_trip_id';

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TripAdapter());
    }

    await Hive.openBox<Trip>(_tripBoxName);
    await Hive.openBox(_settingsBoxName);
  }

  static Box<Trip> get _tripBox => Hive.box<Trip>(_tripBoxName);

  static Box get _settingsBox => Hive.box(_settingsBoxName);

  static List<Trip> getTrips() {
    return _tripBox.values.toList();
  }

  static Future<void> saveTrip(Trip trip) async {
    await _tripBox.put(trip.id, trip);
  }

  static Future<void> deleteTrip(String id) async {
    await _tripBox.delete(id);
  }

  static Future<void> setSelectedTrip(String? tripId) async {
    if (tripId == null) {
      await _settingsBox.delete(_selectedTripKey);
      return;
    }

    await _settingsBox.put(_selectedTripKey, tripId);
  }

  static String? getSelectedTripId() {
    return _settingsBox.get(_selectedTripKey) as String?;
  }
}
