import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_gop/flutter_gop.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pronunciation Evaluator Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PronunciationDemo(),
    );
  }
}

class PronunciationDemo extends StatefulWidget {
  const PronunciationDemo({super.key});

  @override
  State<PronunciationDemo> createState() => _PronunciationDemoState();
}

class _PronunciationDemoState extends State<PronunciationDemo> {
  String _status = 'Ready';
  String _result = '';
  bool _isEvaluating = false;
  final TextEditingController _textController = TextEditingController(
    text: 'Hello world',
  );
  String _selectedLanguage = 'en';

  // Add adapter selection state
  bool _useSpeechSuper = false;
  bool _useOnDevice = false;
  bool _useOsStt = false;

  // SpeechSuper configuration
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiSecretController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  bool _showSpeechSuperConfig = false;

  @override
  void initState() {
    super.initState();
    _setupEvaluationStream();
    _loadSpeechSuperConfig();
  }

  Future<void> _loadSpeechSuperConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('speech_super_api_key') ?? '';
      _apiSecretController.text =
          prefs.getString('speech_super_api_secret') ?? '';
      _userIdController.text = prefs.getString('speech_super_user_id') ?? '';
    });
  }

  Future<void> _saveSpeechSuperConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('speech_super_api_key', _apiKeyController.text);
    await prefs.setString('speech_super_api_secret', _apiSecretController.text);
    await prefs.setString('speech_super_user_id', _userIdController.text);
  }

  void _setupEvaluationStream() {
    PronunciationEvaluator.evaluationStream.listen((data) {
      if (data != null) {
        setState(() {
          _result = const JsonEncoder.withIndent('  ').convert(data);
        });
      }
    });
  }

  Future<void> _startEvaluation() async {
    if (_isEvaluating) return;

    // Validate adapter selection
    if (!_useSpeechSuper && !_useOnDevice && !_useOsStt) {
      setState(() {
        _status = 'Error: Please select at least one adapter';
      });
      return;
    }

    // Validate SpeechSuper configuration if selected
    if (_useSpeechSuper) {
      if (_apiKeyController.text.isEmpty ||
          _apiSecretController.text.isEmpty ||
          _userIdController.text.isEmpty) {
        setState(() {
          _status = 'Error: Please configure SpeechSuper API credentials';
        });
        return;
      }
      await _saveSpeechSuperConfig();
    }

    setState(() {
      _isEvaluating = true;
      _status = 'Evaluating...';
      _result = '';
    });

    try {
      final adapterConfigs = <String, dynamic>{};

      if (_useOnDevice) {
        adapterConfigs['on_device'] = null;
      }

      if (_useSpeechSuper) {
        adapterConfigs['speech_super'] = {
          'language': _selectedLanguage,
          'model': 'sent.eval',
          'apiKey': _apiKeyController.text,
          'apiSecret': _apiSecretController.text,
          'userId': _userIdController.text,
        };
      }

      if (_useOsStt) {
        adapterConfigs['os_stt'] = {
          'language': _selectedLanguage,
          'model': 'default',
          'apiKey': 'YOUR_API_KEY', // Replace with actual API key
          'apiSecret': 'YOUR_API_SECRET', // Replace with actual API secret
        };
      }

      await PronunciationEvaluator.startEvaluation(
        _textController.text,
        _selectedLanguage,
        adapters: adapterConfigs,
      );
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isEvaluating = false;
      });
    }
  }

  Future<void> _stopEvaluation() async {
    if (!_isEvaluating) return;

    try {
      await PronunciationEvaluator.stopEvaluation();
      setState(() {
        _isEvaluating = false;
        _status = 'Ready';
      });
    } catch (e) {
      setState(() {
        _status = 'Error stopping: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pronunciation Evaluator')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Text to evaluate',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: _selectedLanguage,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ko', child: Text('Korean')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Add adapter selection checkboxes
              const Text(
                'Select Adapters:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('On Device'),
                subtitle: const Text(
                  'Uses device\'s built-in speech recognition',
                ),
                value: _useOnDevice,
                onChanged: (bool? value) {
                  setState(() {
                    _useOnDevice = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Speech Super'),
                subtitle: const Text(
                  'Uses Speech Super API (requires API key)',
                ),
                value: _useSpeechSuper,
                onChanged: (bool? value) {
                  setState(() {
                    _useSpeechSuper = value ?? false;
                    if (value == true) {
                      _showSpeechSuperConfig = true;
                    }
                  });
                },
              ),
              if (_showSpeechSuperConfig) ...[
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiSecretController,
                  decoration: const InputDecoration(
                    labelText: 'API Secret',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showSpeechSuperConfig = false;
                    });
                  },
                  child: const Text('Hide Configuration'),
                ),
              ],
              CheckboxListTile(
                title: const Text('OS STT'),
                subtitle: const Text(
                  'Uses OS Speech-to-Text service (requires API key)',
                ),
                value: _useOsStt,
                onChanged: (bool? value) {
                  setState(() {
                    _useOsStt = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isEvaluating ? _stopEvaluation : _startEvaluation,
                child: Text(
                  _isEvaluating ? 'Stop Evaluation' : 'Start Evaluation',
                ),
              ),
              const SizedBox(height: 16),
              Text('Status: $_status'),
              const SizedBox(height: 16),
              Container(
                height: 200, // Fixed height instead of Expanded
                child: SingleChildScrollView(child: Text(_result)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _userIdController.dispose();
    super.dispose();
  }
}
