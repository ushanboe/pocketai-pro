import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/core/models/message.dart';
import 'package:pocketai/core/services/inference_backend.dart';

/// Backend for Gemma 4 models using Google's LiteRT-LM SDK.
///
/// Communication with the native Android SDK happens via a MethodChannel.
/// The Kotlin side (LiteRtLmPlugin) handles engine init, conversation
/// management, and streaming responses back through an EventChannel.
///
/// To port this to another app:
/// 1. Copy this file + LiteRtLmPlugin.kt
/// 2. Register the plugin in MainActivity.kt
/// 3. Add litertlm-android dependency to build.gradle.kts
class LiteRtLmBackend implements InferenceBackend {
  static const _method = MethodChannel('com.appforge.pocketai/litertlm');
  static const _events = EventChannel('com.appforge.pocketai/litertlm_stream');

  StreamController<String>? _streamController;
  StreamSubscription? _eventSubscription;
  bool _isInitialized = false;
  String? _currentModelPath;

  @override
  Stream<String> generateResponse(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    String modelPath, {
    String? mmprojPath,
    Uint8List? imageBytes,
  }) {
    cancel();
    _streamController = StreamController<String>();

    _runInference(userMessage, history, settings, modelPath,
        imageBytes: imageBytes);

    return _streamController!.stream;
  }

  @override
  void cancel() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    try {
      _method.invokeMethod('cancel');
    } catch (_) {}
    _streamController?.close();
    _streamController = null;
  }

  Future<void> _runInference(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    String modelPath, {
    Uint8List? imageBytes,
  }) async {
    try {
      // Initialize engine if model changed or first run
      if (!_isInitialized || _currentModelPath != modelPath) {
        print('[LiteRtLmBackend] Initializing engine for: $modelPath');
        await _method.invokeMethod('initialize', {
          'modelPath': modelPath,
          'backend': 'gpu', // GPU with CPU fallback
        });
        _isInitialized = true;
        _currentModelPath = modelPath;
        print('[LiteRtLmBackend] Engine initialized');
      }

      // Build the message list for the conversation
      final List<Map<String, String>> messageList = [];

      // System prompt
      if (settings.systemPrompt.isNotEmpty) {
        messageList.add({'role': 'system', 'content': settings.systemPrompt});
      }

      // Conversation history
      for (final msg in history) {
        messageList.add({'role': msg.role, 'content': msg.content});
      }

      // Current user message (don't add if already last in history)
      if (history.isEmpty || history.last.content != userMessage) {
        messageList.add({'role': 'user', 'content': userMessage});
      }

      print(
          '[LiteRtLmBackend] Sending ${messageList.length} messages, temp: ${settings.temperature}');

      // Start streaming via EventChannel
      _eventSubscription = _events.receiveBroadcastStream({
        'messages': messageList,
        'temperature': settings.temperature.clamp(0.1, 2.0),
        'topK': 64,
        'topP': 0.95,
        'maxTokens': settings.maxTokens,
        'imageBytes': imageBytes,
      }).listen(
        (event) {
          if (_streamController == null || _streamController!.isClosed) return;
          final token = event as String;
          if (token == '__DONE__') {
            print('[LiteRtLmBackend] Generation complete');
            _streamController?.close();
          } else {
            _streamController!.add(token);
          }
        },
        onError: (error) {
          print('[LiteRtLmBackend] Stream error: $error');
          _streamController?.addError(error);
          _streamController?.close();
        },
        onDone: () {
          _streamController?.close();
        },
      );
    } catch (e) {
      print('[LiteRtLmBackend] ERROR: $e');
      _streamController?.addError(e);
      _streamController?.close();
    }
  }

  /// Release the native engine to free memory.
  Future<void> dispose() async {
    cancel();
    try {
      await _method.invokeMethod('dispose');
    } catch (_) {}
    _isInitialized = false;
    _currentModelPath = null;
  }
}
