# Gemma 4 LiteRT-LM Integration Guide

**Status: WORKING** — Tested and confirmed on-device 2026-04-04. Gemma 4 E2B runs fast on Android with GPU acceleration.

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

### Modified (6 files)
| File | What changed |
|------|-------------|
| `lib/core/models/model_info.dart` | Added `InferenceBackendType` enum + `backendType` field |
| `lib/core/providers/model_provider.dart` | Added Gemma 4 E2B + E4B to catalog, updated merge logic |
| `lib/features/chat/screens/chat_screen.dart` | Passes `backendType` to InferenceEngine |
| `android/app/build.gradle.kts` | Added LiteRT-LM dependency, minSdk=31 |
| `android/app/src/main/AndroidManifest.xml` | Added GPU native library declarations (`libOpenCL.so`, `libvndksupport.so`) inside `<application>` |
| `android/app/proguard-rules.pro` | Added `-keep` rules for all LiteRT-LM classes (prevents R8 stripping) |

### New (5 files)
| File | Purpose |
|------|---------|
| `lib/core/services/inference_backend.dart` | Abstract interface all backends implement |
| `lib/core/services/fllama_backend.dart` | Existing fllama logic extracted into backend interface |
| `lib/core/services/litertlm_backend.dart` | Dart side — calls Kotlin via MethodChannel/EventChannel, with init error handling |
| `lib/core/services/inference_engine.dart` | Rewritten as router that delegates to correct backend |
| `android/.../LiteRtLmPlugin.kt` | Kotlin bridge to LiteRT-LM SDK — callback-based streaming, GPU→CPU fallback, logging |

### Also modified
- `MainActivity.kt` — added one line to register LiteRtLmPlugin

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
- Engine lifecycle (init with `cacheDir`, dispose with proper cleanup)
- **GPU→CPU automatic fallback** (tries GPU first, retries with CPU if GPU fails)
- **Callback-based streaming** via `MessageCallback` (NOT Flow — see Issue #8)
- System instruction via `ConversationConfig.systemInstruction`
- Image bytes for multimodal queries
- Detailed Android logging (`adb logcat | grep LiteRtLm`)
- Cancellation via `conversation.cancelProcess()`

**CRITICAL: GPU fallback pattern.** The `initialize` method MUST try GPU first, then fall back to CPU:
```kotlin
try {
    engine = Engine(EngineConfig(
        modelPath = path, backend = Backend.GPU(),
        visionBackend = Backend.GPU(), audioBackend = Backend.CPU(),
        cacheDir = context.cacheDir.path,
    ))
    engine!!.initialize()  // BLOCKING call — run on background thread
} catch (gpuErr: Exception) {
    Log.w("LiteRtLm", "GPU failed, falling back to CPU: ${gpuErr.message}")
    engine = Engine(EngineConfig(
        modelPath = path, backend = Backend.CPU(),
        visionBackend = Backend.CPU(), audioBackend = Backend.CPU(),
        cacheDir = context.cacheDir.path,
    ))
    engine!!.initialize()
}
```

**CRITICAL: Use callback-based streaming, NOT Flow.** The `sendMessageAsync` API streams `Message` objects (not Strings). Using the callback pattern avoids casting issues:
```kotlin
conv.sendMessageAsync(
    contents,
    object : MessageCallback {
        override fun onMessage(message: Message) {
            val text = message.toString()  // Extract text from Message object
            val thinking = message.channels?.get("thought")  // Optional thinking content
            handler.post { events.success(text) }
        }
        override fun onDone() {
            handler.post { events.success("__DONE__"); events.endOfStream() }
        }
        override fun onError(throwable: Throwable) {
            handler.post { events.error("INFERENCE_ERROR", throwable.message, null) }
        }
    },
)
```

### Step 7: Register plugin in MainActivity

```kotlin
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LiteRtLmPlugin.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
```

### Step 8: Update build.gradle.kts and AndroidManifest.xml

**build.gradle.kts:**
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

**AndroidManifest.xml** — Add GPU library declarations INSIDE `<application>` (not under `<manifest>`):
```xml
<application ...>
    <!-- GPU acceleration for LiteRT-LM. required="false" means CPU fallback works. -->
    <uses-native-library android:name="libOpenCL.so" android:required="false"/>
    <uses-native-library android:name="libvndksupport.so" android:required="false"/>
    ...
</application>
```

These are REQUIRED for GPU inference. Without them, the engine init will fail with `INIT_FAILED` on most devices.

**proguard-rules.pro** — Add keep rules to prevent R8 from stripping LiteRT-LM classes:
```proguard
# LiteRT-LM (Gemma 4) — keep all SDK classes, JNI, and callbacks
# Without these rules, R8 strips classes that are only called from native/JNI code,
# causing ClassNotFoundException crashes at runtime during inference.
-keep class com.google.ai.edge.litertlm.** { *; }
-keepclassmembers class com.google.ai.edge.litertlm.** { *; }
-dontwarn com.google.ai.edge.litertlm.**
```

This is REQUIRED. Without it, the app compiles fine but crashes at runtime because R8 strips SDK classes that are only referenced via JNI from the native `.so` library.

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

## Build Issues & Fixes (CRITICAL — read before building)

These are real issues hit during the first successful build (2026-04-04). AppForge agents MUST apply these fixes or the build will fail.

### Issue 1: Flutter SDK version too old

**Error:**
```
Because pocketai depends on fllama from git which requires SDK version >=3.10.0 <4.0.0, version solving failed.
```

**Cause:** fllama's latest `main` branch requires Dart 3.10+ / Flutter 3.41+. Older Flutter (e.g. 3.29) will fail at dependency resolution.

**Fix:** Run `flutter upgrade` before building. Minimum required: **Flutter 3.41.6 / Dart 3.11.4**.

---

### Issue 2: fllama linker error — `cpp-httplib` not found

**Error:**
```
ld.lld: error: unable to find library -lcpp-httplib
clang++: error: linker command failed with exit code 1
```

**Cause:** The latest llama.cpp `common/CMakeLists.txt` (bundled inside fllama) unconditionally links `cpp-httplib` at line 114. This library doesn't exist on Android. fllama's own `src/CMakeLists.txt` sets `LLAMA_HTTPLIB=OFF` but the `common` subdirectory ignores that flag.

**Fix:** Patch the file at:
```
~/.pub-cache/git/fllama-<hash>/src/llama.cpp/common/CMakeLists.txt
```

Replace:
```cmake
target_link_libraries(${TARGET} PRIVATE
    build_info
    cpp-httplib
)
```

With:
```cmake
target_link_libraries(${TARGET} PRIVATE
    build_info
)

if (NOT LLAMA_HTTPLIB STREQUAL "OFF" AND NOT LLAMA_HTTPLIB STREQUAL "off")
    target_link_libraries(${TARGET} PRIVATE cpp-httplib)
endif()
```

Then clean the build cache:
```bash
rm -rf ~/.pub-cache/git/fllama-<hash>/android/.cxx
rm -rf <project>/build/fllama
```

**Note:** This patch is in the pub cache, so `flutter pub get` or `flutter clean` may reset it. If the build fails again with this error, re-apply the patch. A permanent fix would be to fork fllama or pin to a commit that fixes this upstream.

---

### Issue 3: Kotlin type mismatch in LiteRtLmPlugin — Float vs Double

**Error:**
```
e: LiteRtLmPlugin.kt:128:36 Argument type mismatch: actual type is 'Float', but 'Double' was expected.
e: LiteRtLmPlugin.kt:129:43 Argument type mismatch: actual type is 'Float', but 'Double' was expected.
```

**Cause:** LiteRT-LM's `SamplerConfig` expects `Double` for `topP` and `temperature`, not `Float`. Using `.toFloat()` causes a compile error.

**Fix:** In `LiteRtLmPlugin.kt`, use the values directly without `.toFloat()`:
```kotlin
// WRONG:
topP = topP.toFloat(),
temperature = temperature.toFloat()

// CORRECT:
topP = topP,
temperature = temperature
```

**Already fixed** in the current codebase (commit 8c252aa).

---

### Issue 4: Kotlin metadata version warning (non-fatal)

**Warning:**
```
Info: Class com.google.ai.edge.litertlm.LiteRtLmJni has malformed kotlin.Metadata:
java.lang.IllegalArgumentException: Provided Metadata instance has version 2.3.0,
while maximum supported version is 2.2.0.
```

**Cause:** The `litertlm-android` library was compiled with a newer Kotlin version (2.3.0) than the project's Kotlin compiler supports (2.2.0). This is a metadata compatibility warning, not an error.

**Impact:** No runtime impact — the APK works fine. To suppress, upgrade the project's Kotlin version in `android/settings.gradle.kts` or `build.gradle.kts` when a compatible version is available.

---

### Issue 5: `uses-native-library` in wrong XML location

**Error:**
```
AAPT: error: unexpected element <uses-native-library> found in <manifest>.
```

**Cause:** `<uses-native-library>` tags must go INSIDE `<application>`, not directly under `<manifest>`. This is an Android XML structure rule — it's different from `<uses-permission>` which goes under `<manifest>`.

**Fix:** Place GPU library declarations inside `<application>`:
```xml
<!-- WRONG — under <manifest> -->
<manifest>
    <uses-native-library android:name="libOpenCL.so" android:required="false"/>
    <application ...>

<!-- CORRECT — inside <application> -->
<manifest>
    <application ...>
        <uses-native-library android:name="libOpenCL.so" android:required="false"/>
        <uses-native-library android:name="libvndksupport.so" android:required="false"/>
```

**Already fixed** in the current codebase (commit 6dc7b86).

---

### Issue 6: Runtime — `PlatformException(INIT_FAILED, Engine is not initialized)`

**Error (on device):**
```
Generation error: PlatformException(INIT_FAILED, Engine is not initialized., null, null)
```

**Cause:** The LiteRT-LM engine fails to initialize, usually because:
1. GPU backend is unavailable on the device (most common)
2. Model file is corrupted or incomplete
3. Device doesn't have enough RAM (8 GB min for E2B, 12 GB for E4B)

**Fix (applied in codebase):** Three changes were needed:

**a) AndroidManifest.xml — declare GPU native libraries:**
```xml
<application ...>
    <uses-native-library android:name="libOpenCL.so" android:required="false"/>
    <uses-native-library android:name="libvndksupport.so" android:required="false"/>
```
Without these, the device's GPU compute libraries are not accessible to the app, causing GPU init to fail silently.

**b) LiteRtLmPlugin.kt — GPU→CPU automatic fallback:**
```kotlin
// Try GPU first
try {
    engine = Engine(EngineConfig(modelPath = modelPath, backend = Backend.GPU(), ...))
    engine!!.initialize()
} catch (gpuErr: Exception) {
    // GPU failed — fall back to CPU
    engine = Engine(EngineConfig(modelPath = modelPath, backend = Backend.CPU(), ...))
    engine!!.initialize()
}
```
Without this fallback, GPU failure = total failure. CPU is slower but works on all devices.

**c) litertlm_backend.dart — surface init errors to user:**
```dart
try {
    await _method.invokeMethod('initialize', {...});
} catch (e) {
    _streamController?.addError('Gemma 4 engine failed to start: $e');
    return; // Don't attempt inference with no engine
}
```
Without this, init failure is silent and the user sees a confusing "no response generated" message.

**Debugging:** Use `adb logcat | grep LiteRtLm` to see detailed init logs from the Kotlin plugin.

---

### Issue 7: First build takes ~12 minutes

**Cause:** fllama compiles llama.cpp from C++ source via CMake for 3 Android ABIs (`arm64-v8a`, `x86_64`, `x86`). This is ~200 compilation units per ABI.

**Impact:** First build: ~12 min. Subsequent builds (Dart/Kotlin only): ~1-2 min.

**Tip:** Don't kill the build if it appears stuck at `Running Gradle task 'assembleRelease'...` — it's compiling C++ in the background. The output doesn't stream until completion.

---

### Issue 8: App crashes (force close) during inference — wrong streaming API

**Symptom:** App opens, model downloads, engine initializes, user sends a message, AI "thinks" briefly, then the app force closes. No error shown — just a crash.

**Cause:** `sendMessageAsync()` returns `Flow<Message>`, NOT `Flow<String>`. The original code used:
```kotlin
// WRONG — causes native crash:
conv.sendMessageAsync(contents).collect { token ->
    events.success(token)  // token is a Message object, not a String!
}
```

Passing a `Message` object through Flutter's `EventChannel` (which expects primitives) causes a native serialization crash.

**Fix:** Use the **callback-based** `sendMessageAsync` with `MessageCallback` (this is the pattern Google's own AI Edge Gallery app uses):
```kotlin
// CORRECT — callback pattern with message.toString():
conv.sendMessageAsync(
    contents,
    object : MessageCallback {
        override fun onMessage(message: Message) {
            val text = message.toString()  // Extract String from Message
            val thinking = message.channels?.get("thought")
            handler.post { events.success(text) }  // Send String through EventChannel
        }
        override fun onDone() {
            handler.post { events.success("__DONE__"); events.endOfStream() }
        }
        override fun onError(throwable: Throwable) {
            handler.post { events.error("INFERENCE_ERROR", throwable.message, null) }
        }
    },
)
```

**Key API facts verified from LiteRT-LM source code:**
- `engine.initialize()` is BLOCKING (not suspend) — run on background thread
- `sendMessageAsync` streams `Message` objects — use `message.toString()` for text
- `message.channels?.get("thought")` for thinking/reasoning content
- `conversation.cancelProcess()` to abort (not coroutine job cancellation)
- `Contents.of("text")` for simple text, `Contents.of(listOf(Content.ImageBytes(), Content.Text()))` for multimodal
- System prompt goes in `ConversationConfig.systemInstruction`, not in the message list
- Include `cacheDir = context.cacheDir.path` in `EngineConfig` for model caching

**Already fixed** in the current codebase (commit e021c88).

---

### Issue 9: R8/ProGuard strips LiteRT-LM classes — runtime ClassNotFoundException

**Symptom:** APK builds successfully but crashes at runtime when trying to use Gemma 4. Logcat shows `ClassNotFoundException` or `NoSuchMethodError` for LiteRT-LM classes.

**Cause:** R8 (Android's code shrinker) strips classes that appear unused at compile time. LiteRT-LM's SDK classes are called from native JNI code (`liblitertlm_jni.so`), which R8 can't analyze — so it strips them.

**Fix:** Add keep rules in `android/app/proguard-rules.pro`:
```proguard
-keep class com.google.ai.edge.litertlm.** { *; }
-keepclassmembers class com.google.ai.edge.litertlm.** { *; }
-dontwarn com.google.ai.edge.litertlm.**
```

**Already fixed** in the current codebase (commit 1dbd8ea).

---

### Issue 10: First build takes ~12 minutes

(Same as Issue 7 — renumbered for clarity in the summary table.)

---

### Summary of all issues

| # | Error | Type | Severity | Status |
|---|-------|------|----------|--------|
| 1 | Flutter SDK version solving failed | Build | Fatal — won't compile | Fix: `flutter upgrade` |
| 2 | `cpp-httplib` linker error | Build | Fatal — needs pub cache patch | Fix: patch CMakeLists.txt |
| 3 | Kotlin Float vs Double | Build | Fatal — compile error | Fixed in code |
| 4 | Kotlin metadata version warning | Build | Non-fatal warning | Ignore |
| 5 | `uses-native-library` wrong XML location | Build | Fatal — AAPT error | Fixed in code |
| 6 | `INIT_FAILED, Engine is not initialized` | Runtime | Fatal — no GPU access | Fixed: manifest + fallback |
| 7 | App crashes during inference | Runtime | Fatal — wrong API | Fixed: MessageCallback pattern |
| 8 | R8 strips LiteRT-LM classes | Runtime | Fatal — ClassNotFound | Fixed: ProGuard keep rules |
| 9 | First build takes ~12 minutes | Build | Expected behavior | Normal |

### Build Environment (tested & working)

| Component | Version |
|-----------|---------|
| Flutter | 3.41.6 (stable) |
| Dart | 3.11.4 |
| Android SDK | compileSdk from flutter |
| Android NDK | 28.2.13676358 (auto-installed) |
| minSdk | 31 (Android 12+) |
| Kotlin | 2.2.20 (via Flutter Gradle plugin) |
| CMake | 3.22.1 |
| LiteRT-LM | latest.release (0.10.0 as of 2026-04-04) |
| Build time | ~12 min first build, ~2-3 min incremental |
| APK size | 114.2 MB (includes llama.cpp native libs for 3 ABIs + LiteRT-LM JNI) |

---

## Troubleshooting (Runtime)

- **App force closes / crashes during inference**: Almost certainly Issue #7 (wrong streaming API). `sendMessageAsync` returns `Flow<Message>`, not `Flow<String>`. You MUST use the callback-based pattern with `MessageCallback` and call `message.toString()` to extract text. See Issue #7 above for the exact fix.
- **`ClassNotFoundException` or `NoSuchMethodError` at runtime**: R8 stripped LiteRT-LM classes. Add ProGuard keep rules (Issue #8).
- **`PlatformException(INIT_FAILED, Engine is not initialized)`**: Second most common error. Check in this order:
  1. Are `libOpenCL.so` + `libvndksupport.so` declared in AndroidManifest inside `<application>`?
  2. Does LiteRtLmPlugin have GPU→CPU fallback? (GPU alone fails on many devices)
  3. Is the model file the correct size? (E2B should be ~2.6 GB, not a few MB error page)
  4. Does the device have enough RAM? (8 GB for E2B, 12 GB for E4B)
  5. Run `adb logcat | grep LiteRtLm` for detailed native logs
- **"No response generated after 0s"**: The Dart backend tried to stream before init completed. Ensure `litertlm_backend.dart` catches init errors and returns early instead of attempting inference.
- **"No response generated after 17s"**: Engine initialized but produced no output. Likely a model file issue — delete and re-download the model.
- **Crash on older devices**: Requires Android 12+ (API 31). The minSdk=31 bump handles this at install time.
- **Out of memory / sudden app kill**: E2B needs 8 GB device RAM, E4B needs 12 GB. Android will kill the app if it exceeds available memory. Check RAM before allowing download.
- **Very slow inference**: If CPU fallback kicked in (check logcat for "GPU failed, falling back to CPU"), inference will be 3-5x slower than GPU. This is expected — show users a "Running on CPU (slower)" indicator.
- **Silent failures**: Always surface platform channel errors to the UI. The original code silently showed "no response" for init failures — this was fixed by wrapping the `invokeMethod('initialize')` call in try/catch and forwarding the error to the stream controller.

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
