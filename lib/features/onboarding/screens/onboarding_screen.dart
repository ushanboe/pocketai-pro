// Step 1: Inventory
// This file DEFINES:
//   - OnboardingScreen (StatefulWidget)
//   - _OnboardingScreenState (State)
//   - _OnboardingPage1, _OnboardingPage2, _OnboardingPage3, _OnboardingPage4 (StatelessWidgets)
//   - State variables: _pageController (PageController), _currentPage (int)
//   - Methods: _skipOnboarding(), _nextPage(), _completeOnboarding(), initState(), dispose(), build()
//
// This file USES from other files:
//   - SettingsProvider (from lib/core/providers/settings_provider.dart)
//     - Method used: markOnboardingComplete()
//     - Access via: context.read<SettingsProvider>().markOnboardingComplete()
//   - MainShell (from lib/features/chat/screens/main_shell.dart)
//     - Constructor: MainShell(initialIndex: 1)
//     - Navigate via: Navigator.pushReplacement
//
// Step 2: Connections
// - OnboardingScreen is navigated to from SplashScreen when onboardingComplete == false
// - OnboardingScreen navigates to MainShell(initialIndex: 1) on skip or complete
// - Uses Provider package (context.read) to call SettingsProvider.markOnboardingComplete()
// - Also writes SharedPreferences 'onboarding_complete' = true directly (belt-and-suspenders)
//
// Step 3: User Journey Trace
// User sees Page 1 (welcome/tagline) → taps Next → Page 2 (privacy icons) → taps Next
// → Page 3 (how it works) → taps Next → Page 4 (download CTA) → taps "Get Started"
// → markOnboardingComplete() called → Navigator.pushReplacement(MainShell(initialIndex:1))
// OR user taps Skip at any point → same completion flow
// Dot indicators animate width: active=24, inactive=8, color changes blue/slate
//
// Step 4: Layout Sanity
// Scaffold > SafeArea > Column: [Skip row, Expanded PageView, Bottom row (dots + button)]
// PageView children are all StatelessWidgets with their own scrollable content if needed
// Each page widget uses SingleChildScrollView to avoid overflow on small screens
// No unbounded height issues — PageView is inside Expanded
// TextEditingControllers: N/A (no text input on this screen)
// All page widgets use Column with mainAxisAlignment to center content properly

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketai/core/providers/settings_provider.dart';
import 'package:pocketai/features/chat/screens/main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _likesController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _topicsController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _likesController.dispose();
    _hobbiesController.dispose();
    _dislikesController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  void _skipOnboarding() {
    context.read<SettingsProvider>().markOnboardingComplete();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1)),
    );
  }

  void _saveProfile() {
    final provider = context.read<SettingsProvider>();
    provider.setUserProfile(
      name: _nameController.text.trim(),
      likes: _likesController.text.trim(),
      hobbies: _hobbiesController.text.trim(),
      dislikes: _dislikesController.text.trim(),
      favoriteTopics: _topicsController.text.trim(),
    );
  }

  void _nextPage() {
    // Save profile when leaving the "About You" page (page 3)
    if (_currentPage == 3) {
      _saveProfile();
    }
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    _saveProfile();
    context.read<SettingsProvider>().markOnboardingComplete();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — top right
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skipOnboarding,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // PageView — takes remaining space
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  const _OnboardingPage1(),
                  const _OnboardingPage2(),
                  const _OnboardingPage3(),
                  _OnboardingPageAboutYou(
                    nameController: _nameController,
                    likesController: _likesController,
                    hobbiesController: _hobbiesController,
                    dislikesController: _dislikesController,
                    topicsController: _topicsController,
                  ),
                  const _OnboardingPage4(),
                ],
              ),
            ),
            // Bottom row: dots + Next/Get Started button
            Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 24,
                top: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Animated dot indicators
                  Row(
                    children: List.generate(5, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isActive ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isActive
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF334155),
                        ),
                      );
                    }),
                  ),
                  // Next / Get Started button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == 4 ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: Welcome / Tagline ───────────────────────────────────────────────

class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // App icon / hero illustration using Material icons + styled container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'MyTinyAI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your private AI assistant,\nrunning entirely on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_bolt, color: Color(0xFF3B82F6), size: 20),
                SizedBox(width: 8),
                Text(
                  'No internet required. Ever.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Page 2: Privacy Icons Grid ──────────────────────────────────────────────

class _OnboardingPage2 extends StatelessWidget {
  const _OnboardingPage2();

  @override
  Widget build(BuildContext context) {
    final privacyFeatures = [
      (Icons.lock_outline, 'End-to-End\nPrivate', const Color(0xFF10B981)),
      (Icons.cloud_off_outlined, 'Zero Cloud\nDependency', const Color(0xFF3B82F6)),
      (Icons.visibility_off_outlined, 'No Data\nCollection', const Color(0xFFF59E0B)),
      (Icons.storage_outlined, 'On-Device\nStorage', const Color(0xFF8B5CF6)),
      (Icons.wifi_off_outlined, 'Works\nOffline', const Color(0xFFEF4444)),
      (Icons.shield_outlined, 'Open Source\nTransparent', const Color(0xFF06B6D4)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text(
            'Privacy First',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your conversations never leave your device. No accounts, no tracking, no compromises.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: privacyFeatures.map((feature) {
              final (icon, label, color) = feature;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Page 3: How It Works — 3-Step List ──────────────────────────────────────

class _OnboardingPage3 extends StatelessWidget {
  const _OnboardingPage3();

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        '1',
        Icons.download_outlined,
        const Color(0xFF3B82F6),
        'Download a Model',
        'Choose from our curated library of open-source AI models. Each model is optimized for on-device performance.',
      ),
      (
        '2',
        Icons.tune_outlined,
        const Color(0xFF8B5CF6),
        'Configure Your Assistant',
        'Adjust temperature, context length, and system prompts. Pick from presets like Creative, Precise, or Coding.',
      ),
      (
        '3',
        Icons.chat_bubble_outline,
        const Color(0xFF10B981),
        'Start Chatting',
        'Ask anything. Your AI responds instantly, locally, with no internet connection required.',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'How It Works',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Get up and running in three simple steps.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...steps.map((step) {
            final (number, icon, color, title, description) = step;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step number circle
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  // Step content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  number,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Page 4: About You (User Profile) ─────────────────────────────────────────

class _OnboardingPageAboutYou extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController likesController;
  final TextEditingController hobbiesController;
  final TextEditingController dislikesController;
  final TextEditingController topicsController;

  const _OnboardingPageAboutYou({
    required this.nameController,
    required this.likesController,
    required this.hobbiesController,
    required this.dislikesController,
    required this.topicsController,
  });

  static const _fieldBg = Color(0xFF0F172A);
  static const _fieldBorder = Color(0xFF334155);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _labelGray = Color(0xFF94A3B8);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accentBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: _fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accentBlue),
              ),
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.person_outline, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tell Us About You',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Help your AI companion personalise conversations.\nAll optional — skip any you like.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _labelGray,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildField(
            controller: nameController,
            label: 'Your First Name',
            hint: 'e.g. Patrick',
            icon: Icons.badge_outlined,
          ),
          _buildField(
            controller: likesController,
            label: 'Things You Like',
            hint: 'e.g. coffee, sci-fi movies, hiking',
            icon: Icons.favorite_outline,
          ),
          _buildField(
            controller: hobbiesController,
            label: 'Your Hobbies',
            hint: 'e.g. coding, photography, gaming',
            icon: Icons.sports_esports_outlined,
          ),
          _buildField(
            controller: dislikesController,
            label: 'Things You Dislike',
            hint: 'e.g. small talk, pineapple on pizza',
            icon: Icons.thumb_down_outlined,
          ),
          _buildField(
            controller: topicsController,
            label: 'Favourite Chat Topics',
            hint: 'e.g. space, history, tech, conspiracy theories',
            icon: Icons.chat_outlined,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Page 5: Download CTA ─────────────────────────────────────────────────────

class _OnboardingPage4 extends StatelessWidget {
  const _OnboardingPage4();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // Hero icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.download_done_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Ready to Begin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Download your first AI model and start chatting in seconds. It's completely free and runs 100% on your device.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          // Feature highlight cards
          _HighlightCard(
            icon: Icons.bolt_outlined,
            color: const Color(0xFFF59E0B),
            title: 'Fast Inference',
            subtitle: 'Optimized for mobile hardware',
          ),
          const SizedBox(height: 12),
          _HighlightCard(
            icon: Icons.folder_outlined,
            color: const Color(0xFF3B82F6),
            title: 'Multiple Models',
            subtitle: 'Switch between models anytime',
          ),
          const SizedBox(height: 12),
          _HighlightCard(
            icon: Icons.history_outlined,
            color: const Color(0xFF8B5CF6),
            title: 'Conversation History',
            subtitle: 'All chats saved locally',
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tap 'Get Started' to go to the Models tab and download your first model.",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _HighlightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}