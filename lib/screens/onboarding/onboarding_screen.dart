import 'package:flutter/material.dart';

import '../../core/theme/pinori_colours.dart';
import '../map/map_screen.dart';
import '../../services/onboarding_storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool showWelcome = false;
  int onboardingPage = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      setState(() {
        showWelcome = true;
      });
    });
  }

  Future<void> _finishOnboarding() async {
    await OnboardingStorageService.completeOnboarding();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinoriColours.ivoryMist,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: !showWelcome
              ? _buildSplash()
              : onboardingPage == 0
              ? _buildWelcome()
              : _buildHowItWorks(),
        ),
      ),
    );
  }

  Widget _buildSplash() {
    return Center(
      key: const ValueKey('splash'),
      child: Image.asset(
        'assets/icons/pinori_logo.png',
        width: 190,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        children: [
          const Spacer(),

          Image.asset(
            'assets/icons/pinori_logo.png',
            width: 150,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 48),

          const Text(
            'All those places you saved?\nLet’s actually go.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Pinori turns the places you find online into your own little travel map.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  onboardingPage = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PinoriColours.tomatoJam,
                foregroundColor: PinoriColours.ivoryMist,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Start pinning →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 10),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Padding(
      key: const ValueKey('howItWorks'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        children: [
          const Spacer(),

          const Text(
            'How it works',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PinoriColours.richMahogany,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 36),

          _buildHowItWorksStep(emoji: '🔎', text: 'Find something online'),

          const SizedBox(height: 18),

          _buildHowItWorksStep(
            emoji: '📲',
            text: 'Share or paste it into Pinori',
          ),

          const SizedBox(height: 18),

          _buildHowItWorksStep(emoji: '✨', text: 'Pinori finds the place'),

          const SizedBox(height: 18),

          _buildHowItWorksStep(emoji: '📍', text: 'It appears on your map!'),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: PinoriColours.tomatoJam,
                foregroundColor: PinoriColours.ivoryMist,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Let’s go →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep({required String emoji, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PinoriColours.ivoryMist,
        border: Border.all(color: PinoriColours.richMahogany, width: 3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: PinoriColours.richMahogany,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
