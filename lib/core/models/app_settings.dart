// Step 1: Inventory
// This file DEFINES: AppSettings class with fields:
//   - temperature: double (0.1-2.0, default 0.7)
//   - maxTokens: int (64-2048, default 512)
//   - systemPrompt: String (active system prompt text)
//   - selectedModelId: String (ID of active model, empty if none)
//   - selectedModelName: String (display name for ChatScreen app bar)
//   - darkMode: bool (default true)
//   - showTokenCount: bool (default true)
//   - showGenerationSpeed: bool (default false)
//   - onboardingComplete: bool (default false)
//   - activePreset: String (default 'general')
// Methods: constructor, copyWith, toJson, fromJson, static defaults() factory
//
// This file uses: NO imports from other project files — pure data class
// No dart:convert needed since toJson/fromJson work with Map<String,dynamic>
//
// Step 2: Connections
// Imported by:
//   - settings_provider.dart (reads/writes all fields via SharedPreferences)
//   - chat_screen.dart (reads selectedModelName, maxTokens, showTokenCount, showGenerationSpeed, temperature, systemPrompt)
//   - splash_screen.dart (reads onboardingComplete)
//   - onboarding_screen.dart (triggers markOnboardingComplete)
// No navigation in this file — pure data model
//
// Step 3: User Journey Trace
// Pure data class — no user interaction
// defaults() provides initial values before SharedPreferences are loaded
// copyWith() allows partial updates (e.g., only changing temperature)
// toJson()/fromJson() used by settings_provider for SharedPreferences serialization
//
// Step 4: Layout Sanity
// No widgets — pure Dart data class
// Follow exact same pattern as Conversation and Message models already generated
// All fields are non-nullable with sensible defaults
// No DateTime fields — all primitives (double, int, String, bool)

class AppSettings {
  final double temperature;
  final int maxTokens;
  final String systemPrompt;
  final String selectedModelId;
  final String selectedModelName;
  final bool darkMode;
  final bool showTokenCount;
  final bool showGenerationSpeed;
  final bool onboardingComplete;
  final String activePreset;
  final String selectedPersona;
  final bool enableThinking;
  final String userName;
  final String userLikes;
  final String userHobbies;
  final String userDislikes;
  final String userFavoriteTopics;

  const AppSettings({
    required this.temperature,
    required this.maxTokens,
    required this.systemPrompt,
    required this.selectedModelId,
    required this.selectedModelName,
    required this.darkMode,
    required this.showTokenCount,
    required this.showGenerationSpeed,
    required this.onboardingComplete,
    required this.activePreset,
    required this.selectedPersona,
    required this.enableThinking,
    required this.userName,
    required this.userLikes,
    required this.userHobbies,
    required this.userDislikes,
    required this.userFavoriteTopics,
  });

  /// Returns an AppSettings instance with sensible default values.
  static AppSettings defaults() {
    return const AppSettings(
      temperature: 0.7,
      maxTokens: 512,
      systemPrompt:
          'You are a helpful, harmless, and honest AI assistant running locally on this device. '
          'Be concise, clear, and friendly in your responses.',
      selectedModelId: '',
      selectedModelName: '',
      darkMode: true,
      showTokenCount: true,
      showGenerationSpeed: false,
      onboardingComplete: false,
      activePreset: 'general',
      selectedPersona: 'assistant',
      enableThinking: true,
      userName: '',
      userLikes: '',
      userHobbies: '',
      userDislikes: '',
      userFavoriteTopics: '',
    );
  }

  /// Creates a copy of this AppSettings with the given fields replaced.
  AppSettings copyWith({
    double? temperature,
    int? maxTokens,
    String? systemPrompt,
    String? selectedModelId,
    String? selectedModelName,
    bool? darkMode,
    bool? showTokenCount,
    bool? showGenerationSpeed,
    bool? onboardingComplete,
    String? activePreset,
    String? selectedPersona,
    bool? enableThinking,
    String? userName,
    String? userLikes,
    String? userHobbies,
    String? userDislikes,
    String? userFavoriteTopics,
  }) {
    return AppSettings(
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      selectedModelName: selectedModelName ?? this.selectedModelName,
      darkMode: darkMode ?? this.darkMode,
      showTokenCount: showTokenCount ?? this.showTokenCount,
      showGenerationSpeed: showGenerationSpeed ?? this.showGenerationSpeed,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      activePreset: activePreset ?? this.activePreset,
      selectedPersona: selectedPersona ?? this.selectedPersona,
      enableThinking: enableThinking ?? this.enableThinking,
      userName: userName ?? this.userName,
      userLikes: userLikes ?? this.userLikes,
      userHobbies: userHobbies ?? this.userHobbies,
      userDislikes: userDislikes ?? this.userDislikes,
      userFavoriteTopics: userFavoriteTopics ?? this.userFavoriteTopics,
    );
  }

  /// Converts to a JSON-compatible Map for SharedPreferences serialization.
  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'maxTokens': maxTokens,
      'systemPrompt': systemPrompt,
      'selectedModelId': selectedModelId,
      'selectedModelName': selectedModelName,
      'darkMode': darkMode,
      'showTokenCount': showTokenCount,
      'showGenerationSpeed': showGenerationSpeed,
      'onboardingComplete': onboardingComplete,
      'activePreset': activePreset,
      'selectedPersona': selectedPersona,
      'enableThinking': enableThinking,
      'userName': userName,
      'userLikes': userLikes,
      'userHobbies': userHobbies,
      'userDislikes': userDislikes,
      'userFavoriteTopics': userFavoriteTopics,
    };
  }

  /// Constructs an AppSettings from a JSON Map (e.g., decoded from SharedPreferences).
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 512,
      systemPrompt: json['systemPrompt'] as String? ??
          'You are a helpful, harmless, and honest AI assistant running locally on this device. '
              'Be concise, clear, and friendly in your responses.',
      selectedModelId: json['selectedModelId'] as String? ?? '',
      selectedModelName: json['selectedModelName'] as String? ?? '',
      darkMode: json['darkMode'] as bool? ?? true,
      showTokenCount: json['showTokenCount'] as bool? ?? true,
      showGenerationSpeed: json['showGenerationSpeed'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      activePreset: json['activePreset'] as String? ?? 'general',
      selectedPersona: json['selectedPersona'] as String? ?? 'assistant',
      enableThinking: json['enableThinking'] as bool? ?? true,
      userName: json['userName'] as String? ?? '',
      userLikes: json['userLikes'] as String? ?? '',
      userHobbies: json['userHobbies'] as String? ?? '',
      userDislikes: json['userDislikes'] as String? ?? '',
      userFavoriteTopics: json['userFavoriteTopics'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.temperature == temperature &&
        other.maxTokens == maxTokens &&
        other.systemPrompt == systemPrompt &&
        other.selectedModelId == selectedModelId &&
        other.selectedModelName == selectedModelName &&
        other.darkMode == darkMode &&
        other.showTokenCount == showTokenCount &&
        other.showGenerationSpeed == showGenerationSpeed &&
        other.onboardingComplete == onboardingComplete &&
        other.activePreset == activePreset &&
        other.selectedPersona == selectedPersona &&
        other.enableThinking == enableThinking &&
        other.userName == userName &&
        other.userLikes == userLikes &&
        other.userHobbies == userHobbies &&
        other.userDislikes == userDislikes &&
        other.userFavoriteTopics == userFavoriteTopics;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      temperature,
      maxTokens,
      systemPrompt,
      selectedModelId,
      selectedModelName,
      darkMode,
      showTokenCount,
      showGenerationSpeed,
      onboardingComplete,
      activePreset,
      selectedPersona,
      enableThinking,
      userName,
      userLikes,
      userHobbies,
      userDislikes,
      userFavoriteTopics,
    ]);
  }

  @override
  String toString() {
    return 'AppSettings('
        'temperature: $temperature, '
        'maxTokens: $maxTokens, '
        'selectedModelId: $selectedModelId, '
        'selectedModelName: $selectedModelName, '
        'darkMode: $darkMode, '
        'showTokenCount: $showTokenCount, '
        'showGenerationSpeed: $showGenerationSpeed, '
        'onboardingComplete: $onboardingComplete, '
        'activePreset: $activePreset, '
        'selectedPersona: $selectedPersona, '
        'enableThinking: $enableThinking'
        ')';
  }
}