# MyTinyAI Pro

**Think big. Run tiny.** — Offline AI chat assistant for Android powered by multi-backend on-device LLM inference. Privacy-first: no internet required for chat, no accounts, no data leaves your device.

**Website:** [mytinyai.app](https://mytinyai.app)

## What's new in Pro

- **Multi-backend inference architecture** — Supports both fllama (llama.cpp/GGUF) and Google LiteRT-LM (.litertlm) backends
- **Gemma 4 support** — Google's latest on-device models (E2B 2.6GB, E4B 3.7GB) with multimodal input (text + vision + audio), 32K context, built-in thinking mode, and tool calling
- **Extensible backend system** — Abstract `InferenceBackend` interface makes adding new runtimes (ONNX, CoreML, TFLite) straightforward
- **See [GEMMA4_INTEGRATION.md](GEMMA4_INTEGRATION.md)** for the full integration guide including build issues & fixes

## Features

- **19 LLM models** — Qwen, Llama, Gemma 2/3/4, DeepSeek, Phi, SmolLM, Granite, TinyLlama, MiniCPM-V (0.5B–E4B params)
- **2 vision models** — MobileVLM V2 1.7B (light) and MobileVLM 3B (best quality): describe photos, read text in images, answer visual questions on-device
- **Optimised vision pipeline** — Higher-quality image capture (768x768@90%), low temperature (0.3), boosted max tokens (1024) for detailed image descriptions
- **Hey Tiny voice mode** — Continuous hands-free conversation: STT → inference → TTS → auto-listen loop with animated "Thinking" indicator
- **Voice interaction** — Speech-to-text input (mic button) and text-to-speech output (speaker icon on AI messages)
- **Home screen widget** — Quick-access widget to open MyTinyAI directly from home screen
- **App shortcuts** — Long-press app icon for "New Chat" and "Hey Tiny" quick actions
- **Image upload** — Camera or gallery picker for vision model (auto-hidden for text-only models)
- **Animated typing dots** — Bouncing wave animation while AI generates responses
- **RAM monitor** — Live memory usage indicator in AppBar (turns red above 3 GB)
- **8 personas** — AI Assistant, Friend, Boyfriend, Girlfriend, Mentor, Tutor, Life Coach, Chatterbox
- **Chatterbox persona** — Chatty, fun personality that uses your profile (name, likes, hobbies, dislikes, favorite topics) for personalized conversations. Short 2-3 sentence responses optimized for TTS.
- **User profile** — Onboarding collects firstname, likes, hobbies, dislikes, favorite topics. Editable in Settings with explicit Save button. Used by Chatterbox persona's dynamic system prompt.
- **Resumable downloads** — Large model downloads resume from where they left off if interrupted
- **Wake lock** — Screen stays awake during downloads to prevent Android from killing transfers
- **Conversation management** — Multiple conversations, rename, delete, drawer navigation
- **Prompt templates** — Quick-start prompts for common tasks
- **Thinking toggle** — Show/hide model reasoning (<think> blocks) from Qwen 3 and DeepSeek R1
- **AI Glossary** — Plain-English explanations of 16 common LLM terms
- **Configurable inference** — Temperature, max tokens, system prompt customisation
- **Fully offline** — All inference runs locally via llama.cpp. Internet only needed to download models.
- **Dark theme** — Slate/blue dark UI optimised for OLED

## Architecture

```
lib/
  core/
    models/          # Data models (ModelInfo + InferenceBackendType, Message, Conversation, AppSettings)
    providers/       # State management (ModelProvider, SettingsProvider, ConversationProvider)
    services/
      inference_backend.dart   # Abstract interface for all backends
      inference_engine.dart    # Router — delegates to correct backend by model type
      fllama_backend.dart      # Backend: llama.cpp via fllama (GGUF models)
      litertlm_backend.dart    # Backend: Google LiteRT-LM (Gemma 4 .litertlm models)
      database_helper.dart     # SQLite for conversations/messages
    theme/           # AppTheme
  features/
    chat/            # Chat screen, conversations drawer, prompt templates, voice mode
    models/          # Model catalog, download management
    settings/        # Settings screen, persona picker, AI glossary, acknowledgements
    onboarding/      # Splash + onboarding screens (5 pages incl. "About You" profile)
  main.dart          # App entry point

android/
  app/src/main/kotlin/.../
    MainActivity.kt        # Registers LiteRtLmPlugin platform channel
    LiteRtLmPlugin.kt      # Kotlin bridge to LiteRT-LM SDK (MethodChannel + EventChannel)
    MyTinyAIWidget.kt      # Home screen widget (AppWidgetProvider)
  res/xml/           # App shortcuts (shortcuts.xml), widget config (widget_info.xml)
  res/layout/        # Home screen widget layout (widget_layout.xml)
```

**Key dependencies:**
- `fllama` — Flutter wrapper for llama.cpp (on-device LLM inference for GGUF models)
- `litertlm-android` — Google LiteRT-LM SDK (on-device inference for Gemma 4 .litertlm models)
- `provider` — State management
- `sqflite` — Local SQLite for conversations/messages
- `image_picker` — Camera/gallery for vision model
- `flutter_tts` / `speech_to_text` — Voice interaction + Hey Tiny voice mode
- `wakelock_plus` — Keep screen awake during model downloads
- `flutter_markdown` — Render AI responses with markdown
- `flutter_animate` — Animated typing dots (staggered scale animation)

## Model Catalog

| Model | Size | Capability | Min RAM |
|-------|------|-----------|---------|
| Qwen 2.5 0.5B | 386 MB | Chat | 1 GB |
| Qwen 3 0.6B | 484 MB | Reasoning | 1 GB |
| Gemma 3 1B | 806 MB | Chat | 1.5 GB |
| TinyLlama 1.1B Chat | 637 MB | Chat | 1.5 GB |
| Llama 3.2 1B | 750 MB | Instruct | 2 GB |
| SmolLM2 1.7B | 1.06 GB | Reasoning | 2 GB |
| DeepSeek R1 1.5B | 1.12 GB | Reasoning | 2 GB |
| Qwen 2.5 1.5B | 1.12 GB | Chat | 2 GB |
| Granite 3.1 2B | 1.55 GB | Instruct | 2.5 GB |
| Gemma 2 2B | 1.71 GB | Instruct | 2.5 GB |
| Llama 3.2 3B | 2.02 GB | Instruct | 4 GB |
| Qwen 2.5 3B | 2.11 GB | Reasoning | 4 GB |
| MobileVLM V2 1.7B Vision | 792 MB + 595 MB mmproj | Vision | 2 GB |
| MobileVLM 3B Vision | 1.64 GB + 640 MB mmproj | Vision | 3 GB |
| Phi-3.5 Mini 3.8B | 2.18 GB | Reasoning | 4 GB |
| MiniCPM-V 4 4.1B | 2.19 GB | Chat | 4 GB |
| Gemma 3 4B | 2.49 GB | Chat | 4 GB |

### fllama backend (GGUF models)
All fllama models are Q4_K_M or Q8_0 quantised GGUF files from public HuggingFace repos (no auth required).

**Notes:**
- MobileVLM vision models use LDP/LDPv2 projectors — natively compatible with fllama's llama.cpp
- MiniCPM-V 4 runs as text-only chat (CLIP vision format incompatible with fllama)
- Gemma 3 4B runs as text-only chat (vision has a [known llama.cpp bug](https://github.com/ggml-org/llama.cpp/issues/12784) — loads but produces no output)

### LiteRT-LM backend (Gemma 4 models)

| Model | Size | Capability | Min RAM | Context |
|-------|------|-----------|---------|---------|
| Gemma 4 E2B | 2.6 GB | Multimodal | 8 GB | 32K |
| Gemma 4 E4B | 3.7 GB | Multimodal | 12 GB | 32K |

Gemma 4 models use `.litertlm` format via Google's LiteRT-LM SDK. Features: text + vision + audio input, built-in thinking mode, tool calling. Android 12+ only (iOS not yet supported).

## Build

**Prerequisites:** Flutter SDK 3.41+, Dart 3.11+, Android SDK, NDK 28.2+

```bash
# Debug
flutter run

# Release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (~114 MB)
```

### Known Build Issues (IMPORTANT)

The following issues WILL occur on first build. See [GEMMA4_INTEGRATION.md](GEMMA4_INTEGRATION.md#build-issues--fixes-critical--read-before-building) for detailed fixes.

| # | Error | Cause | Fix |
|---|-------|-------|-----|
| 1 | `version solving failed` (SDK >=3.10.0) | Flutter too old | `flutter upgrade` to 3.41+ |
| 2 | `ld.lld: error: unable to find library -lcpp-httplib` | llama.cpp common links httplib unconditionally | Patch `~/.pub-cache/git/fllama-<hash>/src/llama.cpp/common/CMakeLists.txt` to make httplib conditional |
| 3 | `Argument type mismatch: Float vs Double` in LiteRtLmPlugin.kt | LiteRT-LM SamplerConfig expects Double | Already fixed in codebase — don't use `.toFloat()` |
| 4 | Kotlin metadata version warning (2.3.0 vs 2.2.0) | litertlm-android compiled with newer Kotlin | Non-fatal, no runtime impact |
| 5 | Build appears stuck for 10+ minutes | llama.cpp C++ compilation for 3 ABIs | Normal — wait for it, ~12 min first build |

**Note:** Issue #2 (httplib patch) is in the pub cache and may need to be re-applied after `flutter pub get` or `flutter clean`.

## Permissions

- `INTERNET` — Download models from HuggingFace
- `RECORD_AUDIO` — Voice input (speech-to-text) + Hey Tiny voice mode
- `CAMERA` — Take photos for vision model

## Version History

- **v14 (Pro)** — Multi-backend inference architecture: abstract `InferenceBackend` interface with `FllamaBackend` (GGUF/llama.cpp) and `LiteRtLmBackend` (Google LiteRT-LM). Added Gemma 4 E2B + E4B models (multimodal, 32K context, thinking mode, tool calling). Kotlin platform channel (`LiteRtLmPlugin.kt`) bridges Flutter to native LiteRT-LM SDK. `InferenceEngine` refactored as backend router. `ModelInfo` gains `backendType` field. minSdk bumped to 31 (Android 12+). 19 models total across 2 backends. Build issues documented in GEMMA4_INTEGRATION.md.
- **v13** — Chatterbox persona: chatty, fun personality that personalizes conversations using user profile data. User profile system: onboarding collects name, likes, hobbies, dislikes, favorite topics (new "About You" page 4/5). Profile editable in Settings with Save button + green confirmation snackbar. Dynamic system prompt builder `_buildChatterboxPrompt()` injects profile into short (~50 word) system prompt optimized for small LLMs. Responses capped at 2-3 sentences for TTS compatibility. 8 personas total.
- **v12** — Optimised vision quality: higher image capture (768x768@90% vs 512x512@75%), forced low temperature (0.3) and boosted max tokens (1024) for vision, specific vision system prompt for detailed descriptions. Removed presencePenalty for all inference.
- **v11** — Replaced broken Gemma 3 4B Vision with MobileVLM V2 1.7B + MobileVLM 3B (LDP/LDPv2 projectors, natively compatible with fllama). Gemma 3 4B demoted to text-only (known llama.cpp vision bug). SmolVLM rejected (idefics3 projector unsupported). 17 models total. Vision debug diagnostics.
- **v10** — Added MiniCPM-V 4 4.1B model (15 models total), animated typing dots (bouncing wave), animated "Thinking" indicator in voice mode, live RAM monitor in AppBar, vision context size boost (8192), reduced image resolution for faster vision inference (512x512@75%), auto-download missing mmproj files for vision models
- **v9** — Rebranded to MyTinyAI (mytinyai.app), "Hey Tiny" continuous voice mode (STT→inference→TTS→auto-listen loop), home screen widget, app shortcuts (long-press: New Chat, Hey Tiny), "Think big. Run tiny." tagline
- **v8** — Show Thinking toggle (hide/show reasoning from Qwen 3, DeepSeek R1), AI Glossary (16 LLM terms explained), replaced raw licenses with clean Acknowledgements page
- **v7** — Added Qwen 3 0.6B model (14 models total), hybrid thinking mode
- **v6** — Fixed Android manifest for speech recognition (added RecognitionService query for Android 11+), auto-inject permissions in build pipeline
- **v5** — Fixed STT (one-time init at startup), TTS (completion/cancel/error handlers), doubled speaker icon size
- **v4** — Wake lock during downloads (wakelock_plus) to prevent Android from killing background transfers
- **v3** — Resumable downloads, friendly error messages, file size verification
- **v2** — Multimodal vision (Gemma 3 4B), voice input/output, image upload, 7 personas
- **v1** — 13 model catalog, real fllama inference, conversation management

## License

Private — not for redistribution.
