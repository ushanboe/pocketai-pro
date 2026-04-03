// Step 1: Inventory
// This file DEFINES: PromptTemplate class with fields: id, title, template, category, placeholder
// Methods: toJson(), fromJson() factory constructor, static getter allTemplates
// No imports from other project files needed - pure data class
// 
// Step 2: Connections
// This file is used by:
// - lib/features/chat/widgets/prompt_templates_bottom_sheet.dart (displays templates grouped by category)
// - Potentially chat_screen.dart for template selection
// No dependencies on other project files
//
// Step 3: User Journey Trace
// User opens PromptTemplatesBottomSheet → sheet calls PromptTemplate.allTemplates → 
// gets list of 14 templates → displays grouped by category (Productivity, Learning, Creative, Code)
// User taps a template → template.template text is inserted into chat input
//
// Step 4: Layout Sanity
// Pure data class - no widgets. Just ensure:
// - 14 templates total across 4 categories (Productivity, Learning, Creative, Code)
// - Each template has id, title, template (with [placeholder] markers), category, placeholder field
// - toJson/fromJson are symmetric
// - allTemplates static getter returns hardcoded list

class PromptTemplate {
  final String id;
  final String title;
  final String template;
  final String category;
  final String placeholder;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.template,
    required this.category,
    required this.placeholder,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'template': template,
      'category': category,
      'placeholder': placeholder,
    };
  }

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      template: json['template'] as String,
      category: json['category'] as String,
      placeholder: json['placeholder'] as String,
    );
  }

  static List<PromptTemplate> get allTemplates => [
        // Productivity (4 templates)
        const PromptTemplate(
          id: 'prod_1',
          title: 'Summarize text',
          template:
              'Please summarize the following text in a concise and clear manner, highlighting the key points:\n\n[your text here]',
          category: 'Productivity',
          placeholder: '[your text here]',
        ),
        const PromptTemplate(
          id: 'prod_2',
          title: 'Write an email',
          template:
              'Write a professional email about [topic or purpose]. The tone should be polite and concise. Include a clear subject line, greeting, body, and closing.',
          category: 'Productivity',
          placeholder: '[topic or purpose]',
        ),
        const PromptTemplate(
          id: 'prod_3',
          title: 'Action items from notes',
          template:
              'Extract all action items and tasks from the following meeting notes, and format them as a numbered list with assignees and deadlines where mentioned:\n\n[paste meeting notes here]',
          category: 'Productivity',
          placeholder: '[paste meeting notes here]',
        ),
        const PromptTemplate(
          id: 'prod_4',
          title: 'Rewrite & improve',
          template:
              'Rewrite the following text to improve clarity, grammar, and flow while preserving the original meaning:\n\n[paste text to improve]',
          category: 'Productivity',
          placeholder: '[paste text to improve]',
        ),

        // Learning (3 templates)
        const PromptTemplate(
          id: 'learn_1',
          title: 'Explain a concept',
          template:
              'Explain [concept or topic] in simple terms as if I am a complete beginner. Use analogies and examples to make it easy to understand.',
          category: 'Learning',
          placeholder: '[concept or topic]',
        ),
        const PromptTemplate(
          id: 'learn_2',
          title: 'Quiz me',
          template:
              'Create a 5-question multiple-choice quiz on the topic of [subject]. For each question, provide 4 answer options (A, B, C, D) and indicate the correct answer at the end.',
          category: 'Learning',
          placeholder: '[subject]',
        ),
        const PromptTemplate(
          id: 'learn_3',
          title: 'Study plan',
          template:
              'Create a structured 4-week study plan for learning [topic or skill]. Break it down week by week with specific goals, resources, and daily tasks.',
          category: 'Learning',
          placeholder: '[topic or skill]',
        ),

        // Creative (4 templates)
        const PromptTemplate(
          id: 'creative_1',
          title: 'Write a short story',
          template:
              'Write a short story (around 300 words) with the following premise: [story idea or setting]. Make it engaging with vivid descriptions and a clear beginning, middle, and end.',
          category: 'Creative',
          placeholder: '[story idea or setting]',
        ),
        const PromptTemplate(
          id: 'creative_2',
          title: 'Brainstorm ideas',
          template:
              'Generate 10 creative and diverse ideas for [project or topic]. For each idea, provide a one-sentence description and explain why it could be effective.',
          category: 'Creative',
          placeholder: '[project or topic]',
        ),
        const PromptTemplate(
          id: 'creative_3',
          title: 'Write a poem',
          template:
              'Write a [poem style, e.g. haiku, sonnet, free verse] poem about [theme or subject]. Make it evocative and use vivid imagery.',
          category: 'Creative',
          placeholder: '[poem style, e.g. haiku, sonnet, free verse]',
        ),
        const PromptTemplate(
          id: 'creative_4',
          title: 'Character description',
          template:
              'Create a detailed character profile for a fictional character who is [brief character concept]. Include their appearance, personality, backstory, motivations, and quirks.',
          category: 'Creative',
          placeholder: '[brief character concept]',
        ),

        // Code (3 templates)
        const PromptTemplate(
          id: 'code_1',
          title: 'Explain this code',
          template:
              'Explain the following code step by step. Describe what each part does, the overall purpose, and any potential issues or improvements:\n\n```\n[paste your code here]\n```',
          category: 'Code',
          placeholder: '[paste your code here]',
        ),
        const PromptTemplate(
          id: 'code_2',
          title: 'Debug this code',
          template:
              'I have the following code that is not working as expected. Please identify the bugs, explain what is wrong, and provide a corrected version:\n\n```\n[paste buggy code here]\n```\n\nExpected behavior: [describe what it should do]',
          category: 'Code',
          placeholder: '[paste buggy code here]',
        ),
        const PromptTemplate(
          id: 'code_3',
          title: 'Write a function',
          template:
              'Write a [programming language] function that [description of what the function should do]. Include clear variable names, comments, and handle edge cases. Also provide a brief usage example.',
          category: 'Code',
          placeholder: '[programming language]',
        ),
      ];
}