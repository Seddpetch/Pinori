import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class OnboardingStorageService {
  static const String _boxName = 'pinori_settings';
  static const String _completedKey = 'hasCompletedOnboarding';
  static const String _greetingKey = 'preferredGreeting';

  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static bool hasCompletedOnboarding() {
    return _box.get(_completedKey, defaultValue: false) as bool;
  }

  static Future<void> completeOnboarding() async {
    await _box.put(_completedKey, true);
  }

  static String getPreferredGreeting() {
    return _box.get(_greetingKey, defaultValue: 'Hey you') as String;
  }

  static Future<void> setPreferredGreeting(String greeting) async {
    await _box.put(_greetingKey, greeting);
  }
}
