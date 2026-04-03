import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fllama/fllama.dart' as fllama;
import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/core/models/message.dart';

class InferenceEngine {
  int? _activeRequestId;
  StreamController<String>? _streamController;
  String _previousResponse = '';

  /// Generates a streaming response using the on-device LLM via fllama.
  /// Returns a Stream<String> where each event is an incremental text chunk.
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
    _previousResponse = '';

    _runInference(userMessage, history, settings, modelPath, mmprojPath: mmprojPath, imageBytes: imageBytes);

    return _streamController!.stream;
  }

  /// Cancels the active inference request.
  void cancel() {
    if (_activeRequestId != null) {
      fllama.fllamaCancelInference(_activeRequestId!);
      _activeRequestId = null;
    }
    _streamController?.close();
    _streamController = null;
  }

  Future<void> _runInference(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    String modelPath, {
    String? mmprojPath,
    Uint8List? imageBytes,
  }) async {
    try {
      final isVision = mmprojPath != null && imageBytes != null;
      final contextSize = isVision ? 8192 : 2048;
      // Vision: force lower temperature for focused descriptions, boost maxTokens for detail
      final temperature = isVision ? 0.3 : settings.temperature.clamp(0.1, 2.0);
      final maxTokens = isVision ? 1024 : settings.maxTokens;
      final messages = <fllama.Message>[];

      // Add system prompt (shorter for vision to save context)
      if (settings.systemPrompt.isNotEmpty) {
        if (isVision) {
          messages.add(fllama.Message(fllama.Role.system, 'You are a vision AI. Describe images in detail: objects, people, text, colors, actions, and spatial layout. Be specific and accurate.'));
        } else {
          messages.add(fllama.Message(fllama.Role.system, settings.systemPrompt));
        }
      }

      if (isVision) {
        // Vision: only send the image message — history eats context needed for image embeddings
        final b64 = base64Encode(imageBytes!);
        messages.add(fllama.Message(
          fllama.Role.user,
          '<img src="data:image/jpeg;base64,$b64">\n\n$userMessage',
        ));
        print('[Vision] Image bytes: ${imageBytes.length}, base64 len: ${b64.length}, prompt: "$userMessage"');
        print('[Vision] mmproj: $mmprojPath');
        print('[Vision] Using context: $contextSize, maxTokens: $maxTokens, temp: $temperature');
      } else {
        // Text: send full conversation history
        for (final msg in history) {
          final role =
              msg.role == 'user' ? fllama.Role.user : fllama.Role.assistant;
          messages.add(fllama.Message(role, msg.content));
        }
      }

      final request = fllama.OpenAiRequest(
        messages: messages,
        modelPath: modelPath,
        mmprojPath: mmprojPath,
        temperature: temperature,
        maxTokens: maxTokens,
        contextSize: contextSize,
        presencePenalty: 0.0,
        frequencyPenalty: 0.0,
        topP: 1.0,
        numGpuLayers: 99,
      );

      print('[Inference] Starting ${isVision ? "vision" : "text"} inference, ${messages.length} messages, context: $contextSize');

      _activeRequestId =
          await fllama.fllamaChat(request, (response, json, done) {
        if (_streamController == null || _streamController!.isClosed) return;

        // fllama returns cumulative text — extract the new portion
        final newText = response.substring(_previousResponse.length);
        _previousResponse = response;

        if (newText.isNotEmpty) {
          _streamController!.add(newText);
        }

        if (done) {
          print('[Inference] Done. Total response length: ${response.length}');
          if (response.isEmpty) {
            print('[Inference] WARNING: Empty response from model');
          }
          _activeRequestId = null;
          _streamController?.close();
        }
      });
      print('[Inference] Request ID: $_activeRequestId');
    } catch (e) {
      print('[Inference] ERROR: $e');
      _streamController?.addError(e);
      _streamController?.close();
    }
  }
}
