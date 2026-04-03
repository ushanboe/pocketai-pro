package com.appforge.pocketai

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback

/**
 * Flutter platform channel bridge for Google LiteRT-LM (Gemma 4).
 *
 * MethodChannel  → initialize, cancel, dispose
 * EventChannel   → streaming token output via MessageCallback
 *
 * IMPORTANT API notes (verified from LiteRT-LM source):
 * - engine.initialize() is BLOCKING (not suspend) — run on background thread
 * - sendMessageAsync() streams Message objects, not Strings — use message.toString()
 * - Use callback-based sendMessageAsync for reliable streaming (matches Google Gallery app)
 * - SamplerConfig takes Double for topP/temperature, Int for topK
 * - Contents.of("text") for simple text, Contents.of(Content.Text(), Content.ImageBytes()) for multimodal
 * - conversation.cancelProcess() to abort in-flight generation
 *
 * To reuse in another app:
 * 1. Copy this file into your android/app/src/main/kotlin/<package>/
 * 2. Update the package name at the top
 * 3. Update channel names to match your app's package
 * 4. Register in MainActivity: LiteRtLmPlugin.register(flutterEngine.dartExecutor.binaryMessenger, this)
 * 5. Add gradle dependency: implementation("com.google.ai.edge.litertlm:litertlm-android:latest.release")
 * 6. Add to AndroidManifest.xml inside <application>:
 *    <uses-native-library android:name="libOpenCL.so" android:required="false"/>
 *    <uses-native-library android:name="libvndksupport.so" android:required="false"/>
 */
class LiteRtLmPlugin private constructor(
    private val context: Context,
    private val messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "LiteRtLm"
        private const val METHOD_CHANNEL = "com.appforge.pocketai/litertlm"
        private const val EVENT_CHANNEL = "com.appforge.pocketai/litertlm_stream"

        fun register(messenger: BinaryMessenger, context: Context) {
            val plugin = LiteRtLmPlugin(context, messenger)
            MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(plugin)
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(plugin.StreamHandler())
        }
    }

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val modelPath = call.argument<String>("modelPath")!!
                val backendStr = call.argument<String>("backend") ?: "gpu"

                scope.launch {
                    try {
                        // Dispose previous engine if any
                        try { conversation?.close() } catch (_: Exception) {}
                        conversation = null
                        try { engine?.close() } catch (_: Exception) {}
                        engine = null

                        val useGpu = backendStr != "cpu"
                        var initSuccess = false

                        // Try GPU first, fall back to CPU if GPU fails
                        if (useGpu) {
                            try {
                                Log.d(TAG, "Attempting GPU init for: $modelPath")
                                val eng = Engine(EngineConfig(
                                    modelPath = modelPath,
                                    backend = Backend.GPU(),
                                    visionBackend = Backend.GPU(),
                                    audioBackend = Backend.CPU(),
                                    cacheDir = context.cacheDir.path,
                                ))
                                // initialize() is BLOCKING — we're already on Dispatchers.Default
                                eng.initialize()
                                engine = eng
                                initSuccess = true
                                Log.d(TAG, "GPU init succeeded")
                            } catch (gpuErr: Exception) {
                                Log.w(TAG, "GPU init failed, falling back to CPU: ${gpuErr.message}")
                                try { engine?.close() } catch (_: Exception) {}
                                engine = null
                            }
                        }

                        // CPU fallback (or explicit CPU request)
                        if (!initSuccess) {
                            Log.d(TAG, "Attempting CPU init for: $modelPath")
                            val eng = Engine(EngineConfig(
                                modelPath = modelPath,
                                backend = Backend.CPU(),
                                visionBackend = Backend.CPU(),
                                audioBackend = Backend.CPU(),
                                cacheDir = context.cacheDir.path,
                            ))
                            eng.initialize()
                            engine = eng
                            Log.d(TAG, "CPU init succeeded")
                        }

                        withContext(Dispatchers.Main) {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Engine init failed completely: ${e.message}", e)
                        withContext(Dispatchers.Main) {
                            result.error("INIT_FAILED", "Engine init failed: ${e.message}", e.stackTraceToString())
                        }
                    }
                }
            }
            "cancel" -> {
                try { conversation?.cancelProcess() } catch (_: Exception) {}
                result.success(true)
            }
            "dispose" -> {
                try { conversation?.cancelProcess() } catch (_: Exception) {}
                try { conversation?.close() } catch (_: Exception) {}
                conversation = null
                try { engine?.close() } catch (_: Exception) {}
                engine = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    inner class StreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            if (events == null) return
            if (engine == null) {
                events.error("NO_ENGINE", "Engine not initialized. Call initialize() first, or the model file may be corrupted/incompatible.", null)
                return
            }

            val args = arguments as? Map<*, *> ?: run {
                events.error("BAD_ARGS", "Missing arguments", null)
                return
            }

            @Suppress("UNCHECKED_CAST")
            val messages = args["messages"] as? List<Map<String, String>> ?: emptyList()
            val temperature = (args["temperature"] as? Double) ?: 1.0
            val topK = (args["topK"] as? Int) ?: 10
            val topP = (args["topP"] as? Double) ?: 0.95
            val maxTokens = (args["maxTokens"] as? Int) ?: 512
            val imageBytes = args["imageBytes"] as? ByteArray

            try {
                // Close previous conversation
                try { conversation?.close() } catch (_: Exception) {}

                // Build system instruction from messages
                val systemMsg = messages.firstOrNull { it["role"] == "system" }?.get("content")

                // Create conversation with config
                val conv = engine!!.createConversation(ConversationConfig(
                    systemInstruction = if (systemMsg != null) Contents.of(systemMsg) else null,
                    samplerConfig = SamplerConfig(
                        topK = topK,
                        topP = topP,
                        temperature = temperature
                    ),
                ))
                conversation = conv

                // Get the user message
                val lastUserMsg = messages.lastOrNull { it["role"] == "user" }?.get("content") ?: ""

                // Build content list
                val contentList = mutableListOf<Content>()
                if (imageBytes != null) {
                    contentList.add(Content.ImageBytes(imageBytes))
                }
                contentList.add(Content.Text(lastUserMsg))

                val contents = Contents.of(contentList)

                Log.d(TAG, "Starting inference: \"${lastUserMsg.take(50)}...\", temp=$temperature, topK=$topK")

                // Use callback-based streaming (matches Google Gallery app pattern)
                conv.sendMessageAsync(
                    contents,
                    object : MessageCallback {
                        override fun onMessage(message: Message) {
                            // message.toString() returns the text content of this chunk
                            val text = message.toString()
                            val thinking = message.channels?.get("thought")

                            Log.v(TAG, "Token: \"${text.take(20)}\"")

                            // Post to main thread for Flutter EventChannel
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                if (thinking != null && thinking.isNotEmpty()) {
                                    events.success("<think>$thinking</think>")
                                }
                                if (text.isNotEmpty()) {
                                    events.success(text)
                                }
                            }
                        }

                        override fun onDone() {
                            Log.d(TAG, "Generation complete")
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                events.success("__DONE__")
                                events.endOfStream()
                            }
                        }

                        override fun onError(throwable: Throwable) {
                            Log.e(TAG, "Inference error: ${throwable.message}", throwable)
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                if (throwable is CancellationException) {
                                    events.success("__DONE__")
                                    events.endOfStream()
                                } else {
                                    events.error("INFERENCE_ERROR", "Inference failed: ${throwable.message}", throwable.stackTraceToString())
                                }
                            }
                        }
                    },
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start inference: ${e.message}", e)
                events.error("INFERENCE_ERROR", "Failed to start: ${e.message}", e.stackTraceToString())
            }
        }

        override fun onCancel(arguments: Any?) {
            try { conversation?.cancelProcess() } catch (_: Exception) {}
        }
    }
}
