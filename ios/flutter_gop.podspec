Pod::Spec.new do |s|
  s.name             = 'flutter_gop'
  s.version          = '0.0.1'
  s.summary          = '한국어 발음 평가 플러그인'
  s.description      = <<-DESC
Flutter용 한국어 발음 평가 플러그인으로, C++ 기반 음성 인식 엔진을 사용합니다.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  
  # 소스 파일 및 헤더 설정
  s.source_files = 'Classes/**/*', 'realtime_engine_c.h'
  s.public_header_files = 'Classes/**/*.h'
  
  # 라이브러리 파일 보존 경로
  s.preserve_paths = 'librealtime_engine_ko_c.a', 'realtime_engine_c.h'
  
  # 의존성
  s.dependency 'Flutter'
  s.dependency 'onnxruntime-objc', '~> 1.15.1'
  s.platform = :ios, '12.0'

  # 네이티브 라이브러리 설정
  s.vendored_libraries = 'librealtime_engine_ko_c.a', 'SpeechSuperEngine/libskegn.a'
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'CoreAudio', 'CoreFoundation'
  s.libraries = 'c++', 'z'
  
  # 모델 파일을 리소스 번들로 포함
  s.resource_bundles = {
    'flutter_gop_models' => ['../assets/wav2vec2_ctc_dynamic.onnx', '../assets/tokenizer.json']
  }

  # 빌드 설정
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC -lc++ -force_load "$(PODS_TARGET_SRCROOT)/librealtime_engine_ko_c.a" -force_load "$(PODS_TARGET_SRCROOT)/SpeechSuperEngine/libskegn.a"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT) $(PODS_TARGET_SRCROOT)/Classes $(PODS_TARGET_SRCROOT)/SpeechSuperEngine',
    'LIBRARY_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT) $(PODS_TARGET_SRCROOT)/SpeechSuperEngine'
  }
  s.swift_version = '5.0'
end 