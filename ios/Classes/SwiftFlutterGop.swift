import Flutter
import UIKit
import AVFoundation

public class SwiftFlutterGop: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var audioEngine: AVAudioEngine?
  private var audioRecorder: AVAudioRecorder?
  private var isRecording = false
  private var currentText: String?
  private var currentLanguage: String?
  private var engineWrapper: FlutterGopWrapper?
  private var tempAudioFilePath: URL?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_gop", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterGop()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    let eventChannel = FlutterEventChannel(name: "flutter_gop/events", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startEvaluation":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            let language = args["language"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS",
                          message: "텍스트와 언어를 제공해야 합니다",
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
  
  private func getModelFilePath() -> (modelPath: String?, tokenizerPath: String?) {
    let bundle = Bundle(for: SwiftFlutterGop.self)
    
    // 리소스 번들 가져오기
    guard let resourceBundleURL = bundle.url(forResource: "flutter_gop_models", withExtension: "bundle"),
          let resourceBundle = Bundle(url: resourceBundleURL) else {
      return (nil, nil)
    }
    
    let modelPath = resourceBundle.path(forResource: "wav2vec2_ctc_dynamic", ofType: "onnx")
    let tokenizerPath = resourceBundle.path(forResource: "tokenizer", ofType: "json")
    
    return (modelPath, tokenizerPath)
  }
  
  private func startEvaluation(text: String, language: String, result: @escaping FlutterResult) {
    if isRecording {
      result(FlutterError(code: "ALREADY_RECORDING",
                        message: "이미 평가가 진행 중입니다",
                        details: nil))
      return
    }
    
    currentText = text
    currentLanguage = language
    
    // 모델 파일 경로 가져오기
    let modelPaths = getModelFilePath()
    guard let modelPath = modelPaths.modelPath,
          let tokenizerPath = modelPaths.tokenizerPath else {
      result(FlutterError(code: "MODEL_NOT_FOUND",
                          message: "모델 또는 토크나이저를 찾을 수 없습니다",
                          details: nil))
      return
    }
    
    // 임시 오디오 파일 경로 설정
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    tempAudioFilePath = documentsDirectory.appendingPathComponent("temp_recording.wav")
    
    // 엔진 초기화
    engineWrapper = FlutterGopWrapper(
      modelPath: modelPath,
      tokenizerPath: tokenizerPath,
      device: "CPU",
      updateInterval: 0.5,
      confidenceThreshold: 0.6
    )
    
    // 콜백 설정
    engineWrapper?.setCallbacks(
      { [weak self] in
        DispatchQueue.main.async {
          self?.eventSink?(["status": "started"])
        }
      },
      onTick: { [weak self] current, total in
        DispatchQueue.main.async {
          self?.eventSink?(["status": "processing", "progress": Float(current) / Float(total)])
        }
      },
      onFail: { [weak self] message in
        DispatchQueue.main.async {
          self?.eventSink?(["status": "error", "message": message])
        }
      },
      onEnd: { [weak self] in
        DispatchQueue.main.async {
          self?.eventSink?(["status": "completed"])
        }
      },
      onScore: { [weak self] scoreJson in
        DispatchQueue.main.async {
          self?.eventSink?(["status": "result", "data": scoreJson])
        }
      }
    )
    
    // 엔진 초기화
    let success = engineWrapper?.initialize(
      withSentence: text,
      audioPollingInterval: 0.1,
      minTimeBetweenEvals: 1.0
    ) ?? false
    
    if !success {
      result(FlutterError(code: "ENGINE_INIT_FAILED",
                          message: "엔진 초기화에 실패했습니다",
                          details: nil))
      return
    }
    
    // 오디오 세션 설정
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      result(FlutterError(code: "AUDIO_SESSION_ERROR",
                        message: "오디오 세션 설정에 실패했습니다",
                        details: error.localizedDescription))
      return
    }
    
    // 오디오 녹음 설정
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVSampleRateKey: 16000.0,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false
    ]
    
    do {
      audioRecorder = try AVAudioRecorder(url: tempAudioFilePath!, settings: settings)
      audioRecorder?.record()
      isRecording = true
      
      // 실시간 평가 시작
      engineWrapper?.startEvaluation(withAudioFilePath: tempAudioFilePath!.path)
      
      result(nil)
    } catch {
      result(FlutterError(code: "RECORDER_ERROR",
                        message: "오디오 녹음 설정에 실패했습니다",
                        details: error.localizedDescription))
    }
  }
  
  private func stopEvaluation(result: @escaping FlutterResult) {
    isRecording = false
    
    audioRecorder?.stop()
    audioRecorder = nil
    
    engineWrapper?.stopEvaluation()
    
    // 최종 결과 획득
    if let finalResults = engineWrapper?.getResults() {
      eventSink?(["status": "final_result", "data": finalResults])
    }
    
    engineWrapper?.reset()
    
    do {
      try AVAudioSession.sharedInstance().setActive(false)
    } catch {
      print("오디오 세션 비활성화에 실패했습니다: \(error)")
    }
    
    // 임시 파일 정리
    if let path = tempAudioFilePath {
      try? FileManager.default.removeItem(at: path)
      tempAudioFilePath = nil
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