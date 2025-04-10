import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:plugin/pronunciation_evaluator.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _setupEvaluationStream();
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

    setState(() {
      _isEvaluating = true;
      _status = 'Evaluating...';
      _result = '';
    });

    try {
      await PronunciationEvaluator.startEvaluation(
        _textController.text,
        _selectedLanguage,
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            ElevatedButton(
              onPressed: _isEvaluating ? _stopEvaluation : _startEvaluation,
              child: Text(
                _isEvaluating ? 'Stop Evaluation' : 'Start Evaluation',
              ),
            ),
            const SizedBox(height: 16),
            Text('Status: $_status'),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: Text(_result))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
