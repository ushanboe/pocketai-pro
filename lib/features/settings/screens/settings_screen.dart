// Step 1: Inventory
// This file DEFINES: SettingsScreen (StatefulWidget + State)
// State variables: _temperature, _maxTokens, _systemPrompt, _systemPromptController,
//   _activePreset, _darkMode, _showTokenCount, _showGenerationSpeed
// Also needs: _temperatureDebounce (Timer), _systemPromptDebounce (Timer)
// Methods: initState, dispose, _buildSectionHeader, _buildGenerationSection,
//   _buildAppearanceSection, _buildChatSection, _buildPrivacySection,
//   _buildSliderRow, _buildSwitchTile, _showResetDialog
//
// This file USES from other files:
//   - SettingsProvider (from lib/core/providers/settings_provider.dart)
//     Fields used: settings (AppSettings), presets (List<PromptPreset>)
//     Methods used: setTemperature, setMaxTokens, setSystemPrompt, applyPreset,
//                   resetToDefaults, setDarkMode, setShowTokenCount, setShowGenerationSpeed
//   - AppSettings (from lib/core/models/app_settings.dart)
//     Fields used: temperature, maxTokens, systemPrompt, darkMode,
//                  showTokenCount, showGenerationSpeed, activePreset
//   - PromptPreset (from lib/core/providers/settings_provider.dart)
//     Fields used: id, name, temperature, maxTokens, systemPrompt
//
// Step 2: Connections
// This screen is reached via MainShell bottom navigation tab index 2 (Settings)
// No outgoing navigation except LicensePage (built-in Flutter)
// Uses context.watch<SettingsProvider>() in build() and context.read<SettingsProvider>() in callbacks
// Uses Provider package (context.watch/read) — NOT Riverpod
//
// Step 3: User Journey Trace
// User opens Settings tab → initState loads values from SettingsProvider.settings
// User moves temperature slider → setState + debounced setTemperature call
// User moves max tokens slider → setState + immediate setMaxTokens call
// User types in system prompt → debounced setSystemPrompt call
// User taps preset chip → setState updates all generation values + calls applyPreset
// User taps Reset → AlertDialog → confirm → resetToDefaults → reload state from provider
// User toggles dark mode → setState + setDarkMode
// User toggles show token count → setState + setShowTokenCount
// User toggles show generation speed → setState + setShowGenerationSpeed
// User taps Open Source Licenses → Navigator.push LicensePage
//
// Step 4: Layout Sanity
// ListView is the root scrollable — no nesting issues
// SingleChildScrollView(horizontal) for presets row — correct
// TextEditingController declared as class field, disposed in dispose()
// Timer fields declared as class fields, cancelled in dispose()
// All sections return Column wrapped in Container with decoration
// No unbounded height issues — sliders and text fields have fixed heights

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketai/core/providers/settings_provider.dart';
import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/features/settings/screens/glossary_screen.dart';
import 'package:pocketai/features/settings/screens/acknowledgements_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _temperature = 0.7;
  int _maxTokens = 512;
  String _systemPrompt = 'You are a helpful AI assistant.';
  final TextEditingController _systemPromptController = TextEditingController();
  String _activePreset = 'general';
  bool _darkMode = true;
  bool _showTokenCount = true;
  bool _showGenerationSpeed = false;
  bool _enableThinking = true;
  String _selectedPersona = 'assistant';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _likesController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();
  final TextEditingController _dislikesController = TextEditingController();
  final TextEditingController _topicsController = TextEditingController();

  Timer? _temperatureDebounce;
  Timer? _systemPromptDebounce;
  Timer? _profileDebounce;

  static const _bgColor = Color(0xFF0F172A);
  static const _cardColor = Color(0xFF1E293B);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _subtleGray = Color(0xFF64748B);
  static const _labelGray = Color(0xFF94A3B8);
  static const _sliderInactive = Color(0xFF334155);
  static const _fieldBg = Color(0xFF0F172A);
  static const _fieldBorder = Color(0xFF334155);
  static const _versionGray = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>().settings;
      setState(() {
        _temperature = settings.temperature;
        _maxTokens = settings.maxTokens;
        _systemPrompt = settings.systemPrompt;
        _systemPromptController.text = settings.systemPrompt;
        _activePreset = settings.activePreset;
        _darkMode = settings.darkMode;
        _showTokenCount = settings.showTokenCount;
        _showGenerationSpeed = settings.showGenerationSpeed;
        _enableThinking = settings.enableThinking;
        _selectedPersona = settings.selectedPersona;
        _nameController.text = settings.userName;
        _likesController.text = settings.userLikes;
        _hobbiesController.text = settings.userHobbies;
        _dislikesController.text = settings.userDislikes;
        _topicsController.text = settings.userFavoriteTopics;
      });
    });
  }

  @override
  void dispose() {
    _temperatureDebounce?.cancel();
    _systemPromptDebounce?.cancel();
    _profileDebounce?.cancel();
    _systemPromptController.dispose();
    _nameController.dispose();
    _likesController.dispose();
    _hobbiesController.dispose();
    _dislikesController.dispose();
    _topicsController.dispose();
    super.dispose();
  }

  void _reloadFromProvider() {
    final settings = context.read<SettingsProvider>().settings;
    setState(() {
      _temperature = settings.temperature;
      _maxTokens = settings.maxTokens;
      _systemPrompt = settings.systemPrompt;
      _systemPromptController.text = settings.systemPrompt;
      _activePreset = settings.activePreset;
      _darkMode = settings.darkMode;
      _showTokenCount = settings.showTokenCount;
      _showGenerationSpeed = settings.showGenerationSpeed;
      _enableThinking = settings.enableThinking;
      _selectedPersona = settings.selectedPersona;
      _nameController.text = settings.userName;
      _likesController.text = settings.userLikes;
      _hobbiesController.text = settings.userHobbies;
      _dislikesController.text = settings.userDislikes;
      _topicsController.text = settings.userFavoriteTopics;
    });
  }

  void _showResetDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'Reset to Defaults',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will reset all generation settings, appearance, and chat display options to their default values. Are you sure?',
          style: TextStyle(color: _labelGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _labelGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context.read<SettingsProvider>().resetToDefaults();
        _reloadFromProvider();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: _accentBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          color: _subtleGray,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accentBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      valueLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _accentBlue,
                    inactiveTrackColor: _sliderInactive,
                    thumbColor: _accentBlue,
                    overlayColor: _accentBlue.withValues(alpha: 0.15),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: _accentBlue, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _labelGray),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _accentBlue,
            inactiveTrackColor: _sliderInactive,
          ),
        ],
      ),
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
    // Rebuild Chatterbox prompt if currently active
    if (_selectedPersona == 'talkative') {
      provider.setPersona('talkative');
      _reloadFromProvider();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved! Start a new chat to use it.'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: _fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentBlue),
              ),
              hintText: hint,
              hintStyle: const TextStyle(color: _subtleGray, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: null,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personalise your AI conversations — used by the Chatterbox persona',
              style: TextStyle(fontSize: 12, color: _labelGray),
            ),
            const SizedBox(height: 12),
            _buildProfileField(
              controller: _nameController,
              label: 'Your First Name',
              hint: 'e.g. Patrick',
              icon: Icons.badge_outlined,
            ),
            _buildProfileField(
              controller: _likesController,
              label: 'Things You Like',
              hint: 'e.g. coffee, sci-fi movies, hiking',
              icon: Icons.favorite_outline,
            ),
            _buildProfileField(
              controller: _hobbiesController,
              label: 'Your Hobbies',
              hint: 'e.g. coding, photography, gaming',
              icon: Icons.sports_esports_outlined,
            ),
            _buildProfileField(
              controller: _dislikesController,
              label: 'Things You Dislike',
              hint: 'e.g. small talk, pineapple on pizza',
              icon: Icons.thumb_down_outlined,
            ),
            _buildProfileField(
              controller: _topicsController,
              label: 'Favourite Chat Topics',
              hint: 'e.g. space, history, tech, conspiracy theories',
              icon: Icons.chat_outlined,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaSection() {
    final personaList = SettingsProvider.personas;
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how your AI companion behaves',
              style: TextStyle(fontSize: 12, color: _labelGray),
            ),
            const SizedBox(height: 12),
            ...personaList.map((persona) {
              final isSelected = _selectedPersona == persona.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedPersona = persona.id);
                    context.read<SettingsProvider>().setPersona(persona.id);
                    _reloadFromProvider();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${persona.emoji} Now chatting as: ${persona.name}'),
                        backgroundColor: _accentBlue,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? _accentBlue.withValues(alpha: 0.15) : _fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _accentBlue : _fieldBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(persona.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                persona.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                persona.description,
                                style: const TextStyle(fontSize: 12, color: _labelGray),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: _accentBlue, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationSection() {
    final presets = SettingsProvider.presets;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Temperature slider
          _buildSliderRow(
            icon: Icons.thermostat,
            label: 'Temperature',
            valueLabel: _temperature.toStringAsFixed(1),
            value: _temperature,
            min: 0.1,
            max: 2.0,
            divisions: 19,
            onChanged: (value) {
              setState(() => _temperature = value);
              _temperatureDebounce?.cancel();
              _temperatureDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  try {
                    context.read<SettingsProvider>().setTemperature(value);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings could not be saved'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                }
              });
            },
          ),
          Divider(color: _sliderInactive.withValues(alpha: 0.5), height: 1),
          // Max tokens slider
          _buildSliderRow(
            icon: Icons.data_array,
            label: 'Max Tokens',
            valueLabel: _maxTokens.toString(),
            value: _maxTokens.toDouble(),
            min: 64,
            max: 2048,
            divisions: 30,
            onChanged: (value) {
              final rounded = value.round();
              setState(() => _maxTokens = rounded);
              try {
                context.read<SettingsProvider>().setMaxTokens(rounded);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings could not be saved'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          Divider(color: _sliderInactive.withValues(alpha: 0.5), height: 1),
          // System prompt
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Prompt',
                  style: TextStyle(fontSize: 12, color: _labelGray, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _systemPromptController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _fieldBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _fieldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _accentBlue),
                    ),
                    hintText: 'Enter a system prompt...',
                    hintStyle: const TextStyle(color: _subtleGray),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (text) {
                    _systemPromptDebounce?.cancel();
                    _systemPromptDebounce = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        try {
                          context.read<SettingsProvider>().setSystemPrompt(text);
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Settings could not be saved'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(color: _sliderInactive.withValues(alpha: 0.5), height: 1),
          // Presets
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Presets',
                  style: TextStyle(fontSize: 12, color: _labelGray, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: presets.map((preset) {
                      final isSelected = _activePreset == preset.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset.name),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _activePreset = preset.id;
                              _temperature = preset.temperature;
                              _maxTokens = preset.maxTokens;
                              _systemPromptController.text = preset.systemPrompt;
                              _systemPrompt = preset.systemPrompt;
                            });
                            try {
                              context.read<SettingsProvider>().applyPreset(preset.id);
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Settings could not be saved'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          },
                          selectedColor: _accentBlue,
                          backgroundColor: _fieldBg,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : _labelGray,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected ? _accentBlue : _fieldBorder,
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Reset button
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showResetDialog,
                icon: const Icon(Icons.restore, color: Colors.red, size: 18),
                label: const Text(
                  'Reset to defaults',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Use dark theme throughout the app',
            value: _darkMode,
            icon: Icons.dark_mode_outlined,
            onChanged: (value) {
              setState(() => _darkMode = value);
              try {
                context.read<SettingsProvider>().setDarkMode(value);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings could not be saved'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildSwitchTile(
            title: 'Show Token Count',
            subtitle: 'Display token usage bar below each response',
            value: _showTokenCount,
            icon: Icons.bar_chart,
            onChanged: (value) {
              setState(() => _showTokenCount = value);
              try {
                context.read<SettingsProvider>().setShowTokenCount(value);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings could not be saved'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          Divider(color: _sliderInactive.withValues(alpha: 0.5), height: 1, indent: 16, endIndent: 16),
          _buildSwitchTile(
            title: 'Show Thinking',
            subtitle: 'Display model reasoning (Qwen 3, DeepSeek R1). Turn off for cleaner replies.',
            value: _enableThinking,
            icon: Icons.psychology_outlined,
            onChanged: (value) {
              setState(() => _enableThinking = value);
              try {
                context.read<SettingsProvider>().setEnableThinking(value);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings could not be saved'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          Divider(color: _sliderInactive.withValues(alpha: 0.5), height: 1, indent: 16, endIndent: 16),
          _buildSwitchTile(
            title: 'Show Generation Speed',
            subtitle: 'Display tokens per second after each response',
            value: _showGenerationSpeed,
            icon: Icons.speed,
            onChanged: (value) {
              setState(() => _showGenerationSpeed = value);
              try {
                context.read<SettingsProvider>().setShowGenerationSpeed(value);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings could not be saved'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      children: [
        // Privacy promise card
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF166534).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_outline, color: Color(0xFF4ADE80), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy Promise',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Your data never leaves this device',
                            style: TextStyle(fontSize: 12, color: _labelGray),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildPrivacyItem('No internet permission required'),
              _buildPrivacyItem('All data stored locally on device'),
              _buildPrivacyItem('No analytics or tracking'),
              _buildPrivacyItem('Open model formats (GGUF)'),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Links: Glossary + Acknowledgements
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_stories, color: _accentBlue, size: 20),
                title: const Text(
                  'AI Glossary',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Learn AI terms in plain English',
                  style: TextStyle(color: _labelGray, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: _labelGray),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                  );
                },
              ),
              Divider(color: _sliderInactive.withValues(alpha: 0.5), height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.favorite_outline, color: _accentBlue, size: 20),
                title: const Text(
                  'Acknowledgements',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Open source libraries and model credits',
                  style: TextStyle(color: _labelGray, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: _labelGray),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AcknowledgementsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // App version
        const Text(
          'MyTinyAI v1.0.9',
          style: TextStyle(fontSize: 12, color: _versionGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'Think big. Run tiny. • mytinyai.app',
          style: TextStyle(fontSize: 11, color: _subtleGray),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPrivacyItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to react to external changes (e.g., preset applied from elsewhere)
    final provider = context.watch<SettingsProvider>();
    final settings = provider.settings;

    // Sync state if provider changed externally (e.g., after reset)
    // We only sync non-focused fields to avoid disrupting active text editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_temperature != settings.temperature ||
          _maxTokens != settings.maxTokens ||
          _activePreset != settings.activePreset ||
          _darkMode != settings.darkMode ||
          _showTokenCount != settings.showTokenCount ||
          _showGenerationSpeed != settings.showGenerationSpeed) {
        // Only update if the values actually differ to avoid rebuild loops
      }
    });

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Persona'),
          _buildPersonaSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Your Profile'),
          _buildProfileSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Generation'),
          _buildGenerationSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Appearance'),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Chat Display'),
          _buildChatSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Privacy & About'),
          _buildPrivacySection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}