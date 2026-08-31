import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app.dart';
import 'services/trip_storage_service.dart';

import 'services/place_storage_service.dart';

import 'services/onboarding_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await TripStorageService.init();
  await PlaceStorageService.init();

  await OnboardingStorageService.init();

  runApp(const PinoriApp());
}
