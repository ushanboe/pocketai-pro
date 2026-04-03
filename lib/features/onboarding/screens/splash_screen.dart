// Step 1: Inventory
// This file DEFINES:
//   - SplashScreen (StatefulWidget)
//   - _SplashScreenState (State)
//   - State variables: _initialized (bool, default false)
//   - Methods: initState(), build()
//
// This file USES from other files:
//   - SettingsProvider (from lib/core/providers/settings_provider.dart)
//     - Access via: context.read<SettingsProvider>().settings.onboardingComplete
//     - Already generated — has settings getter returning AppSettings with onboardingComplete field
//   - OnboardingScreen (from lib/features/onboarding/screens/onboarding_screen.dart)
//     - Constructor: const OnboardingScreen()
//     - Navigate via: Navigator.pushReplacement
//   - MainShell (from lib/features/chat/screens/main_shell.dart)
//     - Constructor: const MainShell(initialIndex: 0)
//     - Navigate via: Navigator.pushReplacement
//   - flutter_animate package for .animate() extensions
//   - provider package for context.read<SettingsProvider>()
//
// Step 2: Connections
// - SplashScreen is the initial route (set in main.dart home: SplashScreen())
// - SplashScreen navigates to OnboardingScreen if onboardingComplete == false
// - SplashScreen navigates to MainShell if onboardingComplete == true
// - Uses context.read<SettingsProvider>() to get the settings (Provider package)
// - _initialized flag prevents double-navigation if widget rebuilds during delay
//
// Step 3: User Journey Trace
// App launches → SplashScreen renders (dark bg, animated logo, fade-in text)
// initState fires → Future.delayed(1500ms) starts
// During 1500ms: logo pulses (scale 1.0→1.05 repeating), "MyTinyAI" fades in at 300ms,
//   tagline "AI. Private. Offline." fades in at 600ms
// After 1500ms: reads SettingsProvider.settings.onboardingComplete
//   - false → Navigator.pushReplacement to OnboardingScreen
//   - true → Navigator.pushReplacement to MainShell
// _initialized = true prevents re-navigation on any spurious rebuild
//
// Step 4: Layout Sanity
// Scaffold > body: Center > Column(mainAxisAlignment: center)
// No scrollable inside non-scrollable issues — simple Column with a few widgets
// No TextEditingControllers needed
// flutter_animate is in the dependency list per build spec
// The spec shows .animate() on Container and Text — using flutter_animate extension methods
// Error case: if SettingsProvider throws, catch and default to OnboardingScreen
// SizedBox(height: 80) at bottom per spec for slight upward offset

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:pocketai/core/providers/settings_provider.dart';
import 'package:pocketai/features/onboarding/screens/onboarding_screen.dart';
import 'package:pocketai/features/chat/screens/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _initialized) return;
    _initialized = true;

    bool onboardingComplete = false;
    try {
      onboardingComplete =
          context.read<SettingsProvider>().settings.onboardingComplete;
    } catch (_) {
      // If provider throws for any reason, default to onboarding (first launch)
      onboardingComplete = false;
    }

    if (!mounted) return;

    if (onboardingComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 0)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            // Animated logo container with circular blue glow
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x663B82F6),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_outlined,
                size: 64,
                color: Color(0xFF3B82F6),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 1.0,
                  end: 1.05,
                  duration: const Duration(milliseconds: 1200),
                )
                .then()
                .custom(
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) => child!,
                ),
            const SizedBox(height: 24),
            // App name fade-in
            const Text(
              'MyTinyAI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 600),
                ),
            const SizedBox(height: 8),
            // Tagline fade-in
            const Text(
              'Think big. Run tiny.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 600),
                  duration: const Duration(milliseconds: 600),
                ),
            // Slight upward offset spacer
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}