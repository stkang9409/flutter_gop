Pod::Spec.new do |s|
  s.name             = 'flutter_gop'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin.'
  s.description      = <<-DESC
A new Flutter plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'onnxruntime-objc', '~> 1.15.1'
  s.platform = :ios, '12.0'

  # SpeechSuper SDK 설정
  s.vendored_libraries = 'SpeechSuperEngine/libskegn.a'
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'CoreAudio', 'CoreFoundation'
  s.libraries = 'c++', 'z'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }
  s.swift_version = '5.0'
end 