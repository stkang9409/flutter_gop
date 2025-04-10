package com.example.flutter_gop

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import com.microsoft.onnxruntime.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread
import kotlin.math.min

class FlutterGop: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private var audioRecord: AudioRecord? = null
  private var isRecording = false
  private var handler = Handler(Looper.getMainLooper())
  private var ortEnv: OrtEnvironment? = null
  private var ortSession: OrtSession? = null
  private var currentText: String? = null
  private var currentLanguage: String? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "pronunciation_evaluator")
    channel.setMethodCallHandler(this)
    
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "pronunciation_evaluator/events")
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventSink = null
      }
    })

    // Initialize ONNX Runtime
    ortEnv = OrtEnvironment.getEnvironment()
    val modelPath = flutterPluginBinding.applicationContext.filesDir.absolutePath + "/wav2vec2.onnx"
    ortSession = ortEnv?.createSession(modelPath, OrtSession.SessionOptions())
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "startEvaluation" -> {
        val text = call.argument<String>("text")
        val language = call.argument<String>("language")
        if (text != null && language != null) {
          startEvaluation(text, language, result)
        } else {
          result.error("INVALID_ARGUMENTS", "Text and language must be provided", null)
        }
      }
      "stopEvaluation" -> {
        stopEvaluation(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun startEvaluation(text: String, language: String, result: Result) {
    if (isRecording) {
      result.error("ALREADY_RECORDING", "Evaluation is already in progress", null)
      return
    }

    currentText = text
    currentLanguage = language
    isRecording = true

    // 오디오 설정
    val sampleRate = 16000
    val channelConfig = AudioFormat.CHANNEL_IN_MONO
    val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)

    audioRecord = AudioRecord(
      MediaRecorder.AudioSource.MIC,
      sampleRate,
      channelConfig,
      audioFormat,
      bufferSize
    )

    audioRecord?.startRecording()

    // 오디오 처리 스레드 시작
    thread(start = true) {
      val buffer = ByteArray(bufferSize)
      val floatBuffer = FloatArray(bufferSize / 2)

      while (isRecording) {
        val read = audioRecord?.read(buffer, 0, bufferSize) ?: 0
        if (read > 0) {
          // PCM 16비트를 float로 변환
          val byteBuffer = ByteBuffer.wrap(buffer)
          byteBuffer.order(ByteOrder.LITTLE_ENDIAN)
          for (i in 0 until read / 2) {
            floatBuffer[i] = byteBuffer.short.toFloat() / 32768.0f
          }

          // Prepare input tensor
          val inputShape = longArrayOf(1, read.toLong() / 2)
          val inputTensor = OnnxTensor.createTensor(ortEnv, floatBuffer, inputShape)

          // Run inference
          val inputs = mapOf("input" to inputTensor)
          val output = ortSession?.run(inputs)
          val outputTensor = output?.get(0) as OnnxTensor
          val outputData = outputTensor.floatBuffer.array()

          // Process results
          val score = calculateScore(outputData)
          val wordScores = processWordScores(outputData, text)

          val resultJson = JSONObject().apply {
            put("sentence", JSONObject().apply {
              put("text", currentText)
              put("score", score)
            })
            put("words", wordScores)
          }

          handler.post {
            eventSink?.success(resultJson.toString())
          }

          inputTensor.close()
          outputTensor.close()
        }
      }
    }

    result.success(null)
  }

  private fun calculateScore(outputData: FloatArray): Int {
    // Wav2Vec2 모델의 출력은 각 프레임에 대한 확률 분포
    // 발음 점수는 전체 프레임의 평균 확률을 기반으로 계산
    val frameScores = mutableListOf<Float>()
    
    // 각 프레임의 최대 확률값을 점수로 사용
    for (i in outputData.indices step 29) { // 29는 Wav2Vec2의 출력 차원
      val frameProbabilities = outputData.slice(i until minOf(i + 29, outputData.size))
      val maxProbability = frameProbabilities.maxOrNull() ?: 0f
      frameScores.add(maxProbability)
    }
    
    // 전체 프레임의 평균 점수를 0-100 범위로 변환
    val averageScore = frameScores.average()
    return (averageScore * 100).toInt()
  }

  private fun processWordScores(outputData: FloatArray, text: String): Array<JSONObject> {
    val words = text.split(" ")
    val wordScores = mutableListOf<JSONObject>()
    
    // 각 단어의 길이에 따라 프레임을 분할
    val totalFrames = outputData.size / 29
    val framesPerWord = totalFrames / words.size
    
    for ((index, word) in words.withIndex()) {
      val startFrame = index * framesPerWord
      val endFrame = minOf((index + 1) * framesPerWord, totalFrames)
      
      // 해당 단어의 프레임들에 대한 점수 계산
      val wordFrameScores = mutableListOf<Float>()
      for (frame in startFrame until endFrame) {
        val startIdx = frame * 29
        val endIdx = minOf(startIdx + 29, outputData.size)
        val frameProbabilities = outputData.slice(startIdx until endIdx)
        val maxProbability = frameProbabilities.maxOrNull() ?: 0f
        wordFrameScores.add(maxProbability)
      }
      
      // 단어의 평균 점수를 0-100 범위로 변환
      val wordScore = (wordFrameScores.average() * 100).toInt()
      
      wordScores.add(JSONObject().apply {
        put("text", word)
        put("score", wordScore)
      })
    }
    
    return wordScores.toTypedArray()
  }

  private fun stopEvaluation(result: Result) {
    isRecording = false
    audioRecord?.stop()
    audioRecord?.release()
    audioRecord = null
    result.success(null)
    ortSession?.close()
    ortEnv?.close()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }
} 