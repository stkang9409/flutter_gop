#import <Foundation/Foundation.h>

@interface FlutterGopWrapper : NSObject

// 초기화 메서드
- (instancetype)initWithModelPath:(NSString *)modelPath 
                    tokenizerPath:(NSString *)tokenizerPath 
                           device:(NSString *)device 
                   updateInterval:(float)updateInterval 
              confidenceThreshold:(float)confidenceThreshold;

// 콜백 설정 (메서드 이름 변경)
- (void)setCallbacks:(void(^)(void))onStart
              onTick:(void(^)(int current, int total))onTick
              onFail:(void(^)(NSString *message))onFail
               onEnd:(void(^)(void))onEnd
             onScore:(void(^)(NSString *scoreJson))onScore;

// 초기화 및 평가 메서드
- (BOOL)initializeWithSentence:(NSString *)sentence 
          audioPollingInterval:(float)audioPollingInterval 
         minTimeBetweenEvals:(float)minTimeBetweenEvals;
- (BOOL)startEvaluationWithAudioFilePath:(NSString *)audioFilePath;
- (void)stopEvaluation;
- (void)reset;
- (NSString *)getResults;
- (NSString *)evaluateSpeech:(NSString *)sentence audioFilePath:(NSString *)audioFilePath;

@end