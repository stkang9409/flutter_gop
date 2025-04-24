#import "FlutterGopWrapper.h"
#include "../realtime_engine_c.h"

// C 콜백 함수들을 위한 글로벌 변수
static void (^startCallback)(void);
static void (^tickCallback)(int, int);
static void (^failCallback)(NSString *);
static void (^endCallback)(void);
static void (^scoreCallback)(NSString *);

// C 콜백 함수 구현
void onStartCallback() {
    if (startCallback) {
        startCallback();
    }
}

void onTickCallback(int current, int total) {
    if (tickCallback) {
        tickCallback(current, total);
    }
}

void onFailCallback(const char* message) {
    if (failCallback) {
        failCallback([NSString stringWithUTF8String:message]);
    }
}

void onEndCallback() {
    if (endCallback) {
        endCallback();
    }
}

void onScoreCallback(const char* score_json) {
    if (scoreCallback) {
        scoreCallback([NSString stringWithUTF8String:score_json]);
    }
}

@implementation FlutterGopWrapper {
    EngineCoordinatorHandle _engineHandle;
}

- (instancetype)initWithModelPath:(NSString *)modelPath 
                    tokenizerPath:(NSString *)tokenizerPath 
                           device:(NSString *)device 
                   updateInterval:(float)updateInterval 
              confidenceThreshold:(float)confidenceThreshold {
    self = [super init];
    if (self) {
        _engineHandle = engine_create(
            [modelPath UTF8String],
            [tokenizerPath UTF8String],
            [device UTF8String],
            updateInterval,
            confidenceThreshold);
        
        if (!_engineHandle) {
            return nil;
        }
    }
    return self;
}

- (void)setCallbacks:(void(^)(void))onStart
              onTick:(void(^)(int current, int total))onTick
              onFail:(void(^)(NSString *message))onFail
               onEnd:(void(^)(void))onEnd
             onScore:(void(^)(NSString *scoreJson))onScore {
    startCallback = onStart;
    tickCallback = onTick;
    failCallback = onFail;
    endCallback = onEnd;
    scoreCallback = onScore;
    
    engine_set_listener(
        _engineHandle,
        onStartCallback,
        onTickCallback,
        onFailCallback,
        onEndCallback,
        onScoreCallback);
}

- (BOOL)initializeWithSentence:(NSString *)sentence 
          audioPollingInterval:(float)audioPollingInterval 
         minTimeBetweenEvals:(float)minTimeBetweenEvals {
    return engine_initialize(
        _engineHandle,
        [sentence UTF8String],
        audioPollingInterval,
        minTimeBetweenEvals);
}

- (BOOL)startEvaluationWithAudioFilePath:(NSString *)audioFilePath {
    return engine_start_evaluation(_engineHandle, [audioFilePath UTF8String]);
}

- (void)stopEvaluation {
    engine_stop_evaluation(_engineHandle);
}

- (void)reset {
    engine_reset(_engineHandle);
}

- (NSString *)getResults {
    const char* results = engine_get_results(_engineHandle);
    NSString* resultsString = [NSString stringWithUTF8String:results];
    engine_free_string((char*)results);
    return resultsString;
}

- (NSString *)evaluateSpeech:(NSString *)sentence audioFilePath:(NSString *)audioFilePath {
    const char* results = engine_evaluate_speech(
        _engineHandle,
        [sentence UTF8String],
        [audioFilePath UTF8String]);
    
    NSString* resultsString = [NSString stringWithUTF8String:results];
    engine_free_string((char*)results);
    return resultsString;
}

- (void)dealloc {
    if (_engineHandle) {
        engine_destroy(_engineHandle);
        _engineHandle = NULL;
    }
}

@end