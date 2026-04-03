import 'package:flutter/material.dart';

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  static const _bgColor = Color(0xFF0F172A);
  static const _cardColor = Color(0xFF1E293B);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _labelGray = Color(0xFF94A3B8);
  static const _borderColor = Color(0xFF334155);

  static const List<_GlossaryEntry> _entries = [
    _GlossaryEntry(
      term: 'LLM',
      icon: Icons.psychology,
      definition:
          'Large Language Model. An AI trained on huge amounts of text that can understand and generate human language. The models you download in MyTinyAI are LLMs.',
    ),
    _GlossaryEntry(
      term: 'Tokens',
      icon: Icons.data_array,
      definition:
          'The basic units an AI reads and writes. Roughly 1 token = 3/4 of a word. "Hello world" is 2 tokens. More tokens = longer responses but slower generation.',
    ),
    _GlossaryEntry(
      term: 'Context Window',
      icon: Icons.view_timeline,
      definition:
          'How much text the AI can "remember" in a single conversation. Measured in tokens. A 2048-token context means the AI can consider ~1500 words of conversation history.',
    ),
    _GlossaryEntry(
      term: 'Temperature',
      icon: Icons.thermostat,
      definition:
          'Controls how creative vs predictable the AI is. Low (0.1-0.3) = focused and factual. High (0.8-1.5) = more creative and varied. Default 0.7 is a good balance.',
    ),
    _GlossaryEntry(
      term: 'Inference',
      icon: Icons.bolt,
      definition:
          'The process of the AI generating a response. When you send a message, the model runs "inference" on your device to produce the reply. All inference in MyTinyAI happens locally.',
    ),
    _GlossaryEntry(
      term: 'Parameters',
      icon: Icons.tune,
      definition:
          'The "brain cells" of an AI model. A 3B model has 3 billion parameters. More parameters = smarter but needs more RAM and runs slower. MyTinyAI models range from 0.5B to 3.8B.',
    ),
    _GlossaryEntry(
      term: 'Quantization',
      icon: Icons.compress,
      definition:
          'A compression technique that shrinks model files while keeping most of the quality. Q4_K_M means 4-bit quantization — the model is ~4x smaller than the original with minimal quality loss.',
    ),
    _GlossaryEntry(
      term: 'GGUF',
      icon: Icons.insert_drive_file,
      definition:
          'The file format used for on-device AI models. Created by the llama.cpp project. GGUF files contain the model weights and metadata needed to run inference locally.',
    ),
    _GlossaryEntry(
      term: 'Thinking / Reasoning',
      icon: Icons.lightbulb_outline,
      definition:
          'Some models (Qwen 3, DeepSeek R1) can "think out loud" before answering, showing their reasoning process in <think> tags. This often improves answer quality but makes responses longer. You can turn this off in Settings.',
    ),
    _GlossaryEntry(
      term: 'Vision / Multimodal',
      icon: Icons.image,
      definition:
          'A model that can understand both text and images. Gemma 3 4B Vision can describe photos, read text in images, and answer visual questions. It needs an extra "mmproj" file for image processing.',
    ),
    _GlossaryEntry(
      term: 'System Prompt',
      icon: Icons.description,
      definition:
          'Hidden instructions given to the AI before your conversation starts. It shapes the AI\'s personality and behaviour. For example, "You are a coding assistant" makes the AI focus on programming help.',
    ),
    _GlossaryEntry(
      term: 'On-Device / Local',
      icon: Icons.phone_android,
      definition:
          'AI that runs entirely on your phone with no internet connection needed. Your conversations never leave your device. This is how MyTinyAI works — complete privacy by design.',
    ),
    _GlossaryEntry(
      term: 'Cloud AI',
      icon: Icons.cloud,
      definition:
          'AI that runs on remote servers (like ChatGPT, Gemini). Your messages are sent over the internet to powerful computers. Faster and smarter, but requires internet and your data leaves your device.',
    ),
    _GlossaryEntry(
      term: 'Persona',
      icon: Icons.face,
      definition:
          'A pre-configured personality for the AI. Each persona has a different system prompt that changes how the AI talks — from professional assistant to casual friend to patient tutor.',
    ),
    _GlossaryEntry(
      term: 'Instruct Model',
      icon: Icons.school,
      definition:
          'A model fine-tuned to follow instructions well. Good at answering questions, completing tasks, and following directions. Most models in MyTinyAI are instruct-tuned.',
    ),
    _GlossaryEntry(
      term: 'Chat Model',
      icon: Icons.chat_bubble_outline,
      definition:
          'A model optimised for natural back-and-forth conversation. Tends to be more conversational and engaging than instruct models. Good for general chat.',
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
          'AI Glossary',
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentBlue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_stories, color: _accentBlue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Plain-English explanations of common AI and LLM terms you\'ll encounter when using MyTinyAI.',
                    style: TextStyle(fontSize: 13, color: _labelGray, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accentBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(entry.icon, color: _accentBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.term,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.definition,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _labelGray,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GlossaryEntry {
  final String term;
  final IconData icon;
  final String definition;

  const _GlossaryEntry({
    required this.term,
    required this.icon,
    required this.definition,
  });
}
