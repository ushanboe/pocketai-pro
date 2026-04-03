import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:pocketai/core/models/model_info.dart';

class ModelProvider extends ChangeNotifier {
  List<ModelInfo> _models = [];
  final Map<String, HttpClient> _activeClients = {};
  final Set<String> _cancelledDownloads = {};
  SharedPreferences? _prefs;
  String? _modelsDir;
  String? _lastError;

  List<ModelInfo> get models => List.unmodifiable(_models);
  String? get lastError => _lastError;
  void clearError() { _lastError = null; }

  List<ModelInfo> get downloadedModels =>
      _models.where((m) => m.isDownloaded).toList();

  ModelInfo? get activeModel {
    try {
      return _models.firstWhere((m) => m.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Returns the absolute file path for a downloaded model, or null if not available.
  String? getModelPath(String modelId) {
    if (_modelsDir == null || modelId.isEmpty) return null;
    final model =
        _models.where((m) => m.id == modelId && m.isDownloaded).firstOrNull;
    if (model == null || model.filename.isEmpty) return null;
    return '$_modelsDir/${model.filename}';
  }

  /// Returns the absolute file path for a vision model's mmproj file, or null.
  String? getModelMmprojPath(String modelId) {
    if (_modelsDir == null || modelId.isEmpty) return null;
    final model =
        _models.where((m) => m.id == modelId && m.isDownloaded && m.isVision).firstOrNull;
    if (model == null || model.mmprojFilename.isEmpty) return null;
    final path = '$_modelsDir/${model.mmprojFilename}';
    return path;
  }

  static List<ModelInfo> get defaultCatalog => [
        ModelInfo(
          id: 'qwen3-0.6b',
          name: 'Qwen 3 0.6B',
          sizeBytes: 484000000,
          description:
              'Alibaba\'s latest ultra-compact model. Hybrid thinking mode with strong reasoning for its tiny size. Lightning fast on any device.',
          parameterCount: '0.6B',
          quantization: 'Q4_K_M',
          minRamGB: 1.0,
          capabilityTag: 'Reasoning',
          downloadUrl:
              'https://huggingface.co/lmstudio-community/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf',
          filename: 'Qwen3-0.6B-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'qwen2.5-0.5b-instruct',
          name: 'Qwen 2.5 0.5B',
          sizeBytes: 386000000,
          description:
              'Alibaba\'s ultra-compact chat model. Lightning fast inference on any device. Great for casual conversation.',
          parameterCount: '0.5B',
          quantization: 'Q4_K_M',
          minRamGB: 1.0,
          capabilityTag: 'Chat',
          downloadUrl:
              'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
          filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        ),
        ModelInfo(
          id: 'tinyllama-1.1b-chat',
          name: 'TinyLlama 1.1B Chat',
          sizeBytes: 637000000,
          description:
              'Ultra-fast chat model optimized for mobile devices. Best for quick responses and casual conversation.',
          parameterCount: '1.1B',
          quantization: 'Q4_K_M',
          minRamGB: 1.5,
          capabilityTag: 'Chat',
          downloadUrl:
              'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
          filename: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'llama-3.2-1b-instruct',
          name: 'Llama 3.2 1B',
          sizeBytes: 750000000,
          description:
              'Meta\'s lightweight instruction model. Excellent quality for its size with strong conversational abilities.',
          parameterCount: '1B',
          quantization: 'Q4_K_M',
          minRamGB: 2.0,
          capabilityTag: 'Instruct',
          downloadUrl:
              'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'smollm2-1.7b-instruct',
          name: 'SmolLM2 1.7B',
          sizeBytes: 1060000000,
          description:
              'HuggingFace\'s compact powerhouse. Punches above its weight in reasoning and instruction following.',
          parameterCount: '1.7B',
          quantization: 'Q4_K_M',
          minRamGB: 2.0,
          capabilityTag: 'Reasoning',
          downloadUrl:
              'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf',
          filename: 'SmolLM2-1.7B-Instruct-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'deepseek-r1-1.5b',
          name: 'DeepSeek R1 1.5B',
          sizeBytes: 1117000000,
          description:
              'DeepSeek\'s reasoning-focused distilled model. Excellent at step-by-step thinking and math on a tiny footprint.',
          parameterCount: '1.5B',
          quantization: 'Q4_K_M',
          minRamGB: 2.0,
          capabilityTag: 'Reasoning',
          downloadUrl:
              'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
          filename: 'DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'qwen2.5-1.5b-instruct',
          name: 'Qwen 2.5 1.5B',
          sizeBytes: 1117000000,
          description:
              'Alibaba\'s mid-range chat model. Great balance of speed and quality for multilingual conversations.',
          parameterCount: '1.5B',
          quantization: 'Q4_K_M',
          minRamGB: 2.0,
          capabilityTag: 'Chat',
          downloadUrl:
              'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
          filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        ),
        ModelInfo(
          id: 'granite-3.1-2b-instruct',
          name: 'Granite 3.1 2B',
          sizeBytes: 1545000000,
          description:
              'IBM\'s open enterprise model. Strong at summarization, Q&A, and structured tasks. Trained on curated data.',
          parameterCount: '2B',
          quantization: 'Q4_K_M',
          minRamGB: 2.5,
          capabilityTag: 'Instruct',
          downloadUrl:
              'https://huggingface.co/bartowski/granite-3.1-2b-instruct-GGUF/resolve/main/granite-3.1-2b-instruct-Q4_K_M.gguf',
          filename: 'granite-3.1-2b-instruct-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'gemma-2-2b-it',
          name: 'Gemma 2 2B',
          sizeBytes: 1709000000,
          description:
              'Google\'s lightweight instruction-tuned model. State-of-the-art quality at 2B scale with strong reasoning.',
          parameterCount: '2B',
          quantization: 'Q4_K_M',
          minRamGB: 2.5,
          capabilityTag: 'Instruct',
          downloadUrl:
              'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
          filename: 'gemma-2-2b-it-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'qwen2.5-3b-instruct',
          name: 'Qwen 2.5 3B',
          sizeBytes: 2105000000,
          description:
              'Alibaba\'s powerful 3B model. Excellent multilingual support with strong coding and reasoning abilities.',
          parameterCount: '3B',
          quantization: 'Q4_K_M',
          minRamGB: 4.0,
          capabilityTag: 'Reasoning',
          downloadUrl:
              'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
          filename: 'qwen2.5-3b-instruct-q4_k_m.gguf',
        ),
        ModelInfo(
          id: 'llama-3.2-3b-instruct',
          name: 'Llama 3.2 3B',
          sizeBytes: 2020000000,
          description:
              'Meta\'s balanced instruction model. Strong reasoning, coding, and writing. Recommended for most modern phones.',
          parameterCount: '3B',
          quantization: 'Q4_K_M',
          minRamGB: 4.0,
          capabilityTag: 'Instruct',
          downloadUrl:
              'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          filename: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'gemma-3-1b-it',
          name: 'Gemma 3 1B',
          sizeBytes: 806000000,
          description:
              'Google\'s latest lightweight model. Excellent multilingual support with strong instruction following.',
          parameterCount: '1B',
          quantization: 'Q4_K_M',
          minRamGB: 1.5,
          capabilityTag: 'Chat',
          downloadUrl:
              'https://huggingface.co/MaziyarPanahi/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it.Q4_K_M.gguf',
          filename: 'gemma-3-1b-it.Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'mobilevlm-v2-1.7b',
          name: 'MobileVLM V2 1.7B Vision',
          sizeBytes: 792000000,
          description:
              'BETA: On-device vision is experimental — results vary by image. Describe photos and read text in images. Fast and lightweight. 1.4 GB total with projector.',
          parameterCount: '1.7B',
          quantization: 'Q4_K',
          minRamGB: 2.0,
          capabilityTag: 'Vision',
          downloadUrl:
              'https://huggingface.co/ZiangWu/MobileVLM_V2-1.7B-GGUF/resolve/main/ggml-model-q4_k.gguf',
          filename: 'mobilevlm-v2-1.7b-q4_k.gguf',
          isVision: true,
          mmprojUrl:
              'https://huggingface.co/ZiangWu/MobileVLM_V2-1.7B-GGUF/resolve/main/mmproj-model-f16.gguf',
          mmprojFilename: 'mobilevlm-v2-1.7b-mmproj-f16.gguf',
        ),
        ModelInfo(
          id: 'mobilevlm-3b',
          name: 'MobileVLM 3B Vision',
          sizeBytes: 1640000000,
          description:
              'BETA: On-device vision is experimental — results vary by image. Best image understanding for its size. 2.3 GB total with projector.',
          parameterCount: '3B',
          quantization: 'Q4_K_M',
          minRamGB: 3.0,
          capabilityTag: 'Vision',
          downloadUrl:
              'https://huggingface.co/Blombert/MobileVLM-3B-GGUF/resolve/main/mobilevlm-3b.Q4_K_M.gguf',
          filename: 'mobilevlm-3b-Q4_K_M.gguf',
          isVision: true,
          mmprojUrl:
              'https://huggingface.co/Blombert/MobileVLM-3B-GGUF/resolve/main/mmproj-model-f16.gguf',
          mmprojFilename: 'mobilevlm-3b-mmproj-f16.gguf',
        ),
        ModelInfo(
          id: 'gemma-3-4b-it-vision',
          name: 'Gemma 3 4B',
          sizeBytes: 2490000000,
          description:
              'Google\'s powerful 4B parameter model. Excellent at conversation, reasoning, and instruction following. Top quality for its size.',
          parameterCount: '4B',
          quantization: 'Q4_K_M',
          minRamGB: 4.0,
          capabilityTag: 'Chat',
          downloadUrl:
              'https://huggingface.co/lmstudio-community/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
          filename: 'gemma-3-4b-it-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'phi-3.5-mini-instruct',
          name: 'Phi-3.5 Mini 3.8B',
          sizeBytes: 2180000000,
          description:
              'Microsoft\'s advanced reasoning model. Excellent at math, logic, and code. Best quality under 4B params.',
          parameterCount: '3.8B',
          quantization: 'Q4_K_M',
          minRamGB: 4.0,
          capabilityTag: 'Reasoning',
          downloadUrl:
              'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
          filename: 'Phi-3.5-mini-instruct-Q4_K_M.gguf',
        ),
        ModelInfo(
          id: 'minicpm-v4',
          name: 'MiniCPM-V 4 4.1B',
          sizeBytes: 2190000000,
          description:
              'OpenBMB\'s powerful 4.1B parameter model. Strong conversational abilities with excellent reasoning. Use MobileVLM for image understanding.',
          parameterCount: '4.1B',
          quantization: 'Q4_K_M',
          minRamGB: 4.0,
          capabilityTag: 'Chat',
          downloadUrl:
              'https://huggingface.co/openbmb/MiniCPM-V-4-gguf/resolve/main/ggml-model-Q4_K_M.gguf',
          filename: 'minicpm-v4-q4_k_m.gguf',
        ),
      ];

  /// Loads model catalog from SharedPreferences. Falls back to defaultCatalog.
  /// Verifies that downloaded models actually exist on disk.
  Future<void> loadModels() async {
    _prefs ??= await SharedPreferences.getInstance();

    final dir = await getApplicationDocumentsDirectory();
    _modelsDir = '${dir.path}/models';
    final modelsDirectory = Directory(_modelsDir!);
    if (!await modelsDirectory.exists()) {
      await modelsDirectory.create(recursive: true);
    }

    final jsonString = _prefs!.getString('model_catalog');
    if (jsonString == null) {
      _models = defaultCatalog;
    } else {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
        _models = jsonList
            .map((e) => ModelInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        // Merge with defaultCatalog: add new models + refresh downloadUrl/filename on existing
        final defaultMap = { for (final m in defaultCatalog) m.id: m };
        final existingIds = _models.map((m) => m.id).toSet();
        for (int i = 0; i < _models.length; i++) {
          final def = defaultMap[_models[i].id];
          if (def != null && (_models[i].downloadUrl.isEmpty || _models[i].filename.isEmpty || _models[i].mmprojUrl != def.mmprojUrl)) {
            _models[i] = _models[i].copyWith(
              downloadUrl: def.downloadUrl.isNotEmpty ? def.downloadUrl : null,
              filename: def.filename.isNotEmpty ? def.filename : null,
              isVision: def.isVision,
              mmprojUrl: def.mmprojUrl.isNotEmpty ? def.mmprojUrl : null,
              mmprojFilename: def.mmprojFilename.isNotEmpty ? def.mmprojFilename : null,
            );
          }
        }
        for (final defaultModel in defaultCatalog) {
          if (!existingIds.contains(defaultModel.id)) {
            _models.add(defaultModel);
          }
        }
      } catch (_) {
        _models = defaultCatalog;
      }
    }

    // Verify downloaded models still exist on disk
    for (int i = 0; i < _models.length; i++) {
      if (_models[i].isDownloaded && _models[i].filename.isNotEmpty) {
        final filePath = '$_modelsDir/${_models[i].filename}';
        if (!await File(filePath).exists()) {
          _models[i] = _models[i].copyWith(
            isDownloaded: false,
            downloadProgress: 0.0,
            clearDownloadedAt: true,
            isActive: false,
          );
        }
      }
    }

    // Auto-download missing mmproj files for downloaded vision models (non-blocking)
    _downloadMissingMmproj();

    _saveModels();
    notifyListeners();
  }

  /// Background-downloads missing mmproj files for vision models already on disk.
  /// Called fire-and-forget from loadModels() so it doesn't block app startup.
  void _downloadMissingMmproj() async {
    if (_modelsDir == null) return;
    for (int i = 0; i < _models.length; i++) {
      final m = _models[i];
      if (m.isDownloaded && m.isVision && m.mmprojUrl.isNotEmpty && m.mmprojFilename.isNotEmpty) {
        final mmprojPath = '$_modelsDir/${m.mmprojFilename}';
        if (!await File(mmprojPath).exists()) {
          debugPrint('[ModelProvider] Background downloading mmproj for ${m.id}');
          try {
            final tmpPath = '$mmprojPath.tmp';
            final client = HttpClient();
            final req = await client.getUrl(Uri.parse(m.mmprojUrl));
            final resp = await req.close();
            if (resp.statusCode == 200) {
              final sink = File(tmpPath).openWrite();
              await for (final chunk in resp) {
                sink.add(chunk);
              }
              await sink.flush();
              await sink.close();
              final finalFile = File(mmprojPath);
              if (await finalFile.exists()) await finalFile.delete();
              await File(tmpPath).rename(mmprojPath);
              debugPrint('[ModelProvider] mmproj downloaded for ${m.id}');
            }
            client.close();
          } catch (e) {
            debugPrint('[ModelProvider] mmproj background download failed: $e');
          }
        }
      }
    }
  }

  /// Downloads a GGUF model file from HuggingFace with progress tracking.
  Future<void> startDownload(String modelId) async {
    final index = _models.indexWhere((m) => m.id == modelId);
    if (index == -1) return;

    final model = _models[index];
    if (model.downloadUrl.isEmpty ||
        model.filename.isEmpty ||
        _modelsDir == null) return;

    _cancelledDownloads.remove(modelId);
    _models[index] = model.copyWith(downloadProgress: 0.01);
    notifyListeners();

    // Keep device awake during download to prevent Android from killing the connection
    try { await WakelockPlus.enable(); } catch (_) {}

    try {
      final filePath = '$_modelsDir/${model.filename}';
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);

      // Resume support: check if a partial .tmp file exists
      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
        debugPrint('[ModelProvider] Resuming $modelId from $existingBytes bytes');
      }

      final client = HttpClient();
      _activeClients[modelId] = client;

      final request = await client.getUrl(Uri.parse(model.downloadUrl));
      if (existingBytes > 0) {
        request.headers.set('Range', 'bytes=$existingBytes-');
      }
      final response = await request.close();

      // 200 = full file, 206 = partial (resume accepted)
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      // If server doesn't support range (returned 200 instead of 206), start fresh
      if (existingBytes > 0 && response.statusCode == 200) {
        existingBytes = 0;
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength + existingBytes
          : model.sizeBytes;
      int receivedBytes = existingBytes;
      int lastUpdateMs = 0;

      final sink = tempFile.openWrite(mode: existingBytes > 0 && response.statusCode == 206
          ? FileMode.append : FileMode.write);

      await for (final chunk in response) {
        if (_cancelledDownloads.contains(modelId)) break;

        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (totalBytes > 0 && now - lastUpdateMs > 250) {
          lastUpdateMs = now;
          final progress = (receivedBytes / totalBytes).clamp(0.01, 0.99);
          final idx = _models.indexWhere((m) => m.id == modelId);
          if (idx != -1) {
            _models[idx] = _models[idx].copyWith(downloadProgress: progress);
            notifyListeners();
          }
        }
      }

      await sink.flush();
      await sink.close();
      _activeClients.remove(modelId);

      if (_cancelledDownloads.contains(modelId)) {
        _cancelledDownloads.remove(modelId);
        // Keep .tmp file for resume — don't delete it
        final idx = _models.indexWhere((m) => m.id == modelId);
        if (idx != -1) {
          _models[idx] = _models[idx].copyWith(downloadProgress: 0.0);
          _saveModels();
          notifyListeners();
        }
        try { await WakelockPlus.disable(); } catch (_) {}
        return;
      }

      // Verify downloaded file is valid (not an error page)
      final tempSize = await tempFile.length();
      if (tempSize < 1000000) {
        // < 1MB is too small for any GGUF model — likely an error page
        await tempFile.delete();
        _lastError = 'Download incomplete. Please try again.';
        final idx = _models.indexWhere((m) => m.id == modelId);
        if (idx != -1) {
          _models[idx] = _models[idx].copyWith(downloadProgress: 0.0);
          _saveModels();
        }
        try { await WakelockPlus.disable(); } catch (_) {}
        notifyListeners();
        return;
      }

      // Rename temp file to final location
      final finalFile = File(filePath);
      if (await finalFile.exists()) await finalFile.delete();
      await tempFile.rename(filePath);

      // Download mmproj file for vision models
      if (model.isVision && model.mmprojUrl.isNotEmpty && model.mmprojFilename.isNotEmpty) {
        try {
          final mmprojPath = '$_modelsDir/${model.mmprojFilename}';
          final mmprojTmp = '$mmprojPath.tmp';
          final mmprojClient = HttpClient();
          final mmprojReq = await mmprojClient.getUrl(Uri.parse(model.mmprojUrl));
          final mmprojResp = await mmprojReq.close();
          if (mmprojResp.statusCode == 200) {
            final mmprojSink = File(mmprojTmp).openWrite();
            await for (final chunk in mmprojResp) {
              mmprojSink.add(chunk);
            }
            await mmprojSink.flush();
            await mmprojSink.close();
            final mmprojFinal = File(mmprojPath);
            if (await mmprojFinal.exists()) await mmprojFinal.delete();
            await File(mmprojTmp).rename(mmprojPath);
            debugPrint('[ModelProvider] Downloaded mmproj for $modelId');
          }
          mmprojClient.close();
        } catch (e) {
          debugPrint('[ModelProvider] mmproj download error: $e');
        }
      }

      final idx = _models.indexWhere((m) => m.id == modelId);
      if (idx != -1) {
        _models[idx] = _models[idx].copyWith(
          downloadProgress: 1.0,
          isDownloaded: true,
          downloadedAt: DateTime.now(),
        );
        _saveModels();
        notifyListeners();
      }
      try { await WakelockPlus.disable(); } catch (_) {}
    } catch (e) {
      _activeClients.remove(modelId);
      final idx = _models.indexWhere((m) => m.id == modelId);
      if (idx != -1) {
        _models[idx] = _models[idx].copyWith(downloadProgress: 0.0);
        _saveModels();
      }
      _lastError = _friendlyError(e);
      debugPrint('[ModelProvider] Download error for $modelId: $e');
      // Clean up temp file on error
      try {
        final tempFile = File('$_modelsDir/${model.filename}.tmp');
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      try { await WakelockPlus.disable(); } catch (_) {}
      notifyListeners();
    }
  }

  /// Cancels an in-progress download and cleans up.
  void cancelDownload(String modelId) {
    _cancelledDownloads.add(modelId);
    try {
      _activeClients[modelId]?.close(force: true);
    } catch (_) {}
    _activeClients.remove(modelId);

    final index = _models.indexWhere((m) => m.id == modelId);
    if (index != -1) {
      _models[index] = _models[index].copyWith(downloadProgress: 0.0);
      _saveModels();
      notifyListeners();
    }
  }

  /// Deletes a model from disk and resets its state.
  Future<void> deleteModel(String modelId) async {
    cancelDownload(modelId);

    final index = _models.indexWhere((m) => m.id == modelId);
    if (index == -1) return;

    final model = _models[index];
    _models[index] = model.copyWith(
      isDownloaded: false,
      isActive: false,
      clearDownloadedAt: true,
      downloadProgress: 0.0,
    );
    _saveModels();
    notifyListeners();

    if (_modelsDir != null && model.filename.isNotEmpty) {
      try {
        final file = File('$_modelsDir/${model.filename}');
        if (await file.exists()) await file.delete();
        final tempFile = File('$_modelsDir/${model.filename}.tmp');
        if (await tempFile.exists()) await tempFile.delete();
        if (model.mmprojFilename.isNotEmpty) {
          final mmFile = File('$_modelsDir/${model.mmprojFilename}');
          if (await mmFile.exists()) await mmFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Sets the given model as the active model, deactivating all others.
  void setActiveModel(String modelId) {
    for (int i = 0; i < _models.length; i++) {
      _models[i] = _models[i].copyWith(isActive: _models[i].id == modelId);
    }
    _saveModels();
    notifyListeners();
  }

  /// Converts raw exceptions into user-friendly error messages.
  static String _friendlyError(dynamic e) {
    final raw = e.toString();
    if (e is SocketException || raw.contains('SocketException')) {
      return 'Connection lost. Please check your internet and try again.';
    }
    if (e is HttpException || raw.contains('HttpException')) {
      if (raw.contains('302') || raw.contains('307') || raw.contains('redirect')) {
        return 'Download redirect failed. Please try again.';
      }
      return 'Server error. Please try again later.';
    }
    if (raw.contains('FileSystemException') || raw.contains('No space')) {
      return 'Not enough storage space. Free up space and try again.';
    }
    if (raw.contains('Connection closed') || raw.contains('Connection reset')) {
      return 'Connection dropped during download. Please try again.';
    }
    return 'Download failed. Please check your connection and try again.';
  }

  /// Persists the current model list to SharedPreferences as a JSON string.
  Future<void> _saveModels() async {
    _prefs ??= await SharedPreferences.getInstance();
    final jsonList = _models.map((m) => m.toJson()).toList();
    await _prefs!.setString('model_catalog', jsonEncode(jsonList));
  }

  @override
  void dispose() {
    for (final client in _activeClients.values) {
      try {
        client.close(force: true);
      } catch (_) {}
    }
    _activeClients.clear();
    super.dispose();
  }
}
