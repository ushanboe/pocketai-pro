// Step 1: Inventory
// This file DEFINES: SettingsProvider (ChangeNotifier)
//   Fields: _settings (AppSettings), _prefs (SharedPreferences?)
//   Methods: init(), setTemperature(), setMaxTokens(), setSystemPrompt(),
//            setActiveModel(), setDarkMode(), setShowTokenCount(),
//            setShowGenerationSpeed(), markOnboardingComplete(),
//            applyPreset(), resetToDefaults(), get settings
//   Also needs: hardcoded PromptPreset list (5 presets from spec)
//
// This file USES from other files:
//   - AppSettings (from lib/core/models/app_settings.dart)
//     Fields used: temperature, maxTokens, systemPrompt, selectedModelId,
//                  selectedModelName, darkMode, showTokenCount,
//                  showGenerationSpeed, onboardingComplete, activePreset
//     Methods used: defaults(), copyWith()
//   - SharedPreferences (from shared_preferences package)
//
// Step 2: Connections
// Used by:
//   - main.dart: creates instance, calls init(), passes to MultiProvider
//   - splash_screen.dart: reads settings.onboardingComplete
//   - onboarding_screen.dart: calls markOnboardingComplete()
//   - chat_screen.dart: reads settings (temperature, systemPrompt, maxTokens, etc.)
//   - settings_screen.dart: calls all setters, applyPreset(), resetToDefaults()
//   - models_screen.dart: calls setActiveModel()
//
// Step 3: Presets (5 from spec)
// The spec mentions 5 hardcoded presets. Based on typical AI assistant presets:
//   1. general: "General Assistant" - balanced temperature 0.7, 512 tokens
//   2. creative: "Creative Writing" - high temperature 1.2, 1024 tokens
//   3. precise: "Precise & Factual" - low temperature 0.2, 512 tokens
//   4. coding: "Code Assistant" - low temperature 0.3, 1024 tokens
//   5. concise: "Concise Replies" - medium temperature 0.5, 256 tokens
//
// SharedPreferences keys:
//   'temperature', 'max_tokens', 'system_prompt', 'selected_model_id',
//   'selected_model_name', 'dark_mode', 'show_token_count',
//   'show_generation_speed', 'onboarding_complete', 'active_preset'
//
// Step 4: Layout Sanity
// No widgets — pure ChangeNotifier provider
// All setters update _settings via copyWith() and persist to SharedPreferences
// applyPreset() finds preset by ID, updates temperature/maxTokens/systemPrompt/activePreset
// resetToDefaults() resets to AppSettings.defaults() and saves all to prefs

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketai/core/models/app_settings.dart';

/// A simple data class representing a prompt preset configuration.
class PromptPreset {
  final String id;
  final String name;
  final String description;
  final double temperature;
  final int maxTokens;
  final String systemPrompt;

  const PromptPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.temperature,
    required this.maxTokens,
    required this.systemPrompt,
  });
}

/// A persona configuration that shapes the AI's personality.
class Persona {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String systemPrompt;

  const Persona({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.systemPrompt,
  });
}

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings.defaults();
  SharedPreferences? _prefs;

  AppSettings get settings => _settings;

  /// Hardcoded list of 5 presets available to the user.
  static const List<PromptPreset> presets = [
    PromptPreset(
      id: 'general',
      name: 'General Assistant',
      description: 'Balanced responses for everyday tasks',
      temperature: 0.7,
      maxTokens: 512,
      systemPrompt:
          'You are a helpful, harmless, and honest AI assistant running locally on this device. '
          'Be concise, clear, and friendly in your responses.',
    ),
    PromptPreset(
      id: 'creative',
      name: 'Creative Writing',
      description: 'High creativity for stories and brainstorming',
      temperature: 1.2,
      maxTokens: 1024,
      systemPrompt:
          'You are a creative writing assistant with a vivid imagination. '
          'Generate engaging, original, and expressive content. '
          'Feel free to use metaphors, descriptive language, and narrative flair.',
    ),
    PromptPreset(
      id: 'precise',
      name: 'Precise & Factual',
      description: 'Low temperature for accurate, deterministic answers',
      temperature: 0.2,
      maxTokens: 512,
      systemPrompt:
          'You are a precise and factual AI assistant. '
          'Provide accurate, well-structured, and concise answers. '
          'Avoid speculation. If you are unsure, say so clearly.',
    ),
    PromptPreset(
      id: 'coding',
      name: 'Code Assistant',
      description: 'Optimized for writing and explaining code',
      temperature: 0.3,
      maxTokens: 1024,
      systemPrompt:
          'You are an expert software engineering assistant. '
          'Write clean, efficient, and well-commented code. '
          'Explain your solutions clearly. Prefer idiomatic patterns for the language in use.',
    ),
    PromptPreset(
      id: 'concise',
      name: 'Concise Replies',
      description: 'Short, to-the-point responses',
      temperature: 0.5,
      maxTokens: 256,
      systemPrompt:
          'You are a concise AI assistant. '
          'Keep all responses brief and to the point — no more than 2-3 sentences unless absolutely necessary. '
          'Prioritize clarity over completeness.',
    ),
  ];

  /// Hardcoded list of personas the user can adopt.
  static const List<Persona> personas = [
    Persona(
      id: 'assistant',
      name: 'AI Assistant',
      emoji: '\u{1F916}',
      description: 'Helpful, clear, and professional',
      systemPrompt:
          'You are a helpful, harmless, and honest AI assistant running locally on this device. '
          'Be concise, clear, and friendly in your responses.',
    ),
    Persona(
      id: 'friend',
      name: 'Friend',
      emoji: '\u{1F60A}',
      description: 'Casual, warm, and supportive',
      systemPrompt:
          'You are the user\'s close friend. Be casual, warm, supportive, and use a relaxed conversational tone. '
          'Use friendly language, show genuine interest in what they share, crack jokes when appropriate, '
          'and be emotionally supportive. Keep things lighthearted but be there for serious moments too.',
    ),
    Persona(
      id: 'boyfriend',
      name: 'Boyfriend',
      emoji: '\u{1F468}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F468}',
      description: 'Caring, romantic, and attentive',
      systemPrompt:
          'You are a caring, loving boyfriend. Be affectionate, attentive, and emotionally supportive. '
          'Show genuine interest in the user\'s day, feelings, and experiences. Use warm pet names occasionally. '
          'Be encouraging, complimentary, and make them feel valued and loved. Keep conversations sweet and engaging.',
    ),
    Persona(
      id: 'girlfriend',
      name: 'Girlfriend',
      emoji: '\u{1F469}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F469}',
      description: 'Sweet, loving, and playful',
      systemPrompt:
          'You are a sweet, loving girlfriend. Be affectionate, playful, and emotionally connected. '
          'Show genuine care about the user\'s day, feelings, and dreams. Use warm pet names occasionally. '
          'Be supportive, flirty in a wholesome way, and make them feel special and appreciated.',
    ),
    Persona(
      id: 'mentor',
      name: 'Mentor',
      emoji: '\u{1F9D1}\u{200D}\u{1F393}',
      description: 'Wise, guiding, and insightful',
      systemPrompt:
          'You are a wise and experienced mentor. Guide the user with thoughtful advice drawn from deep experience. '
          'Ask probing questions to help them think through problems. Share relevant wisdom and frameworks. '
          'Be encouraging but honest. Help them grow and see situations from new perspectives.',
    ),
    Persona(
      id: 'tutor',
      name: 'Tutor',
      emoji: '\u{1F4DA}',
      description: 'Patient, educational, step-by-step',
      systemPrompt:
          'You are a patient and skilled tutor. Explain concepts clearly using simple language and examples. '
          'Break complex topics into manageable steps. Check understanding before moving on. '
          'Encourage curiosity and celebrate progress. Adapt your teaching style to the user\'s level.',
    ),
    Persona(
      id: 'coach',
      name: 'Life Coach',
      emoji: '\u{1F4AA}',
      description: 'Motivating, action-oriented',
      systemPrompt:
          'You are an energetic and empowering life coach. Help the user set goals, overcome obstacles, '
          'and take action. Be motivating and positive but also honest and direct. '
          'Focus on practical steps and accountability. Celebrate wins and reframe setbacks as learning opportunities.',
    ),
    Persona(
      id: 'talkative',
      name: 'Chatterbox',
      emoji: '\u{1F5E3}',
      description: 'Endlessly curious, random topics, never shuts up',
      systemPrompt:
          'You are a chatty, fun friend who loves talking. '
          'Keep answers to 2-3 sentences max. Always end with a question or new topic. '
          'Be casual and fun. Bring up random facts, "would you rather" questions, or new topics to keep chatting.',
    ),
  ];

  /// Initializes the provider by loading all settings from SharedPreferences.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final temperature = _prefs!.getDouble('temperature') ?? 0.7;
    final maxTokens = _prefs!.getInt('max_tokens') ?? 512;
    final systemPrompt = _prefs!.getString('system_prompt') ??
        'You are a helpful, harmless, and honest AI assistant running locally on this device. '
            'Be concise, clear, and friendly in your responses.';
    final selectedModelId = _prefs!.getString('selected_model_id') ?? '';
    final selectedModelName = _prefs!.getString('selected_model_name') ?? '';
    final darkMode = _prefs!.getBool('dark_mode') ?? true;
    final showTokenCount = _prefs!.getBool('show_token_count') ?? true;
    final showGenerationSpeed = _prefs!.getBool('show_generation_speed') ?? false;
    final onboardingComplete = _prefs!.getBool('onboarding_complete') ?? false;
    final activePreset = _prefs!.getString('active_preset') ?? 'general';
    final selectedPersona = _prefs!.getString('selected_persona') ?? 'assistant';
    final enableThinking = _prefs!.getBool('enable_thinking') ?? true;
    final userName = _prefs!.getString('user_name') ?? '';
    final userLikes = _prefs!.getString('user_likes') ?? '';
    final userHobbies = _prefs!.getString('user_hobbies') ?? '';
    final userDislikes = _prefs!.getString('user_dislikes') ?? '';
    final userFavoriteTopics = _prefs!.getString('user_favorite_topics') ?? '';

    _settings = AppSettings(
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
      selectedModelId: selectedModelId,
      selectedModelName: selectedModelName,
      darkMode: darkMode,
      showTokenCount: showTokenCount,
      showGenerationSpeed: showGenerationSpeed,
      onboardingComplete: onboardingComplete,
      activePreset: activePreset,
      selectedPersona: selectedPersona,
      enableThinking: enableThinking,
      userName: userName,
      userLikes: userLikes,
      userHobbies: userHobbies,
      userDislikes: userDislikes,
      userFavoriteTopics: userFavoriteTopics,
    );

    notifyListeners();
  }

  /// Updates temperature and persists to SharedPreferences.
  void setTemperature(double value) {
    _settings = _settings.copyWith(temperature: value);
    _prefs?.setDouble('temperature', value);
    notifyListeners();
  }

  /// Updates maxTokens and persists to SharedPreferences.
  void setMaxTokens(int value) {
    _settings = _settings.copyWith(maxTokens: value);
    _prefs?.setInt('max_tokens', value);
    notifyListeners();
  }

  /// Updates systemPrompt and persists to SharedPreferences.
  void setSystemPrompt(String value) {
    _settings = _settings.copyWith(systemPrompt: value);
    _prefs?.setString('system_prompt', value);
    notifyListeners();
  }

  /// Updates the active model ID and name, persists both to SharedPreferences.
  void setActiveModel(String modelId, String modelName) {
    _settings = _settings.copyWith(
      selectedModelId: modelId,
      selectedModelName: modelName,
    );
    _prefs?.setString('selected_model_id', modelId);
    _prefs?.setString('selected_model_name', modelName);
    notifyListeners();
  }

  /// Updates dark mode preference and persists to SharedPreferences.
  void setDarkMode(bool value) {
    _settings = _settings.copyWith(darkMode: value);
    _prefs?.setBool('dark_mode', value);
    notifyListeners();
  }

  /// Updates show token count preference and persists to SharedPreferences.
  void setShowTokenCount(bool value) {
    _settings = _settings.copyWith(showTokenCount: value);
    _prefs?.setBool('show_token_count', value);
    notifyListeners();
  }

  /// Updates show generation speed preference and persists to SharedPreferences.
  void setShowGenerationSpeed(bool value) {
    _settings = _settings.copyWith(showGenerationSpeed: value);
    _prefs?.setBool('show_generation_speed', value);
    notifyListeners();
  }

  /// Marks onboarding as complete and persists to SharedPreferences.
  void markOnboardingComplete() {
    _settings = _settings.copyWith(onboardingComplete: true);
    _prefs?.setBool('onboarding_complete', true);
    notifyListeners();
  }

  /// Applies a hardcoded preset by ID, updating temperature, maxTokens,
  /// systemPrompt, and activePreset. Persists all changed values.
  void applyPreset(String presetId) {
    final preset = presets.where((p) => p.id == presetId).firstOrNull;
    if (preset == null) return;

    _settings = _settings.copyWith(
      temperature: preset.temperature,
      maxTokens: preset.maxTokens,
      systemPrompt: preset.systemPrompt,
      activePreset: preset.id,
    );

    _prefs?.setDouble('temperature', preset.temperature);
    _prefs?.setInt('max_tokens', preset.maxTokens);
    _prefs?.setString('system_prompt', preset.systemPrompt);
    _prefs?.setString('active_preset', preset.id);

    notifyListeners();
  }

  /// Updates enable thinking preference and persists to SharedPreferences.
  void setEnableThinking(bool value) {
    _settings = _settings.copyWith(enableThinking: value);
    _prefs?.setBool('enable_thinking', value);
    notifyListeners();
  }

  /// Updates user profile fields and persists to SharedPreferences.
  void setUserProfile({
    required String name,
    required String likes,
    required String hobbies,
    required String dislikes,
    required String favoriteTopics,
  }) {
    _settings = _settings.copyWith(
      userName: name,
      userLikes: likes,
      userHobbies: hobbies,
      userDislikes: dislikes,
      userFavoriteTopics: favoriteTopics,
    );
    _prefs?.setString('user_name', name);
    _prefs?.setString('user_likes', likes);
    _prefs?.setString('user_hobbies', hobbies);
    _prefs?.setString('user_dislikes', dislikes);
    _prefs?.setString('user_favorite_topics', favoriteTopics);
    notifyListeners();
  }

  /// Builds a personalized system prompt for the Chatterbox persona using user profile data.
  /// Kept SHORT — small LLMs (1-3B) ignore long system prompts.
  String _buildChatterboxPrompt() {
    final s = _settings;
    final buf = StringBuffer();

    buf.write('You are a chatty, fun friend who loves talking. ');
    buf.write('Keep answers to 2-3 sentences max. Always end with a question or new topic. ');

    if (s.userName.isNotEmpty) {
      buf.write('The user\'s name is ${s.userName}. Call them by name. ');
    }
    if (s.userLikes.isNotEmpty) {
      buf.write('They like: ${s.userLikes}. ');
    }
    if (s.userHobbies.isNotEmpty) {
      buf.write('Hobbies: ${s.userHobbies}. ');
    }
    if (s.userDislikes.isNotEmpty) {
      buf.write('They dislike: ${s.userDislikes}. ');
    }
    if (s.userFavoriteTopics.isNotEmpty) {
      buf.write('Favorite topics: ${s.userFavoriteTopics}. Talk about these! ');
    }

    buf.write('Be casual and fun. Bring up random facts, "would you rather" questions, or new topics to keep chatting.');

    return buf.toString();
  }

  /// Sets the active persona, updating the system prompt accordingly.
  /// For the Chatterbox persona, builds a personalized prompt using user profile data.
  void setPersona(String personaId) {
    final persona = personas.where((p) => p.id == personaId).firstOrNull;
    if (persona == null) return;

    final prompt = personaId == 'talkative'
        ? _buildChatterboxPrompt()
        : persona.systemPrompt;

    _settings = _settings.copyWith(
      selectedPersona: persona.id,
      systemPrompt: prompt,
    );

    _prefs?.setString('selected_persona', persona.id);
    _prefs?.setString('system_prompt', prompt);

    notifyListeners();
  }

  /// Resets all settings to their default values and persists to SharedPreferences.
  void resetToDefaults() {
    final defaults = AppSettings.defaults();
    _settings = defaults;

    _prefs?.setDouble('temperature', defaults.temperature);
    _prefs?.setInt('max_tokens', defaults.maxTokens);
    _prefs?.setString('system_prompt', defaults.systemPrompt);
    _prefs?.setString('selected_model_id', defaults.selectedModelId);
    _prefs?.setString('selected_model_name', defaults.selectedModelName);
    _prefs?.setBool('dark_mode', defaults.darkMode);
    _prefs?.setBool('show_token_count', defaults.showTokenCount);
    _prefs?.setBool('show_generation_speed', defaults.showGenerationSpeed);
    _prefs?.setBool('onboarding_complete', defaults.onboardingComplete);
    _prefs?.setString('active_preset', defaults.activePreset);
    _prefs?.setString('selected_persona', defaults.selectedPersona);
    _prefs?.setBool('enable_thinking', defaults.enableThinking);
    // Note: user profile is NOT reset — it's personal data, not a setting

    notifyListeners();
  }
}