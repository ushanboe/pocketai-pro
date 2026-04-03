import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:pocketai/core/models/message.dart';
import 'package:pocketai/core/providers/conversation_provider.dart';
import 'package:pocketai/core/providers/settings_provider.dart';
import 'package:pocketai/core/services/inference_engine.dart';
import 'package:pocketai/core/models/model_info.dart';
import 'package:pocketai/core/providers/model_provider.dart';
import 'package:pocketai/features/chat/widgets/prompt_templates_bottom_sheet.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const ChatScreen({super.key, required this.onOpenDrawer});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  List<Message> _messages = [];
  bool _isGenerating = false;
  String _streamingContent = '';
  String? _activeConversationId;
  String _activeModelName = 'No model loaded';
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollFab = false;
  bool _showTokenBar = true;
  int _tokensUsed = 0;
  int _maxTokens = 512;
  final InferenceEngine _inferenceEngine = InferenceEngine();
  double? _generationSpeed;
  bool _isLoadingMessages = false;
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _ttsInitialized = false;
  bool _sttAvailable = false;
  bool _isSpeaking = false;
  bool _voiceModeActive = false;
  String _voiceModeStatus = 'idle'; // 'listening', 'thinking', 'speaking'
  String _voiceModeText = '';

  StreamSubscription<String>? _streamSubscription;
  final _uuid = const Uuid();
  final Random _random = Random();
  Timer? _ramTimer;
  int _appRamMB = 0;

  /// Strips <think>...</think> blocks from model output.
  /// Handles both complete blocks and in-progress (unclosed) blocks.
  static String _stripThinkingTags(String text) {
    // Remove complete thinking blocks
    var result = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    // Remove incomplete thinking block at end (still streaming)
    result = result.replaceAll(RegExp(r'<think>[\s\S]*$'), '');
    return result.trimLeft();
  }

  static const List<String> _starterPrompts = [
    'Explain quantum computing simply',
    'Write a short story about AI',
    'Help me debug my code',
    'What is the Fermi paradox?',
    'Give me a productivity tip',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startRamMonitor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFromSettings();
      _initTts();
      _initStt();
    });
  }

  void _startRamMonitor() {
    _updateRam();
    _ramTimer = Timer.periodic(const Duration(seconds: 3), (_) => _updateRam());
  }

  void _updateRam() {
    if (!mounted) return;
    final rss = ProcessInfo.currentRss;
    final mb = (rss / (1024 * 1024)).round();
    if (mb != _appRamMB) {
      setState(() => _appRamMB = mb);
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_voiceModeActive) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _voiceModeActive) _startVoiceListening();
          });
        }
      }
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _ttsInitialized = true;
  }

  Future<void> _initStt() async {
    _sttAvailable = await _speechToText.initialize(
      onError: (error) {
        debugPrint('[STT] Error: ${error.errorMsg}');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        debugPrint('[STT] Status: $status');
        if (status == 'notListening' && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    debugPrint('[STT] Available: $_sttAvailable');
  }

  Future<void> _speak(String text) async {
    if (!_ttsInitialized) return;
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_sttAvailable) {
      // Retry initialization once — user may have just granted permission
      _sttAvailable = await _speechToText.initialize();
    }
    if (!_sttAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available. Check app permissions and offline language packs.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
          }
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _startVoiceMode() async {
    final modelProvider = context.read<ModelProvider>();
    final modelPath = modelProvider.getModelPath(
      context.read<SettingsProvider>().settings.selectedModelId,
    );
    if (modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please download and activate a model first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_sttAvailable) {
      _sttAvailable = await _speechToText.initialize();
    }
    if (!_sttAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available. Check permissions.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() {
      _voiceModeActive = true;
      _voiceModeStatus = 'listening';
      _voiceModeText = '';
    });
    _startVoiceListening();
  }

  void _stopVoiceMode() {
    _speechToText.stop();
    _flutterTts.stop();
    if (_isGenerating) {
      _stopGeneration();
    }
    setState(() {
      _voiceModeActive = false;
      _voiceModeStatus = 'idle';
      _voiceModeText = '';
      _isListening = false;
      _isSpeaking = false;
    });
  }

  void _startVoiceListening() async {
    if (!_voiceModeActive || !mounted) return;
    setState(() {
      _voiceModeStatus = 'listening';
      _voiceModeText = '';
    });
    await _speechToText.listen(
      onResult: (result) {
        if (!mounted || !_voiceModeActive) return;
        setState(() => _voiceModeText = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _processVoiceInput(result.recognizedWords.trim());
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
    setState(() => _isListening = true);
  }

  void _processVoiceInput(String text) {
    if (!_voiceModeActive || !mounted) return;
    setState(() {
      _voiceModeStatus = 'thinking';
      _isListening = false;
    });
    _textController.text = text;
    _sendMessage();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 768,
      maxHeight: 768,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pendingImageBytes = bytes;
      _pendingImageName = picked.name;
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF3B82F6)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ramTimer?.cancel();
    _flutterTts.stop();
    _streamSubscription?.cancel();
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final shouldShow = maxExtent - current > 200;
    if (shouldShow != _showScrollFab) {
      setState(() {
        _showScrollFab = shouldShow;
      });
    }
  }

  void _updateFromSettings() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>().settings;
    setState(() {
      _activeModelName = settings.selectedModelName.isNotEmpty
          ? settings.selectedModelName
          : 'No model loaded';
      _showTokenBar = settings.showTokenCount;
      _maxTokens = settings.maxTokens;
    });
  }

  void _estimateTokensUsed() {
    int total = 0;
    for (final msg in _messages) {
      total += msg.tokenCount;
    }
    if (_streamingContent.isNotEmpty) {
      total += Message.estimateTokenCount(_streamingContent);
    }
    setState(() {
      _tokensUsed = total;
    });
  }

  /// Public method called by MainShell to load a specific conversation.
  Future<void> loadConversation(String id) async {
    if (!mounted) return;

    if (_isGenerating) {
      _inferenceEngine.cancel();
      _streamSubscription?.cancel();
      _streamSubscription = null;
    }

    setState(() {
      _isLoadingMessages = true;
      _activeConversationId = id;
      _messages = [];
      _streamingContent = '';
      _isGenerating = false;
      _generationSpeed = null;
    });

    try {
      final conversationProvider = context.read<ConversationProvider>();
      final loaded = await conversationProvider.getMessages(id);

      final conversations = conversationProvider.conversations;
      final conv = conversations.where((c) => c.id == id).firstOrNull;

      if (mounted) {
        setState(() {
          _messages = loaded;
          _isLoadingMessages = false;
          if (conv != null && conv.modelName.isNotEmpty) {
            _activeModelName = conv.modelName;
          }
          _maxTokens = conv?.maxTokens ??
              context.read<SettingsProvider>().settings.maxTokens;
        });
        _estimateTokensUsed();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load conversation. Starting fresh.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Public method called by MainShell to start a fresh conversation.
  void startNewConversation() {
    if (!mounted) return;

    if (_isGenerating) {
      _inferenceEngine.cancel();
      _streamSubscription?.cancel();
      _streamSubscription = null;
    }

    setState(() {
      _activeConversationId = null;
      _messages = [];
      _streamingContent = '';
      _isGenerating = false;
      _generationSpeed = null;
      _tokensUsed = 0;
    });
    _textController.clear();
    _updateFromSettings();
  }

  Future<void> _createNewConversation() async {
    final settings = context.read<SettingsProvider>().settings;
    final conversation =
        await context.read<ConversationProvider>().createConversation(
              settings,
              settings.selectedModelId,
              settings.selectedModelName,
            );
    setState(() {
      _activeConversationId = conversation.id;
      _maxTokens = conversation.maxTokens;
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    // Verify an LLM model is active before proceeding
    final modelProvider = context.read<ModelProvider>();
    final modelPath = modelProvider.getModelPath(
      context.read<SettingsProvider>().settings.selectedModelId,
    );
    if (modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please download and activate a model first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    _textController.clear();

    if (_activeConversationId == null) {
      await _createNewConversation();
    }

    final conversationId = _activeConversationId!;
    final settings = context.read<SettingsProvider>().settings;

    final userMessage = Message(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      tokenCount: Message.estimateTokenCount(text),
      generationTimeMs: 0,
    );

    await context
        .read<ConversationProvider>()
        .addMessage(conversationId, userMessage);

    setState(() {
      _messages = [..._messages, userMessage];
      _isGenerating = true;
      _streamingContent = '';
      _generationSpeed = null;
    });

    _estimateTokensUsed();
    _scrollToBottom();

    final startTime = DateTime.now();

    // Check if vision model is active and pass image + mmprojPath
    final mmprojPath = modelProvider.getModelMmprojPath(
      settings.selectedModelId,
    );
    final imageBytes = _pendingImageBytes;
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
    });

    // Show debug info for vision requests
    if (imageBytes != null && mmprojPath != null) {
      final imgKB = (imageBytes.length / 1024).round();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vision: ${imgKB}KB image, mmproj: ${mmprojPath.split('/').last}, ctx: 8192'),
          backgroundColor: const Color(0xFF3B82F6),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Determine which backend to use based on the active model
    final activeModel = modelProvider.activeModel;
    final backendType = activeModel?.backendType ?? InferenceBackendType.fllama;

    final stream =
        _inferenceEngine.generateResponse(
          text, _messages, settings, modelPath,
          mmprojPath: mmprojPath,
          imageBytes: imageBytes,
          backendType: backendType,
        );
    _streamSubscription = stream.listen(
      (token) {
        if (!mounted) return;
        setState(() {
          _streamingContent += token;
        });
        _estimateTokensUsed();
        _scrollToBottom();
      },
      onDone: () async {
        if (!mounted) return;
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds;
        final enableThinking = context.read<SettingsProvider>().settings.enableThinking;
        var finalContent = enableThinking ? _streamingContent : _stripThinkingTags(_streamingContent);
        if (finalContent.trim().isEmpty) {
          final secs = (elapsed / 1000).round();
          final isVision = imageBytes != null && mmprojPath != null;
          finalContent = isVision
              ? '[Vision failed after ${secs}s. RAM: $_appRamMB MB. The model loaded but produced no output — this usually means the image embeddings + context exceeded available memory. Try: 1) Close all other apps 2) Restart phone 3) Use a simpler image]'
              : '[No response generated after ${secs}s. Try a different model or restart the app.]';
        }
        final tokenCount = Message.estimateTokenCount(finalContent);
        final speed = elapsed > 0
            ? tokenCount / (elapsed / 1000.0)
            : _random.nextInt(18).toDouble() + 8;

        final assistantMessage = Message(
          id: _uuid.v4(),
          conversationId: conversationId,
          role: 'assistant',
          content: finalContent,
          timestamp: DateTime.now(),
          tokenCount: tokenCount,
          generationTimeMs: elapsed,
        );

        await context
            .read<ConversationProvider>()
            .addMessage(conversationId, assistantMessage);

        if (mounted) {
          setState(() {
            _messages = [..._messages, assistantMessage];
            _isGenerating = false;
            _streamingContent = '';
            _generationSpeed = speed;
          });
          _estimateTokensUsed();
          _scrollToBottom();

          // Voice mode: auto-speak response and continue loop
          if (_voiceModeActive && finalContent.isNotEmpty) {
            setState(() {
              _voiceModeStatus = 'speaking';
              _voiceModeText = finalContent;
            });
            _flutterTts.speak(finalContent);
            setState(() => _isSpeaking = true);
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isGenerating = false;
          _streamingContent = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _stopGeneration() async {
    _inferenceEngine.cancel();
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    if (!mounted) return;

    final partial = _streamingContent;
    if (partial.isNotEmpty && _activeConversationId != null) {
      final assistantMessage = Message(
        id: _uuid.v4(),
        conversationId: _activeConversationId!,
        role: 'assistant',
        content: partial,
        timestamp: DateTime.now(),
        tokenCount: Message.estimateTokenCount(partial),
        generationTimeMs: 0,
      );

      await context
          .read<ConversationProvider>()
          .addMessage(_activeConversationId!, assistantMessage);

      if (mounted) {
        setState(() {
          _messages = [..._messages, assistantMessage];
          _isGenerating = false;
          _streamingContent = '';
        });
        _estimateTokensUsed();
      }
    } else {
      setState(() {
        _isGenerating = false;
        _streamingContent = '';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showMessageOptions(Message message) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Color(0xFF94A3B8)),
                title: const Text('Copy',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Color(0xFF94A3B8)),
                title: const Text('Share',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(message.content, subject: 'MyTinyAI Message');
                },
              ),
              if (message.role == 'assistant')
                ListTile(
                  leading:
                      const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                  title: const Text('Regenerate',
                      style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (_activeConversationId != null) {
                      await context
                          .read<ConversationProvider>()
                          .deleteMessage(message.id, _activeConversationId!);
                      final idx = _messages.indexOf(message);
                      if (idx != -1) {
                        String? userText;
                        for (int i = idx - 1; i >= 0; i--) {
                          if (_messages[i].role == 'user') {
                            userText = _messages[i].content;
                            break;
                          }
                        }
                        setState(() {
                          _messages = _messages
                              .where((m) => m.id != message.id)
                              .toList();
                        });
                        if (userText != null && mounted) {
                          _textController.text = userText;
                          await _sendMessage();
                        }
                      }
                    }
                  },
                ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_activeConversationId != null) {
                    await context
                        .read<ConversationProvider>()
                        .deleteMessage(message.id, _activeConversationId!);
                    setState(() {
                      _messages = _messages
                          .where((m) => m.id != message.id)
                          .toList();
                    });
                    _estimateTokensUsed();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportConversation() async {
    if (_messages.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('MyTinyAI Conversation Export');
    buffer.writeln('Model: $_activeModelName');
    buffer.writeln('Date: ${DateTime.now().toLocal()}');
    buffer.writeln('---');
    for (final msg in _messages) {
      final role = msg.role == 'user' ? 'You' : 'AI';
      buffer.writeln('[$role]: ${msg.content}');
      buffer.writeln();
    }
    await Share.share(buffer.toString(), subject: 'MyTinyAI Conversation');
  }

  void _showConversationMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem<String>(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.ios_share_outlined, color: Color(0xFF94A3B8), size: 18),
              SizedBox(width: 12),
              Text('Export Chat', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'new',
          child: Row(
            children: [
              Icon(Icons.add_comment_outlined, color: Color(0xFF94A3B8), size: 18),
              SizedBox(width: 12),
              Text('New Chat', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'export') {
        _exportConversation();
      } else if (value == 'new') {
        startNewConversation();
      }
    });
  }

  Widget _buildTokenUsageBar() {
    final fraction = _maxTokens > 0
        ? (_tokensUsed / _maxTokens).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: fraction,
            backgroundColor: const Color(0xFF1E293B),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            minHeight: 4,
          ),
          const SizedBox(height: 2),
          Text(
            '$_tokensUsed / $_maxTokens tokens',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology_outlined,
              size: 64,
              color: Color(0xFF334155),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start a conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask me anything. I work completely offline.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _starterPrompts.map((prompt) {
                return ActionChip(
                  label: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF334155)),
                  onPressed: () {
                    _textController.text = prompt;
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 18,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: _streamingContent.isNotEmpty
                  ? Builder(builder: (context) {
                      final enableThinking = context.read<SettingsProvider>().settings.enableThinking;
                      final displayText = enableThinking ? _streamingContent : _stripThinkingTags(_streamingContent);
                      if (displayText.isEmpty) return _buildTypingDots();
                      return Text(
                        displayText,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      );
                    })
                  : _buildTypingDots(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots({Color color = const Color(0xFF64748B)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.5, 1.5),
              duration: 600.ms,
              delay: Duration(milliseconds: i * 200),
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              begin: const Offset(1.5, 1.5),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.easeInOut,
            );
      }),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.role == 'user';
    final enableThinking = context.read<SettingsProvider>().settings.enableThinking;
    final displayContent = (!isUser && !enableThinking)
        ? _stripThinkingTags(message.content)
        : message.content;
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 18,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: const Color(0xFF334155), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayContent,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isUser
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (!isUser) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _speak(message.content),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.volume_up_outlined,
                                  size: 28,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildVoiceModeOverlay() {
    final statusColor = _voiceModeStatus == 'listening'
        ? const Color(0xFF3B82F6)
        : _voiceModeStatus == 'thinking'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    final statusIcon = _voiceModeStatus == 'listening'
        ? Icons.mic
        : _voiceModeStatus == 'thinking'
            ? Icons.psychology
            : Icons.volume_up;
    final statusLabel = _voiceModeStatus == 'listening'
        ? 'Listening...'
        : _voiceModeStatus == 'thinking'
            ? 'Thinking...'
            : 'Speaking...';

    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(statusIcon, size: 48, color: statusColor),
              ),
              const SizedBox(height: 32),
              const Text(
                'Hey Tiny',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (_voiceModeStatus == 'thinking')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Thinking',
                      style: TextStyle(
                        fontSize: 16,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildTypingDots(color: const Color(0xFFF59E0B)),
                  ],
                )
              else
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 24),
              if (_voiceModeText.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _voiceModeText,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _stopVoiceMode,
                icon: const Icon(Icons.stop_rounded, size: 24),
                label: const Text(
                  'End Conversation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    // Check if active model supports vision
    final settings = context.watch<SettingsProvider>().settings;
    final activeModel = context.watch<ModelProvider>().models
        .where((m) => m.id == settings.selectedModelId && m.isVision && m.isDownloaded)
        .firstOrNull;
    final supportsVision = activeModel != null;

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview bar
          if (_pendingImageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _pendingImageBytes!,
                      width: 48, height: 48, fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pendingImageName ?? 'Image attached',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                    onPressed: () => setState(() {
                      _pendingImageBytes = null;
                      _pendingImageName = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image picker button (only if vision model active)
          if (supportsVision)
            IconButton(
              icon: const Icon(Icons.image_outlined,
                  color: Color(0xFF3B82F6)),
              onPressed: _showImageSourcePicker,
              tooltip: 'Attach image',
            ),
          // Prompt templates button
          if (!supportsVision)
            IconButton(
              icon: const Icon(Icons.grid_view_outlined,
                  color: Color(0xFF64748B)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => PromptTemplatesBottomSheet(
                    onTemplateSelected: (template) {
                      _textController.text = template;
                    },
                  ),
                );
              },
            ),
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 6,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message Tiny...',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Mic button for voice input
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : const Color(0xFF64748B),
              size: 24,
            ),
            onPressed: _toggleListening,
            tooltip: _isListening ? 'Stop listening' : 'Voice input',
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isGenerating
                ? IconButton(
                    key: const ValueKey('stop'),
                    icon: const Icon(Icons.stop_circle_outlined,
                        color: Colors.red, size: 28),
                    onPressed: _stopGeneration,
                  )
                : IconButton(
                    key: const ValueKey('send'),
                    icon: const Icon(Icons.send_rounded,
                        color: Color(0xFF3B82F6), size: 28),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMessages) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_showTokenBar) _buildTokenUsageBar(),
          Expanded(
            child: _voiceModeActive
                ? _buildVoiceModeOverlay()
                : _messages.isEmpty && !_isGenerating
                    ? _buildEmptyState()
                    : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _messages.length + (_isGenerating ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length && _isGenerating) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[i]);
                    },
                  ),
          ),
          if (_showScrollFab)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: FloatingActionButton.small(
                  onPressed: _scrollToBottom,
                  backgroundColor: const Color(0xFF1E293B),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF3B82F6)),
                ),
              ),
            ),
          if (!_voiceModeActive) _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Read model name reactively from providers
    final settings = context.watch<SettingsProvider>().settings;
    final modelName = settings.selectedModelName.isNotEmpty
        ? settings.selectedModelName
        : 'No model loaded';

    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onOpenDrawer,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modelName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 10, color: Color(0xFF22C55E)),
              const SizedBox(width: 4),
              const Text(
                'Local Chat',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF22C55E),
                ),
              ),
              if (_appRamMB > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.memory, size: 10, color: _appRamMB > 3000 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
                const SizedBox(width: 2),
                Text(
                  '${_appRamMB} MB',
                  style: TextStyle(
                    fontSize: 11,
                    color: _appRamMB > 3000 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _voiceModeActive ? Icons.headset_off : Icons.headset_mic_outlined,
            color: _voiceModeActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          onPressed: _voiceModeActive ? _stopVoiceMode : _startVoiceMode,
          tooltip: 'Hey Tiny',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
          onPressed: _showConversationMenu,
        ),
      ],
    );
  }
}
