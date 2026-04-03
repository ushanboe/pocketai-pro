import 'package:flutter/material.dart';

class AcknowledgementsScreen extends StatelessWidget {
  const AcknowledgementsScreen({super.key});

  static const _bgColor = Color(0xFF0F172A);
  static const _cardColor = Color(0xFF1E293B);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _labelGray = Color(0xFF94A3B8);
  static const _borderColor = Color(0xFF334155);

  static const List<_Dependency> _dependencies = [
    _Dependency(
      name: 'fllama',
      description: 'On-device LLM inference via llama.cpp',
      license: 'MIT',
    ),
    _Dependency(
      name: 'llama.cpp',
      description: 'C++ library for running AI models locally',
      license: 'MIT',
    ),
    _Dependency(
      name: 'Flutter',
      description: 'Cross-platform UI framework by Google',
      license: 'BSD-3-Clause',
    ),
    _Dependency(
      name: 'provider',
      description: 'State management for Flutter',
      license: 'MIT',
    ),
    _Dependency(
      name: 'sqflite',
      description: 'SQLite database for conversation storage',
      license: 'MIT',
    ),
    _Dependency(
      name: 'flutter_tts',
      description: 'Text-to-speech for AI voice output',
      license: 'MIT',
    ),
    _Dependency(
      name: 'speech_to_text',
      description: 'Voice input via speech recognition',
      license: 'MIT',
    ),
    _Dependency(
      name: 'image_picker',
      description: 'Camera and gallery access for vision model',
      license: 'Apache-2.0',
    ),
    _Dependency(
      name: 'flutter_markdown',
      description: 'Markdown rendering for AI responses',
      license: 'BSD-3-Clause',
    ),
    _Dependency(
      name: 'wakelock_plus',
      description: 'Keeps screen awake during downloads',
      license: 'MIT',
    ),
    _Dependency(
      name: 'shared_preferences',
      description: 'Persistent key-value storage for settings',
      license: 'BSD-3-Clause',
    ),
    _Dependency(
      name: 'share_plus',
      description: 'Share conversations and messages',
      license: 'BSD-3-Clause',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Acknowledgements',
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
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: const Column(
              children: [
                Icon(Icons.favorite_outline, color: _accentBlue, size: 32),
                SizedBox(height: 12),
                Text(
                  'MyTinyAI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 13, color: _labelGray),
                ),
                SizedBox(height: 12),
                Text(
                  'Built with open-source software.\nAll data stays on your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _labelGray, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Section header
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'OPEN SOURCE LIBRARIES',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Dependencies list
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _dependencies.length; i++) ...[
                  if (i > 0)
                    Divider(
                      color: _borderColor.withValues(alpha: 0.5),
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dependencies[i].name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dependencies[i].description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _labelGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _dependencies[i].license,
                            style: const TextStyle(
                              fontSize: 10,
                              color: _accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Model credits
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'AI MODELS',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: const Text(
              'Models are provided by Alibaba (Qwen), Meta (Llama), Google (Gemma), '
              'DeepSeek, Microsoft (Phi), Hugging Face (SmolLM), IBM (Granite), '
              'and the TinyLlama team. All models are publicly available GGUF files '
              'from HuggingFace under their respective licences.',
              style: TextStyle(fontSize: 13, color: _labelGray, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          // Legal
          const Center(
            child: Text(
              '\u00A9 2025 MyTinyAI. All rights reserved.',
              style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Dependency {
  final String name;
  final String description;
  final String license;

  const _Dependency({
    required this.name,
    required this.description,
    required this.license,
  });
}
