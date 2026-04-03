package com.appforge.pocketai

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect

import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Content

/**
 * Flutter platform channel bridge for Google LiteRT-LM (Gemma 4).
 *
 * MethodChannel  → initialize, cancel, dispose
 * EventChannel   → streaming token output
 *
 * To reuse in another app:
 * 1. Copy this file into your android/app/src/main/kotlin/<package>/
 * 2. Update the package name at the top
 * 3. Update channel names to match your app's package
 * 4. Register in MainActivity: LiteRtLmPlugin.register(flutterEngine.dartExecutor.binaryMessenger, this)
 * 5. Add gradle dependency: implementation("com.google.ai.edge.litertlm:litertlm-android:latest.release")
 */
class LiteRtLmPlugin private constructor(
    private val context: Context,
    private val messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
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
    private var activeJob: Job? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val modelPath = call.argument<String>("modelPath")!!
                val backendStr = call.argument<String>("backend") ?: "gpu"

                scope.launch {
                    try {
                        // Dispose previous engine if any
                        conversation = null
                        engine?.close()

                        val backend = if (backendStr == "cpu") Backend.CPU() else Backend.GPU()

                        engine = Engine(EngineConfig(
                            modelPath = modelPath,
                            backend = backend,
                            visionBackend = backend,
                            audioBackend = Backend.CPU()
                        ))
                        engine!!.initialize()

                        withContext(Dispatchers.Main) {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("INIT_FAILED", e.message, null)
                        }
                    }
                }
            }
            "cancel" -> {
                activeJob?.cancel()
                activeJob = null
                result.success(true)
            }
            "dispose" -> {
                activeJob?.cancel()
                conversation = null
                engine?.close()
                engine = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    inner class StreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            if (events == null || engine == null) {
                events?.error("NO_ENGINE", "Engine not initialized", null)
                return
            }

            val args = arguments as? Map<*, *> ?: run {
                events.error("BAD_ARGS", "Missing arguments", null)
                return
            }

            @Suppress("UNCHECKED_CAST")
            val messages = args["messages"] as? List<Map<String, String>> ?: emptyList()
            val temperature = (args["temperature"] as? Double) ?: 1.0
            val topK = (args["topK"] as? Int) ?: 64
            val topP = (args["topP"] as? Double) ?: 0.95
            val maxTokens = (args["maxTokens"] as? Int) ?: 512
            val imageBytes = args["imageBytes"] as? ByteArray

            activeJob = scope.launch {
                try {
                    // Create a new conversation with sampling config
                    val conv = engine!!.createConversation(ConversationConfig(
                        samplerConfig = SamplerConfig(
                            topK = topK,
                            topP = topP,
                            temperature = temperature
                        )
                    ))
                    conversation = conv

                    // Build the prompt from messages
                    val lastUserMsg = messages.lastOrNull { it["role"] == "user" }?.get("content") ?: ""

                    // Build content with optional image
                    val contents = if (imageBytes != null) {
                        Contents.of(
                            Content.ImageBytes(imageBytes),
                            Content.Text(lastUserMsg)
                        )
                    } else {
                        Contents.of(Content.Text(lastUserMsg))
                    }

                    // Stream response tokens
                    conv.sendMessageAsync(contents).collect { token ->
                        withContext(Dispatchers.Main) {
                            events.success(token)
                        }
                    }

                    withContext(Dispatchers.Main) {
                        events.success("__DONE__")
                        events.endOfStream()
                    }
                } catch (e: CancellationException) {
                    withContext(Dispatchers.Main) {
                        events.success("__DONE__")
                        events.endOfStream()
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        events.error("INFERENCE_ERROR", e.message, null)
                    }
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            activeJob?.cancel()
            activeJob = null
        }
    }
}
