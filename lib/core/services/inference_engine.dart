import 'dart:typed_data';

import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/core/models/message.dart';
import 'package:pocketai/core/models/model_info.dart';
import 'package:pocketai/core/services/inference_backend.dart';
import 'package:pocketai/core/services/fllama_backend.dart';
import 'package:pocketai/core/services/litertlm_backend.dart';

/// Routes inference requests to the correct backend based on model type.
///
/// Usage stays identical to the old InferenceEngine — call generateResponse()
/// and get a Stream<String> back. The only new parameter is [backendType],
/// which tells the engine which runtime to use.
///
/// To add a new backend:
/// 1. Create a class implementing InferenceBackend
/// 2. Add a case to _backendFor()
/// 3. Add the enum value to InferenceBackendType
class InferenceEngine {
  final _backends = <InferenceBackendType, InferenceBackend>{};
  InferenceBackendType? _activeBackendType;

  /// Returns (or creates) the backend for the given type.
  InferenceBackend _backendFor(InferenceBackendType type) {
    return _backends.putIfAbsent(type, () {
      switch (type) {
        case InferenceBackendType.fllama:
          return FllamaBackend();
        case InferenceBackendType.litertlm:
          return LiteRtLmBackend();
      }
    });
  }

  /// Generates a streaming response using the appropriate backend.
  Stream<String> generateResponse(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    String modelPath, {
    String? mmprojPath,
    Uint8List? imageBytes,
    InferenceBackendType backendType = InferenceBackendType.fllama,
  }) {
    // Cancel any in-flight request on the previous backend
    cancel();
    _activeBackendType = backendType;

    final backend = _backendFor(backendType);
    return backend.generateResponse(
      userMessage,
      history,
      settings,
      modelPath,
      mmprojPath: mmprojPath,
      imageBytes: imageBytes,
    );
  }

  /// Cancels the active inference request on whichever backend is running.
  void cancel() {
    if (_activeBackendType != null) {
      _backends[_activeBackendType]?.cancel();
    }
  }
}
