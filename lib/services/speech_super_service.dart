import 'dart:async';
import 'package:flutter_plugin_speechsuper/index.dart';

class SpeechService {
  late final String _appKey;
  late final String _secretKey;
  final String _userId;
  final FlutterPluginSpeechsuper _speechsuperPlugin =
      FlutterPluginSpeechsuper();
  late final KYEngineSetting _kyEngineSetting;
  bool _isPlaying = false;
  OnRecordListener? _onRecordListener;
  Function(String)? log;

  SpeechService({
    required String userId,
    required String appKey,
    required String secretKey,
    Function(String)? log,
  }) : _userId = userId {
    _appKey = appKey;
    _secretKey = secretKey;

    if (_appKey.isEmpty || _secretKey.isEmpty) {
      throw Exception('Speech API keys are not properly configured');
    }

    log?.call(
      'SpeechService initialized with appKey: $_appKey, secretKey: $_secretKey, userId: $_userId',
    );
  }

  Future<void> initialize({OnInitEngineListener? onInitEngineListener}) async {
    final completer = Completer<void>();
    try {
      final engineStatus = await _speechsuperPlugin.getEngineStatus();
      if (engineStatus == KYEngineStatus.INITIALIZED) {
        log?.call('Engine already initialized, skipping initialization');
        completer.complete();
        return completer.future;
      }

      log?.call('Creating engine settings with native engine type');
      _kyEngineSetting = KYEngineSetting()..engineType = "native";

      log?.call('Initializing speech engine with appKey: $_appKey');

      await _speechsuperPlugin.initEngine(
        _appKey,
        _secretKey,
        _userId,
        _kyEngineSetting,
        OnInitEngineListener(
          onInitEngineFailed: () {
            log?.call('Engine initialization failed');
            onInitEngineListener?.onInitEngineFailed?.call();
            completer.completeError('Engine initialization failed');
          },
          onInitEngineSuccess: () {
            log?.call('Engine initialization succeeded');
            onInitEngineListener?.onInitEngineSuccess?.call();
            completer.complete();
          },
          onStartInitEngine: () {
            log?.call('Engine initialization started');
            onInitEngineListener?.onStartInitEngine?.call();
          },
        ),
      );
      return completer.future;
    } catch (e) {
      log?.call('Engine initialization failed: $e');
      completer.completeError('Engine initialization failed: $e');
      rethrow;
    }
  }

  Future<void> destroy() async {
    final engineStatus = await _speechsuperPlugin.getEngineStatus();
    if (engineStatus == KYEngineStatus.UNINITIALIZED) {
      log?.call('Engine not initialized, skipping destroy');
      return;
    }
    log?.call('Destroying speech engine');
    await _speechsuperPlugin.dispose();
    log?.call('Speech engine disposed');
    _isPlaying = false;
    log?.call('Speech engine destroyed');
  }

  Future<void> start({
    required String coreType,
    required String refText,
    required Function() onStart,
    required Function() onRecordEnd,
    required Function(String) onScore,
    required Function(String) onStartRecordFail,
  }) async {
    final completer = Completer<void>();
    final engineStatus = await _speechsuperPlugin.getEngineStatus();
    if (engineStatus == KYEngineStatus.UNINITIALIZED) {
      completer.completeError(Exception('Engine not initialized'));
      throw Exception('Engine not initialized');
    }
    _onRecordListener = OnRecordListener(
      onStart: () {
        log?.call('start record===>');
        onStart();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onTick: (num var1, num var2) {
        // debugPrint('tick===> var1:$var1, var2:$var2');
      },
      onStartRecordFail: (String res) {
        log?.call('start record failed：$res');
        if (res.contains('startEngineTest fail, wait last record end')) {
          stop().then((_) {
            log?.call('start record again');
            start(
                  coreType: coreType,
                  refText: refText,
                  onStart: onStart,
                  onRecordEnd: onRecordEnd,
                  onScore: onScore,
                  onStartRecordFail: onStartRecordFail,
                )
                .then((_) {
                  if (!completer.isCompleted) {
                    completer.complete();
                  }
                })
                .catchError((e) {
                  if (!completer.isCompleted) {
                    completer.completeError(e);
                  }
                });
          });
        } else {
          onStartRecordFail(res);
          if (!completer.isCompleted) {
            completer.completeError('Start record failed: $res');
          }
        }
      },
      onRecording: (int vadStatus, int soundIntensity) {
        // debugPrint('vad_status:$vadStatus, sound_intensity:$soundIntensity');
      },
      onRecordEnd: () {
        log?.call('stop record===>');
        onRecordEnd();
      },
      onScore: (String res) {
        // debugPrint('show result===>');
        onScore(res);
      },
    );

    final kyRecordSetting =
        KYRecordSetting()
          ..request = {
            'refText': refText,
            'coreType': coreType,
            'realtime_feedback': 1,
          }
          ..audioType = KYAudioType.mp3;

    try {
      final result = await _speechsuperPlugin.start(
        kyRecordSetting,
        _onRecordListener!,
      );
      log?.call('start result: $result');
      // We don't complete here because we want to wait for onStart or onStartRecordFail
    } catch (e) {
      log?.call('start error: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }

    return completer.future;
  }

  Future<void> stop() async {
    try {
      await _speechsuperPlugin.stop();
      log?.call("stop success");
    } catch (e) {
      log?.call('stop error: $e');
      rethrow;
    }
  }

  Future<void> cancel() async {
    try {
      await _speechsuperPlugin.cancel();
      log?.call('cancel success');
    } catch (e) {
      log?.call('cancel error: $e');
      rethrow;
    }
  }

  Future<void> playback({
    required Function() onStart,
    required Function() onEnd,
    required Function(String) onStartFail,
  }) async {
    if (_isPlaying) {
      throw Exception('Already playing');
    }
    final onPlayListener = OnPlayListener(
      onStart: () {
        log?.call('start replay===>');
        _isPlaying = true;
        onStart();
      },
      onStartFail: (String str) {
        log?.call('replay failed===>');
        _isPlaying = false;
        onStartFail(str);
      },
      onEnd: () {
        log?.call('replay end===>');
        _isPlaying = false;
        onEnd();
      },
    );

    try {
      await _speechsuperPlugin.playback(onPlayListener);
      log?.call('playback success');
    } catch (e) {
      log?.call('playback error: $e');
      _isPlaying = false;
      rethrow;
    }
  }
}
