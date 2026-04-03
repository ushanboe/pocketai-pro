# Gemma 4 LiteRT-LM Integration Guide

Step-by-step guide for adding Gemma 4 on-device inference to a Flutter app that currently uses fllama (llama.cpp) for GGUF models.

## Overview

Gemma 4 uses Google's **LiteRT-LM** runtime with `.litertlm` model files — a completely different stack from llama.cpp/GGUF. This guide adds it as a second inference backend alongside your existing fllama setup. All existing models keep working unchanged.

## Architecture

```
┌─────────────────────────────────────────────┐
│              InferenceEngine                 │
│         (routes to correct backend)          │
├──────────────────┬──────────────────────────┤
│   FllamaBackend  │    LiteRtLmBackend       │
│   (GGUF models)  │    (.litertlm models)    │
│   Pure Dart      │    Platform Channel       │
│                  │    ↕                      │
│                  │    LiteRtLmPlugin.kt      │
│                  │    (Android native)       │
└──────────────────┴──────────────────────────┘
```

## Files Changed / Added

### Modified (4 files)
| File | What changed |
|------|-------------|
| `lib/core/models/model_info.dart` | Added `InferenceBackendType` enum + `backendType` field |
| `lib/core/providers/model_provider.dart` | Added Gemma 4 E2B + E4B to catalog, updated merge logic |
| `lib/features/chat/screens/chat_screen.dart` | Passes `backendType` to InferenceEngine |
| `android/app/build.gradle.kts` | Added LiteRT-LM dependency, minSdk=31 |

### New (5 files)
| File | Purpose |
|------|---------|
| `lib/core/services/inference_backend.dart` | Abstract interface all backends implement |
| `lib/core/services/fllama_backend.dart` | Existing fllama logic extracted into backend interface |
| `lib/core/services/litertlm_backend.dart` | Dart side — calls Kotlin via MethodChannel/EventChannel |
| `lib/core/services/inference_engine.dart` | Rewritten as router that delegates to correct backend |
| `android/.../LiteRtLmPlugin.kt` | Kotlin bridge to LiteRT-LM SDK |

### Unchanged
- `MainActivity.kt` — just added one line to register the plugin

---

## Step-by-Step Integration (for your other apps)

### Step 1: Add the backend type to your model data class

In your model info/data class, add:

```dart
enum InferenceBackendType {
  fllama,    // llama.cpp / GGUF
  litertlm,  // Google LiteRT-LM / Gemma 4
}

// In your model class:
final InferenceBackendType backendType;
// Default to fllama so existing models aren't affected:
this.backendType = InferenceBackendType.fllama,
```

Update `copyWith()`, `toJson()`, and `fromJson()` to include the field. Use `backendType.name` for JSON serialization.

### Step 2: Create the abstract backend interface

```dart
// lib/core/services/inference_backend.dart
abstract class InferenceBackend {
  Stream<String> generateResponse(
    String userMessage,
    List<Message> history,
    AppSettings settings,
    String modelPath, {
    String? mmprojPath,
    Uint8List? imageBytes,
  });
  void cancel();
}
```

### Step 3: Extract existing fllama code into FllamaBackend

Move your current `InferenceEngine` logic into a class that `implements InferenceBackend`. No behavior changes — just wrapping it in the interface.

### Step 4: Create LiteRtLmBackend (Dart side)

This uses `MethodChannel` for init/cancel/dispose and `EventChannel` for streaming tokens.

Key channel names (update for your app's package):
```dart
static const _method = MethodChannel('com.yourpackage/litertlm');
static const _events = EventChannel('com.yourpackage/litertlm_stream');
```

The backend handles:
- Lazy engine initialization (only init when model changes)
- Conversation management
- Streaming tokens back as incremental chunks
- `__DONE__` sentinel to signal completion

### Step 5: Rewrite InferenceEngine as a router

```dart
class InferenceEngine {
  final _backends = <InferenceBackendType, InferenceBackend>{};

  InferenceBackend _backendFor(InferenceBackendType type) {
    return _backends.putIfAbsent(type, () {
      switch (type) {
        case InferenceBackendType.fllama: return FllamaBackend();
        case InferenceBackendType.litertlm: return LiteRtLmBackend();
      }
    });
  }

  Stream<String> generateResponse(..., {InferenceBackendType backendType = InferenceBackendType.fllama}) {
    cancel();
    return _backendFor(backendType).generateResponse(...);
  }
}
```

### Step 6: Create LiteRtLmPlugin.kt (Android native)

Copy `LiteRtLmPlugin.kt` into your `android/app/src/main/kotlin/<package>/` directory. Update:
1. Package name at the top
2. Channel name constants (`METHOD_CHANNEL`, `EVENT_CHANNEL`)

The plugin handles:
- Engine lifecycle (init, dispose)
- GPU/CPU backend selection
- Streaming via Kotlin coroutines + `sendMessageAsync().collect()`
- Image bytes for multimodal queries

### Step 7: Register plugin in MainActivity

```kotlin
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LiteRtLmPlugin.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
```

### Step 8: Update build.gradle.kts

```kotlin
android {
    defaultConfig {
        minSdk = maxOf(flutter.minSdkVersion, 31) // Android 12+ required
    }
}

dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-android:latest.release")
}
```

### Step 9: Add Gemma 4 models to your catalog

```dart
ModelInfo(
  id: 'gemma-4-e2b-it',
  name: 'Gemma 4 E2B',
  sizeBytes: 2600000000,      // ~2.6 GB
  minRamGB: 8.0,
  downloadUrl: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  filename: 'gemma-4-E2B-it.litertlm',
  backendType: InferenceBackendType.litertlm,
),
ModelInfo(
  id: 'gemma-4-e4b-it',
  name: 'Gemma 4 E4B',
  sizeBytes: 3700000000,      // ~3.7 GB
  minRamGB: 12.0,
  downloadUrl: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
  filename: 'gemma-4-E4B-it.litertlm',
  backendType: InferenceBackendType.litertlm,
),
```

### Step 10: Pass backendType in your chat screen

Where you call `generateResponse()`, look up the active model's `backendType` and pass it:

```dart
final activeModel = modelProvider.activeModel;
final backendType = activeModel?.backendType ?? InferenceBackendType.fllama;

_inferenceEngine.generateResponse(
  text, messages, settings, modelPath,
  backendType: backendType,
);
```

---

## Available Gemma 4 Models

| Model | File Size | Min RAM | Context | Capabilities |
|-------|-----------|---------|---------|-------------|
| Gemma 4 E2B | ~2.6 GB | 8 GB | 32K | Text, Vision, Audio, Thinking, Tool Calling |
| Gemma 4 E4B | ~3.7 GB | 12 GB | 32K | Text, Vision, Audio, Thinking, Tool Calling |

## Platform Support

| Platform | Status |
|----------|--------|
| Android 12+ | Fully supported |
| iOS 17+ | Not yet (Swift API in development, Gemma 4 not in iOS allowlist) |
| Desktop (Linux/macOS/Windows) | Via Python/C++ API (not via this Flutter integration) |

## Troubleshooting

- **"Engine not initialized"**: The LiteRT-LM engine takes 10-15 seconds to load. Ensure you show a loading indicator.
- **Crash on older devices**: Requires Android 12+ (API 31). The minSdk bump handles this at install time.
- **Out of memory**: E2B needs 8GB RAM, E4B needs 12GB. Check device RAM before allowing download.
- **No response / empty output**: Try `Backend.CPU()` instead of `Backend.GPU()` — some GPUs aren't supported yet.

## Adding More Backends Later

The architecture supports adding more backends easily:

1. Add a value to `InferenceBackendType` enum
2. Create a class implementing `InferenceBackend`
3. Add a case to `InferenceEngine._backendFor()`
4. Add models to the catalog with the new `backendType`

Examples of other backends you could add:
- **ONNX Runtime** for ONNX models
- **Core ML** for Apple's on-device models (iOS)
- **TensorFlow Lite** for TFLite models
