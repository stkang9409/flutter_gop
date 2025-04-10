#import "PronunciationEvaluatorPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <onnxruntime/onnxruntime_cxx_api.h>

@interface PronunciationEvaluatorPlugin() <FlutterStreamHandler>
@property (nonatomic, strong) FlutterEventSink eventSink;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioInputNode *inputNode;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) NSString *currentText;
@property (nonatomic, strong) NSString *currentLanguage;
@property (nonatomic, strong) Ort::Env *ortEnv;
@property (nonatomic, strong) Ort::Session *ortSession;
@end

@implementation PronunciationEvaluatorPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    PronunciationEvaluatorPlugin* instance = [[PronunciationEvaluatorPlugin alloc] init];
    
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                    methodChannelWithName:@"pronunciation_evaluator"
                                    binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    FlutterEventChannel* eventChannel = [FlutterEventChannel
                                        eventChannelWithName:@"pronunciation_evaluator/events"
                                        binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];
    
    // Initialize ONNX Runtime
    instance.ortEnv = new Ort::Env(ORT_LOGGING_LEVEL_WARNING, "pronunciation_evaluator");
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"wav2vec2" ofType:@"onnx"];
    Ort::SessionOptions sessionOptions;
    instance.ortSession = new Ort::Session(*instance.ortEnv, [modelPath UTF8String], sessionOptions);
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"startEvaluation" isEqualToString:call.method]) {
        NSString *text = call.arguments[@"text"];
        NSString *language = call.arguments[@"language"];
        if (text && language) {
            [self startEvaluation:text language:language result:result];
        } else {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                     message:@"Text and language must be provided"
                                     details:nil]);
        }
    } else if ([@"stopEvaluation" isEqualToString:call.method]) {
        [self stopEvaluation:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startEvaluation:(NSString*)text language:(NSString*)language result:(FlutterResult)result {
    if (self.isRecording) {
        result([FlutterError errorWithCode:@"ALREADY_RECORDING"
                                 message:@"Evaluation is already in progress"
                                 details:nil]);
        return;
    }
    
    self.currentText = text;
    self.currentLanguage = language;
    self.isRecording = YES;
    
    // Configure audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    [audioSession setActive:YES error:nil];
    
    // Setup audio engine
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.inputNode = [self.audioEngine inputNode];
    
    // Configure audio format
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                            sampleRate:16000
                                                              channels:1
                                                           interleaved:NO];
    
    // Install tap on input node
    [self.inputNode installTapOnBus:0 bufferSize:4096 format:format block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        if (!self.isRecording) return;
        
        // Get audio data
        float *audioData = buffer.floatChannelData[0];
        UInt32 frameCount = buffer.frameLength;
        
        // Prepare input tensor
        std::vector<int64_t> inputShape = {1, frameCount};
        Ort::Value inputTensor = Ort::Value::CreateTensor<float>(self.ortEnv->GetAllocator(),
                                                               inputShape.data(),
                                                               inputShape.size());
        
        // Copy audio data to tensor
        float* tensorData = inputTensor.GetTensorMutableData<float>();
        memcpy(tensorData, audioData, frameCount * sizeof(float));
        
        // Run inference
        const char* inputName = "input";
        const char* outputName = "output";
        std::vector<const char*> inputNames = {inputName};
        std::vector<const char*> outputNames = {outputName};
        std::vector<Ort::Value> inputs = {std::move(inputTensor)};
        
        auto outputTensors = self.ortSession->Run(Ort::RunOptions{nullptr},
                                                inputNames.data(),
                                                inputs.data(),
                                                inputs.size(),
                                                outputNames.data(),
                                                outputNames.size());
        
        // Process results
        float* outputData = outputTensors[0].GetTensorMutableData<float>();
        NSInteger score = [self calculateScore:outputData size:frameCount];
        NSArray *wordScores = [self processWordScores:outputData size:frameCount text:text];
        
        // Send results
        NSDictionary *resultDict = @{
            @"sentence": @{
                @"text": self.currentText,
                @"score": @(score)
            },
            @"words": wordScores
        };
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:resultDict options:0 error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.eventSink(jsonString);
        });
    }];
    
    // Start audio engine
    [self.audioEngine startAndReturnError:nil];
    result(nil);
}

- (NSInteger)calculateScore:(float*)outputData size:(NSInteger)size {
    // Implement your scoring logic here
    float sum = 0;
    for (NSInteger i = 0; i < size; i++) {
        sum += outputData[i];
    }
    return (NSInteger)((sum / size) * 100);
}

- (NSArray*)processWordScores:(float*)outputData size:(NSInteger)size text:(NSString*)text {
    // Implement word-level scoring logic here
    NSArray *words = [text componentsSeparatedByString:@" "];
    NSMutableArray *wordScores = [NSMutableArray array];
    
    for (NSString *word in words) {
        [wordScores addObject:@{
            @"text": word,
            @"score": @80 // Placeholder score
        }];
    }
    
    return wordScores;
}

- (void)stopEvaluation:(FlutterResult)result {
    self.isRecording = NO;
    [self.audioEngine stop];
    [self.inputNode removeTapOnBus:0];
    self.audioEngine = nil;
    self.inputNode = nil;
    result(nil);
}

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void)dealloc {
    delete self.ortSession;
    delete self.ortEnv;
}

@end 