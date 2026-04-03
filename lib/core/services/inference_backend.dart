import 'dart:typed_data';

import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/core/models/message.dart';

/// Abstract interface for on-device LLM inference backends.
///
/// To add a new backend to your app:
/// 1. Create a class that implements InferenceBackend
/// 2. Implement generateResponse() to return a Stream<String> of incremental tokens
/// 3. Implement cancel() to abort in-flight inference
/// 4. Register it in InferenceEngine._backendFor()
abstract class InferenceBackend {
  /// Generates a streaming response from the model.
  /// Each event in the stream is an incremental text chunk (not cumulative).
  Stream<String> generateResponse(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    String modelPath, {
    String? mmprojPath,
    Uint8List? imageBytes,
  });

  /// Cancels the active inference request, if any.
  void cancel();
}
