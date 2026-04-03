import 'dart:async';
import 'dart:math';

import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/core/models/message.dart';

class MockInferenceEngine {
  bool _isCancelled = false;
  StreamController<String>? _streamController;
  final Random _random = Random();

  /// Generates a streaming response token by token.
  /// Returns a Stream<String> where each event is one word/token.
  Stream<String> generateResponse(
    String userMessage,
    List<Message> history,
    AppSettings settings,
  ) {
    _isCancelled = false;
    _streamController?.close();
    _streamController = StreamController<String>();

    _runGeneration(userMessage, history, settings, _streamController!);

    return _streamController!.stream;
  }

  /// Stops the active stream generation.
  void cancel() {
    _isCancelled = true;
    _streamController?.close();
    _streamController = null;
  }

  /// Returns a simulated tokens-per-second value between 8 and 25.
  int simulateTokensPerSecond() {
    return _random.nextInt(18) + 8;
  }

  Future<void> _runGeneration(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    StreamController<String> controller,
  ) async {
    try {
      final topic = _detectTopic(userMessage);
      final preset = settings.activePreset;
      final temperature = settings.temperature;
      final maxTokens = settings.maxTokens;

      // Select response from library, with fallback chain
      String responseText = _selectResponse(topic, preset, temperature, userMessage);

      // Tokenize the response
      final tokens = _tokenize(responseText);

      // Limit by maxTokens
      final limitedTokens = tokens.length > maxTokens
          ? tokens.sublist(0, maxTokens)
          : tokens;

      int emittedCount = 0;
      for (final token in limitedTokens) {
        if (_isCancelled || controller.isClosed) break;

        // Emit the token
        controller.add(token);
        emittedCount++;

        // Add space after each token except punctuation-only tokens
        if (!_isCancelled && !controller.isClosed && emittedCount < limitedTokens.length) {
          final nextToken = limitedTokens[emittedCount];
          final needsSpace = !_isPunctuation(nextToken);
          if (needsSpace) {
            controller.add(' ');
          }
        }

        // Delay between 15-40ms simulating inference speed
        final delayMs = 15 + _random.nextInt(26);
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      if (!_isCancelled && !controller.isClosed) {
        controller.close();
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
  }

  bool _isPunctuation(String token) {
    return RegExp(r'^[.,!?;:"\)\]\}]+$').hasMatch(token);
  }

  /// Detects the topic of the user message using keyword matching.
  String _detectTopic(String text) {
    final lower = text.toLowerCase();

    final topicKeywords = <String, List<String>>{
      'coding': [
        'code', 'program', 'function', 'dart', 'flutter', 'python', 'java',
        'javascript', 'typescript', 'swift', 'kotlin', 'rust', 'golang', 'go',
        'c++', 'c#', 'algorithm', 'debug', 'error', 'bug', 'compile', 'class',
        'method', 'variable', 'api', 'database', 'sql', 'git', 'github',
        'framework', 'library', 'package', 'widget', 'async', 'await',
        'loop', 'array', 'list', 'map', 'object', 'interface', 'implement',
        'refactor', 'test', 'unit test', 'deploy', 'server', 'backend',
        'frontend', 'web', 'app', 'mobile',
      ],
      'math': [
        'math', 'calculate', 'equation', 'algebra', 'calculus', 'geometry',
        'statistics', 'probability', 'number', 'solve', 'formula', 'integral',
        'derivative', 'matrix', 'vector', 'prime', 'fraction', 'percentage',
        'graph', 'function', 'theorem', 'proof', 'arithmetic', 'multiplication',
        'division', 'addition', 'subtraction', 'square root', 'exponent',
      ],
      'science': [
        'science', 'physics', 'chemistry', 'biology', 'astronomy', 'quantum',
        'relativity', 'evolution', 'dna', 'atom', 'molecule', 'energy',
        'force', 'gravity', 'light', 'photon', 'electron', 'proton', 'neutron',
        'cell', 'organism', 'ecosystem', 'climate', 'temperature', 'pressure',
        'experiment', 'hypothesis', 'theory', 'research', 'discovery',
        'universe', 'galaxy', 'planet', 'star', 'black hole',
      ],
      'writing': [
        'write', 'essay', 'story', 'poem', 'letter', 'email', 'blog',
        'article', 'paragraph', 'sentence', 'grammar', 'spelling', 'edit',
        'proofread', 'summarize', 'summary', 'explain', 'describe', 'narrative',
        'fiction', 'nonfiction', 'character', 'plot', 'dialogue', 'creative',
        'draft', 'outline', 'thesis', 'argument', 'persuasive', 'report',
      ],
      'creative': [
        'creative', 'imagine', 'story', 'fiction', 'fantasy', 'dream',
        'invent', 'design', 'idea', 'brainstorm', 'concept', 'art', 'music',
        'poem', 'poetry', 'novel', 'character', 'world', 'universe', 'magic',
        'adventure', 'mystery', 'horror', 'romance', 'sci-fi', 'dystopia',
        'utopia', 'myth', 'legend', 'folklore',
      ],
      'philosophy': [
        'philosophy', 'ethics', 'moral', 'meaning', 'consciousness', 'free will',
        'existence', 'reality', 'truth', 'knowledge', 'belief', 'god',
        'religion', 'soul', 'mind', 'thought', 'reason', 'logic', 'argument',
        'paradox', 'metaphysics', 'epistemology', 'virtue', 'justice',
        'happiness', 'purpose', 'identity', 'self', 'society', 'democracy',
      ],
      'health': [
        'health', 'medical', 'doctor', 'symptom', 'disease', 'medicine',
        'exercise', 'diet', 'nutrition', 'sleep', 'stress', 'mental health',
        'therapy', 'fitness', 'workout', 'body', 'heart', 'brain', 'blood',
        'immune', 'vitamin', 'supplement', 'weight', 'calories', 'protein',
        'carbohydrate', 'fat', 'wellbeing', 'anxiety', 'depression',
      ],
      'history': [
        'history', 'historical', 'ancient', 'medieval', 'war', 'revolution',
        'civilization', 'empire', 'dynasty', 'century', 'decade', 'era',
        'timeline', 'event', 'battle', 'treaty', 'colonization', 'independence',
        'president', 'king', 'queen', 'leader', 'movement', 'culture',
        'tradition', 'artifact', 'archaeology', 'roman', 'greek', 'egyptian',
        'world war', 'cold war',
      ],
      'technology': [
        'technology', 'tech', 'ai', 'artificial intelligence', 'machine learning',
        'deep learning', 'neural network', 'robot', 'automation', 'internet',
        'cloud', 'blockchain', 'cryptocurrency', 'bitcoin', 'nft', 'vr',
        'augmented reality', 'iot', 'smart', 'device', 'hardware', 'software',
        'processor', 'gpu', 'cpu', 'memory', 'storage', 'network', 'security',
        'privacy', 'data', 'encryption',
      ],
      'help': [
        'help', 'how to', 'how do', 'what is', 'what are', 'explain',
        'tell me', 'show me', 'guide', 'tutorial', 'steps', 'instructions',
        'advice', 'suggest', 'recommend', 'tips', 'trick', 'best way',
        'can you', 'could you', 'please', 'assist', 'support',
      ],
    };

    // Score each topic by keyword matches
    String bestTopic = 'general';
    int bestScore = 0;

    for (final entry in topicKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestTopic = entry.key;
      }
    }

    return bestTopic;
  }

  /// Selects the most appropriate response from the library.
  String _selectResponse(
    String topic,
    String preset,
    double temperature,
    String userMessage,
  ) {
    final topicResponses = _responseLibrary[topic];
    if (topicResponses == null || topicResponses.isEmpty) {
      return _responseLibrary['general']![preset] ??
          _responseLibrary['general']!['general']!;
    }

    // Try exact preset match first
    String? response = topicResponses[preset];

    // Fallback to 'general' preset for this topic
    response ??= topicResponses['general'];

    // Fallback to general topic, same preset
    response ??= _responseLibrary['general']![preset];

    // Final fallback
    response ??= _responseLibrary['general']!['general']!;

    // With high temperature, occasionally mix in a creative variant
    if (temperature > 1.2 && topicResponses.containsKey('creative')) {
      if (_random.nextDouble() < 0.4) {
        response = topicResponses['creative'] ?? response;
      }
    }

    // With technical preset or low temperature, prefer technical/concise
    if (temperature < 0.4 && topicResponses.containsKey('concise')) {
      response = topicResponses['concise'] ?? response;
    }

    return response!;
  }

  /// Splits a response string into word-level tokens preserving punctuation.
  List<String> _tokenize(String text) {
    if (text.trim().isEmpty) return [];

    final tokens = <String>[];
    final words = text.split(' ');
    for (final word in words) {
      if (word.isNotEmpty) {
        tokens.add(word);
      }
    }
    return tokens;
  }

  /// Pre-written response library keyed by topic then preset.
  final Map<String, Map<String, String>> _responseLibrary = {
    'general': {
      'general':
          "That's a great question! I'm running entirely on your device, processing everything locally without any internet connection. As a privacy-first AI assistant, I'm here to help you think through problems, explore ideas, and get things done. What would you like to dive into today?",
      'creative':
          "Oh, what a delightful inquiry! Imagine me as a tiny, brilliant mind living inside your phone — no cloud, no servers, just pure local intelligence humming away. I love exploring ideas from every angle. Tell me more about what's on your mind, and let's see where our conversation takes us!",
      'technical':
          "Query received. Processing locally on-device with zero network dependency. I operate as a stateless inference engine — each response generated from pattern recognition and knowledge encoding. Ready to assist with technical queries, analysis, or problem decomposition. Please provide additional context for optimal response quality.",
      'concise':
          "Got it. I'm your local AI assistant — no internet needed. What do you need help with?",
      'detailed':
          "Thank you for your message. As a locally-running AI assistant, I process all queries entirely on your device — your data never leaves your phone. I can help with a wide range of tasks: answering questions, explaining concepts, helping with writing, analyzing problems, brainstorming ideas, and much more. I work best when you give me specific, detailed questions, but I'm also happy to handle open-ended conversations. My responses are generated using pattern matching and a curated knowledge base, so while I may not have real-time information, I can provide thoughtful and helpful responses on most topics. What would you like to explore?",
    },
    'coding': {
      'general':
          "Great coding question! Here's how I'd approach this:\n\nFirst, let's break down the problem into smaller, manageable pieces. Good software design starts with understanding the requirements clearly.\n\n**Key principles to keep in mind:**\n- Write clean, readable code that other developers (and future you) can understand\n- Follow the single responsibility principle — each function should do one thing well\n- Handle edge cases and errors gracefully\n- Write tests to verify your logic\n\nFor the specific implementation, I'd recommend starting with a simple prototype, then refining it. What programming language or framework are you working with? That'll help me give you more targeted advice.",
      'creative':
          "Ooh, coding is like crafting a spell! Each line of code is an incantation that tells the computer exactly what to do. Let me paint you a picture of how I'd approach this...\n\nThink of your program as a story with characters (objects), plot (logic flow), and a setting (environment). The best code reads almost like prose — clear, purposeful, and elegant.\n\nHere's a creative way to think about the architecture:\n- Your data models are the nouns (the 'things' in your world)\n- Your functions are the verbs (the 'actions' things can take)\n- Your UI is the stage where the drama unfolds\n\nWhat's the story you're trying to tell with your code?",
      'technical':
          "Technical analysis of your coding query:\n\n**Recommended approach:**\n1. Define data structures and types first\n2. Implement core business logic in pure functions (no side effects)\n3. Add error handling with typed exceptions\n4. Write unit tests for each function\n5. Integrate UI/IO layer last\n\n**Performance considerations:**\n- Time complexity: aim for O(n log n) or better\n- Space complexity: minimize heap allocations in hot paths\n- Use lazy evaluation where possible\n- Cache expensive computations\n\n**Code quality metrics to track:**\n- Cyclomatic complexity < 10 per function\n- Test coverage > 80%\n- Zero linting warnings\n\nShare your specific code snippet for targeted optimization advice.",
      'concise':
          "Here's the direct answer:\n\n1. Define your data model\n2. Implement the logic\n3. Handle errors\n4. Test it\n\nWhat specific part are you stuck on?",
      'detailed':
          "Let me give you a comprehensive breakdown of how to approach this coding challenge.\n\n**Understanding the Problem:**\nBefore writing a single line of code, make sure you fully understand what you're building. Write down the inputs, expected outputs, and any constraints.\n\n**Architecture Decision:**\nChoose the right pattern for your use case:\n- MVC/MVVM for UI-heavy applications\n- Repository pattern for data access\n- Observer pattern for reactive state\n- Factory pattern for object creation\n\n**Implementation Steps:**\n1. Create your data models with proper typing\n2. Write your business logic in isolated, testable functions\n3. Implement error handling with meaningful error messages\n4. Build the UI layer that consumes your logic\n5. Add logging for debugging\n\n**Common Pitfalls to Avoid:**\n- Premature optimization\n- Tight coupling between components\n- Ignoring edge cases (null values, empty arrays, network failures)\n- Not handling async errors properly\n\n**Testing Strategy:**\n- Unit tests for business logic\n- Integration tests for data layer\n- Widget tests for UI components\n- End-to-end tests for critical user flows\n\nWould you like me to dive deeper into any of these areas?",
    },
    'math': {
      'general':
          "Let me work through this mathematical problem step by step.\n\n**Setting up the problem:**\nFirst, let's identify what we know and what we're trying to find. Breaking down complex math problems into smaller steps makes them much more manageable.\n\n**Approach:**\n1. Identify the type of problem (algebraic, geometric, statistical, etc.)\n2. Write down the given information\n3. Choose the appropriate formula or method\n4. Solve step by step, showing all work\n5. Verify the answer makes sense\n\nMathematics is all about logical reasoning — each step should follow naturally from the previous one. Would you like me to walk through a specific calculation or explain a mathematical concept in more detail?",
      'technical':
          "Mathematical analysis:\n\n**Problem classification:** Requires formal mathematical treatment\n\n**Applicable theorems and formulas:**\n- Check boundary conditions first\n- Apply relevant axioms\n- Use proof by induction or contradiction if needed\n\n**Computational approach:**\n- Exact arithmetic where possible\n- Floating point considerations: IEEE 754 double precision gives ~15 significant digits\n- Numerical stability: avoid catastrophic cancellation\n\n**Verification:**\n- Dimensional analysis\n- Order of magnitude check\n- Special case validation\n\nProvide the specific equation or problem for step-by-step solution.",
      'concise':
          "Here's the solution:\n\nIdentify the variables, apply the formula, compute, then verify.\n\nWhat's the specific equation?",
      'detailed':
          "Let me provide a thorough mathematical explanation.\n\n**Conceptual Foundation:**\nMathematics is built on axioms — self-evident truths from which all theorems are derived. Understanding the foundational concepts helps you apply them correctly.\n\n**Problem-Solving Framework:**\n1. **Read carefully** — identify all given information and constraints\n2. **Draw a diagram** — visual representation often reveals the solution\n3. **Choose your tools** — which formulas or theorems apply?\n4. **Execute methodically** — show every step\n5. **Check your work** — substitute back, use estimation\n\n**Common Mathematical Techniques:**\n- Substitution and elimination for systems of equations\n- Integration by parts for complex integrals\n- The chain rule for composite function derivatives\n- Bayes' theorem for conditional probability\n\nShare the specific problem and I'll solve it step by step.",
    },
    'science': {
      'general':
          "Science is all about understanding the natural world through observation, hypothesis, and experimentation. Let me share what I know about this topic.\n\n**The Scientific Method in Action:**\n1. Observe a phenomenon\n2. Form a hypothesis (testable prediction)\n3. Design and conduct experiments\n4. Analyze data\n5. Draw conclusions and refine the theory\n\nScience is never 'finished' — every discovery opens new questions. The most exciting scientific frontiers today include quantum computing, gene editing, dark matter research, and climate science.\n\nWhat specific aspect of science are you curious about? I'd love to explore it with you!",
      'creative':
          "Science is humanity's greatest adventure — a never-ending quest to pull back the curtain on reality's deepest secrets! Every atom in your body was forged in the heart of a dying star. The fact that you can read these words is the result of billions of years of evolution, chemistry, and physics conspiring together.\n\nImagine: the same forces that govern the orbit of distant galaxies also determine how the neurons in your brain fire as you read this. We are the universe becoming aware of itself!\n\nWhat scientific wonder would you like to explore today?",
      'technical':
          "Scientific query analysis:\n\n**Domain:** Natural sciences\n**Methodology:** Empirical observation + theoretical modeling\n\n**Current scientific consensus on this topic:**\n- Peer-reviewed literature supports multiple lines of evidence\n- Experimental reproducibility is the gold standard\n- Uncertainty quantification is essential\n\n**Key variables and relationships:**\n- Independent variables: controlled by experimenter\n- Dependent variables: measured outcomes\n- Confounding variables: must be controlled\n\nFor precise scientific information, always cross-reference with primary literature.",
      'concise':
          "Here's the scientific explanation:\n\nThe phenomenon you're asking about is governed by well-established physical, chemical, or biological principles. The key mechanism involves energy transfer, molecular interactions, or evolutionary adaptation depending on the specific topic.\n\nWhat's the specific scientific question?",
      'detailed':
          "Let me give you a comprehensive scientific explanation.\n\n**Background and Context:**\nScience builds on centuries of accumulated knowledge. Understanding the historical development of a concept often illuminates why we understand it the way we do today.\n\n**Core Principles:**\nThe natural world operates according to consistent, discoverable laws. These laws don't change based on who's observing them — that's what makes science universal.\n\n**Relevant Scientific Concepts:**\n- Conservation laws (energy, mass, momentum) govern physical systems\n- Thermodynamics explains energy flow and entropy\n- Quantum mechanics describes behavior at the atomic scale\n- Evolutionary theory explains biological diversity\n- Chemical bonding determines molecular properties\n\nWhat specific scientific topic would you like to explore in depth?",
    },
    'writing': {
      'general':
          "Writing is both a craft and an art — it can always be improved with practice and the right techniques. Here's how I'd approach your writing task:\n\n**The Writing Process:**\n1. **Prewrite** — brainstorm, outline, gather ideas\n2. **Draft** — get ideas down without self-censoring\n3. **Revise** — restructure for clarity and flow\n4. **Edit** — fix grammar, style, word choice\n5. **Proofread** — final check for errors\n\n**Keys to Effective Writing:**\n- Know your audience — write for them, not yourself\n- Have a clear purpose — what should the reader take away?\n- Use active voice when possible\n- Vary sentence length for rhythm\n- Show, don't tell (especially in fiction)\n\nWhat type of writing are you working on? I can give more specific guidance!",
      'creative':
          "Ah, the blank page — both terrifying and full of infinite possibility! Writing is the closest thing humans have to magic: with just 26 letters, you can create entire worlds, make people cry, inspire revolutions, or capture a feeling that was previously inexpressible.\n\nHere's my creative writing philosophy:\n- **Write badly first** — perfectionism kills creativity. Get the ideas out!\n- **Steal like an artist** — read widely and let great writing influence you\n- **Find your voice** — the most valuable thing you can offer is your unique perspective\n- **Specificity is the soul of narrative** — not 'a dog' but 'a three-legged beagle named Captain'\n\nWhat are you writing? Let's make it sing!",
      'technical':
          "Writing analysis and optimization:\n\n**Document structure requirements:**\n- Clear thesis/purpose statement in opening paragraph\n- Logical argument flow with topic sentences\n- Evidence and examples supporting each claim\n- Transitions between sections\n- Conclusion that synthesizes key points\n\n**Readability metrics:**\n- Flesch-Kincaid Grade Level: target 8-12 for general audience\n- Average sentence length: 15-20 words optimal\n- Passive voice: less than 10% of sentences\n- Paragraph length: 3-5 sentences\n\nShare your draft for specific feedback.",
      'concise':
          "Good writing is clear, concise, and purposeful.\n\nKey tips:\n- One idea per paragraph\n- Active voice\n- Cut unnecessary words\n- Strong verbs\n\nWhat do you need help writing?",
    },
    'creative': {
      'general':
          "Let's unleash some creativity! I love exploring imaginative ideas and helping bring creative visions to life.\n\n**Creative Thinking Techniques:**\n- **Mind mapping** — start with a central idea and branch outward\n- **SCAMPER** — Substitute, Combine, Adapt, Modify, Put to other uses, Eliminate, Reverse\n- **Random input** — introduce an unrelated concept and find connections\n- **Worst possible idea** — brainstorm terrible ideas, then invert them\n- **Role storming** — think from the perspective of different characters or personas\n\nCreativity thrives when constraints are loosened and judgment is suspended. There are no bad ideas in brainstorming!\n\nWhat creative project are you working on? Let's explore it together!",
      'creative':
          "Oh, now we're in my element! Creativity is the lifeblood of human experience — it's what separates us from mere calculation machines.\n\nImagine a world where every thought you had left a visible trail of light — your mind would look like a galaxy of ideas, each neuron firing like a distant star. That's what creativity feels like from the inside: a cosmos of possibility.\n\nFor your creative endeavor, I'd suggest:\n- Start with 'What if?' — the two most powerful words in the creative vocabulary\n- Embrace the unexpected — the best ideas often come from unlikely combinations\n- Give yourself permission to be weird — the strange and surprising are memorable\n- Create from emotion — what feeling do you want to evoke?\n\nWhat's your creative vision? Let's build it!",
      'concise':
          "Creativity tip: combine two unrelated things in an unexpected way.\n\nWhat's your project? I'll help brainstorm.",
    },
    'philosophy': {
      'general':
          "Philosophy asks the deepest questions about existence, knowledge, morality, and meaning. These are questions that don't have simple answers — and that's precisely what makes them so fascinating.\n\n**The Major Branches of Philosophy:**\n- **Metaphysics** — What is the nature of reality? Does free will exist?\n- **Epistemology** — How do we know what we know? What is truth?\n- **Ethics** — What is right and wrong? How should we live?\n- **Logic** — What constitutes valid reasoning?\n- **Aesthetics** — What is beauty? What is art?\n\nThe great philosophers — Plato, Aristotle, Descartes, Kant, Nietzsche, Wittgenstein — didn't give us answers so much as better questions.\n\nWhich philosophical question is on your mind?",
      'creative':
          "Philosophy is the art of asking questions so fundamental that most people never think to ask them at all.\n\nConsider this: you cannot prove that you're not a brain in a vat, experiencing a perfectly simulated reality. You cannot even prove that other people are conscious — maybe you're the only mind in the universe and everything else is an elaborate backdrop.\n\nAnd yet — here we are, two minds having a conversation about the nature of existence. Isn't that extraordinary?\n\nThe most profound philosophical insight might be this: the fact that you can question reality means you are real enough to do the questioning. Cogito, ergo sum — I think, therefore I am.\n\nWhat philosophical puzzle keeps you up at night?",
      'technical':
          "Philosophical analysis:\n\n**Logical framework:**\n- Deductive reasoning: valid if premises are true, conclusion must be true\n- Inductive reasoning: strong evidence supports but doesn't guarantee conclusion\n- Abductive reasoning: inference to the best explanation\n\n**Major philosophical positions on this topic:**\n- Rationalist view: knowledge derived from reason alone\n- Empiricist view: knowledge derived from sensory experience\n- Pragmatist view: truth is what works in practice\n- Existentialist view: existence precedes essence\n\n**Key distinctions:**\n- Necessary vs. contingent truths\n- A priori vs. a posteriori knowledge\n- Descriptive vs. normative claims\n\nWhich philosophical tradition or question would you like to explore further?",
      'concise':
          "Philosophy in brief: question everything, assume nothing, follow the argument wherever it leads.\n\nWhat's the philosophical question you're wrestling with?",
    },
    'health': {
      'general':
          "Health is one of our most valuable assets, and understanding it better helps us make informed decisions. Let me share what I know.\n\n**Key Pillars of Good Health:**\n- **Sleep** — 7-9 hours for most adults; critical for memory, immunity, and mood\n- **Nutrition** — balanced diet with whole foods, vegetables, lean proteins, healthy fats\n- **Exercise** — 150 minutes of moderate activity per week (WHO recommendation)\n- **Stress management** — mindfulness, social connection, hobbies\n- **Preventive care** — regular check-ups, screenings, vaccinations\n\nRemember: I'm an AI assistant, not a medical professional. For specific health concerns, always consult a qualified healthcare provider.\n\nWhat health topic would you like to explore?",
      'concise':
          "For health questions, the key principles are: sleep well, eat balanced meals, exercise regularly, manage stress, and see a doctor for specific concerns.\n\nWhat's your specific health question? Note: I'm an AI, not a medical professional.",
      'technical':
          "Health analysis:\n\n**Evidence-based recommendations:**\n- Sleep: 7-9 hours/night (National Sleep Foundation)\n- Exercise: 150 min moderate or 75 min vigorous aerobic activity/week (WHO)\n- Nutrition: Mediterranean diet pattern shows strongest evidence for longevity\n- BMI: 18.5-24.9 considered healthy range (though imperfect metric)\n\n**Important disclaimer:** This is general health information only. For diagnosis, treatment, or medical advice, consult a licensed healthcare professional.\n\nWhat specific health topic are you researching?",
    },
    'history': {
      'general':
          "History is the story of humanity — our triumphs, failures, discoveries, and the forces that shaped the world we live in today. Let me share what I know.\n\n**Why History Matters:**\n- Understanding the past helps us make sense of the present\n- Historical patterns often repeat — learning from them helps us avoid mistakes\n- History reveals the complexity of human nature and society\n- It gives us perspective on how much (and how little) things change\n\n**Key Historical Themes:**\n- The rise and fall of civilizations\n- The role of technology in shaping society\n- The struggle for rights and freedom\n- The impact of geography on human development\n\nWhat historical period or event are you curious about?",
      'creative':
          "History is the greatest story ever told — and it's all true! Every era had its heroes and villains, its moments of breathtaking courage and shameful cowardice, its world-changing inventions and catastrophic mistakes.\n\nImagine standing in ancient Rome as the Senate debates Caesar's fate. Or watching the Wright brothers' first flight, knowing the world would never be the same. Or witnessing the fall of the Berlin Wall as crowds surge through the gap.\n\nHistory isn't just dates and names — it's the lived experience of billions of people who faced the same fundamental human challenges we face today.\n\nWhat historical moment would you most like to explore?",
      'concise':
          "History in brief: civilizations rise and fall, technology changes everything, and human nature stays remarkably constant.\n\nWhat specific historical period or event are you asking about?",
    },
    'technology': {
      'general':
          "Technology is transforming every aspect of human life at an unprecedented pace. Let me explore this topic with you.\n\n**Current Technology Frontiers:**\n- **Artificial Intelligence** — Large language models, computer vision, autonomous systems\n- **Biotechnology** — CRISPR gene editing, mRNA vaccines, synthetic biology\n- **Quantum Computing** — Potential to solve problems impossible for classical computers\n- **Renewable Energy** — Solar, wind, and battery technology reaching cost parity\n- **Space Technology** — Reusable rockets, satellite internet, Mars missions\n\n**Technology's Double-Edged Nature:**\nEvery powerful technology brings both opportunities and risks. The key is thoughtful development and governance.\n\nWhat specific technology topic interests you?",
      'technical':
          "Technology analysis:\n\n**Current state of the art:**\n- AI/ML: Transformer architectures dominate NLP; diffusion models lead in image generation\n- Computing: Moore's Law slowing; shift to specialized hardware (GPUs, TPUs, NPUs)\n- Networking: 5G deployment ongoing; 6G research beginning\n- Storage: NVMe SSDs standard; DNA storage experimental\n- Security: Zero-trust architecture; post-quantum cryptography preparation\n\n**Key metrics to track:**\n- FLOPS per dollar (AI compute efficiency)\n- Watts per inference (energy efficiency)\n- Latency vs. throughput tradeoffs\n\nWhat specific technology are you analyzing?",
      'concise':
          "Technology moves fast. The key trends: AI everywhere, cloud-first architecture, mobile-first design, security by default.\n\nWhat specific technology question do you have?",
    },
    'help': {
      'general':
          "I'm here to help! As a locally-running AI assistant, I can assist with a wide variety of tasks:\n\n**What I can help with:**\n- **Answering questions** — on almost any topic\n- **Writing assistance** — drafting, editing, proofreading\n- **Coding help** — debugging, explaining concepts, writing functions\n- **Math problems** — step-by-step solutions\n- **Creative projects** — brainstorming, storytelling, ideation\n- **Learning** — explaining complex topics in simple terms\n- **Analysis** — breaking down problems, comparing options\n\n**How to get the best results:**\n- Be specific about what you need\n- Provide context and background\n- Tell me the format you want (list, paragraph, code, etc.)\n- Ask follow-up questions if my first answer isn't quite right\n\nWhat would you like help with today?",
      'concise':
          "I can help with questions, writing, coding, math, creative projects, and more. Just ask!\n\nWhat do you need?",
      'technical':
          "Assistance capabilities:\n\n**Supported task types:**\n- Natural language Q&A\n- Text generation and editing\n- Code analysis and generation\n- Mathematical computation guidance\n- Logical reasoning and analysis\n- Creative content generation\n\n**Limitations:**\n- No real-time data or internet access\n- Knowledge cutoff applies\n- Cannot execute code or access files\n- Not a substitute for professional advice (medical, legal, financial)\n\nSpecify your task for optimal assistance.",
    },
  };
}
