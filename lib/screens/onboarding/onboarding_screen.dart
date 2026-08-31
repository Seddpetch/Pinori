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

  String selectedGreeting = 'Hey you';
  bool showCustomGreeting = false;
  final TextEditingController greetingController = TextEditingController();

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

  @override
  void dispose() {
    greetingController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await OnboardingStorageService.completeOnboarding();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  Widget _buildGreetingPage() {
    Widget greetingOption(String label) {
      final isSelected = !showCustomGreeting && selectedGreeting == label;

      return GestureDetector(
        onTap: () {
          setState(() {
            selectedGreeting = label;
            showCustomGreeting = false;
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFC33132)
                : const Color(0xFFFFFBE9),
            border: Border.all(color: const Color(0xFF280000), width: 4),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFFFFFBE9)
                  : const Color(0xFF280000),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How should Pinori greet you?',
            style: TextStyle(
              color: Color(0xFF280000),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Pick whatever feels like you ♡',
            style: TextStyle(
              color: Color(0xFF280000),
              fontSize: 15,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 28),

          greetingOption('Hey girl'),
          const SizedBox(height: 10),

          greetingOption('Hey guy'),
          const SizedBox(height: 10),

          greetingOption('Hey you'),
          const SizedBox(height: 10),

          GestureDetector(
            onTap: () {
              setState(() {
                showCustomGreeting = true;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: showCustomGreeting
                    ? const Color(0xFFC33132)
                    : const Color(0xFFFFFBE9),
                border: Border.all(color: const Color(0xFF280000), width: 4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Something else…',
                style: TextStyle(
                  color: showCustomGreeting
                      ? const Color(0xFFFFFBE9)
                      : const Color(0xFF280000),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (showCustomGreeting) ...[
            const SizedBox(height: 14),

            TextField(
              controller: greetingController,
              decoration: InputDecoration(
                labelText: 'Type your greeting',
                hintText: 'e.g. Hey babe, Hey bestie, Oi loser, Captain 👀',
                filled: true,
                fillColor: const Color(0xFFFFFBE9),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFF280000),
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFFC33132),
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          GestureDetector(
            onTap: () async {
              final greeting = showCustomGreeting
                  ? greetingController.text.trim()
                  : selectedGreeting;

              if (greeting.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Type your greeting first ♡')),
                );
                return;
              }

              await OnboardingStorageService.setPreferredGreeting(greeting);

              if (!mounted) return;

              setState(() {
                onboardingPage = 2;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFC33132),
                border: Border.all(color: const Color(0xFF280000), width: 4),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Continue →',
                style: TextStyle(
                  color: Color(0xFFFFFBE9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
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
              : onboardingPage == 1
              ? _buildGreetingPage()
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
