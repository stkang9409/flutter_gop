import Flutter
import UIKit
import AVFoundation

public class SwiftPronunciationEvaluatorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var audioEngine: AVAudioEngine?
  private var isRecording = false
  private var currentText: String?
  private var currentLanguage: String?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pronunciation_evaluator", binaryMessenger: registrar.messenger())
    let instance = SwiftPronunciationEvaluatorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    let eventChannel = FlutterEventChannel(name: "pronunciation_evaluator/events", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startEvaluation":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            let language = args["language"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "Text and language must be provided",
                          details: nil))
        return
      }
      startEvaluation(text: text, language: language, result: result)
    case "stopEvaluation":
      stopEvaluation(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func startEvaluation(text: String, language: String, result: @escaping FlutterResult) {
    if isRecording {
      result(FlutterError(code: "ALREADY_RECORDING",
                        message: "Evaluation is already in progress",
                        details: nil))
      return
    }
    
    currentText = text
    currentLanguage = language
    
    // 오디오 세션 설정
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      result(FlutterError(code: "AUDIO_SESSION_ERROR",
                        message: "Failed to set up audio session",
                        details: error.localizedDescription))
      return
    }
    
    // 오디오 엔진 설정
    audioEngine = AVAudioEngine()
    let inputNode = audioEngine?.inputNode
    let inputFormat = inputNode?.outputFormat(forBus: 0)
    let sampleRate = inputFormat?.sampleRate ?? 16000
    
    // 버퍼 크기 설정 (1초 분량)
    let bufferSize = AVAudioFrameCount(sampleRate)
    
    inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
      guard let self = self, self.isRecording else { return }
      
      // 오디오 데이터를 float 배열로 변환
      let channelData = buffer.floatChannelData?[0]
      let frameLength = Int(buffer.frameLength)
      
      if let channelData = channelData {
        // 여기에 ONNX Runtime으로 모델 추론 코드 추가
        // 임시로 더미 결과 생성
        let dummyResult: [String: Any] = [
          "sentence": [
            "text": self.currentText ?? "",
            "score": 85
          ],
          "words": [
            [
              "text": "Hello",
              "score": 90
            ],
            [
              "text": "world",
              "score": 80
            ]
          ]
        ]
        
        DispatchQueue.main.async {
          self.eventSink?(dummyResult)
        }
      }
    }
    
    do {
      try audioEngine?.start()
      isRecording = true
      result(nil)
    } catch {
      result(FlutterError(code: "AUDIO_ENGINE_ERROR",
                        message: "Failed to start audio engine",
                        details: error.localizedDescription))
    }
  }
  
  private func stopEvaluation(result: @escaping FlutterResult) {
    isRecording = false
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil
    
    do {
      try AVAudioSession.sharedInstance().setActive(false)
    } catch {
      print("Failed to deactivate audio session: \(error)")
    }
    
    result(nil)
  }
  
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
} 