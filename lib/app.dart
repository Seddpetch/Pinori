import 'package:flutter/material.dart';
import 'core/theme/pinori_theme.dart';
import 'screens/map/map_screen.dart';

import 'screens/onboarding/onboarding_screen.dart';
import 'services/onboarding_storage_service.dart';

class PinoriApp extends StatelessWidget {
  const PinoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pinori',
      theme: PinoriTheme.lightTheme,
      home: OnboardingStorageService.hasCompletedOnboarding()
          ? const MapScreen()
          : const OnboardingScreen(),
    );
  }
}
