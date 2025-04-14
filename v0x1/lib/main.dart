import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Wave App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechInitialized = false;
  String _text = "Tap the mic to speak";

  late AnimationController _controller;
  final List<Wave> _waves = [];
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _controller.repeat(reverse: true);

    _setupSpeech();
  }

  Future<void> _setupSpeech() async {
    await _requestPermission();
    if (await Permission.microphone.isGranted) {
      await _initSpeech();
    }
  }

  Future<void> _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech status: $status')),
          );
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
            _stopWaveAnimation();
          }
        }
      },
      onError: (errorNotification) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech error: $errorNotification'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isListening = false;
          });
          _stopWaveAnimation();
        }
      },
    );
    if (mounted && !_speechInitialized) {
      setState(() {
        _text = "Speech initialization failed. Check permissions.";
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (mounted && status != PermissionStatus.granted) {
      setState(() {
        _text = "Microphone permission denied";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for this app'),
        ),
      );
    }
  }

  void _startWaveAnimation() {
    _waveTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (mounted) {
        setState(() {
          _waves.add(Wave(radius: 50.0, opacity: 1.0));
        });
      }
    });
  }

  void _stopWaveAnimation() {
    _waveTimer?.cancel();
    if (mounted) {
      setState(() {
        _waves.clear();
      });
    }
  }

  void _listen() async {
    if (!await Permission.microphone.isGranted) {
      if (mounted) {
        setState(() {
          _text = "Microphone permission required";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      await _requestPermission();
      return;
    }

    if (!_speechInitialized) {
      await _initSpeech();
      if (!_speechInitialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech not initialized')),
          );
        }
        return;
      }
    }

    if (!_isListening) {
      setState(() {
        _isListening = true;
        _text = "Listening...";
      });
      _startWaveAnimation();
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _text = result.recognizedWords.isNotEmpty
                  ? result.recognizedWords
                  : "No words recognized";
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
        ),
      );
    } else {
      setState(() {
        _isListening = false;
        _text = _text.isEmpty ? "Tap the mic to speak" : _text;
      });
      _stopWaveAnimation();
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _waveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _text,
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 50),
            Stack(
              alignment: Alignment.center,
              children: [
                for (var wave in _waves)
                  CustomPaint(
                    painter: WavePainter(
                      wave: wave,
                      controller: _controller,
                    ),
                    child: const SizedBox(
                      width: 300,
                      height: 300,
                    ),
                  ),
                GestureDetector(
                  onTap: _listen,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.blue.shade600 : Colors.blue.shade400,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isListening
                              ? Colors.blue.withOpacity(0.6)
                              : Colors.blue.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              _isListening ? "Tap to stop" : "Tap to speak",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Wave {
  double radius;
  double opacity;

  Wave({required this.radius, required this.opacity});

  void update() {
    radius += 4;
    opacity -= 0.03;
    if (opacity < 0) opacity = 0;
  }
}

class WavePainter extends CustomPainter {
  final Wave wave;
  final AnimationController controller;

  WavePainter({required this.wave, required this.controller});

  @override
  void paint(Canvas canvas, Size size) {
    wave.update();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = RadialGradient(
        colors: [
          Colors.blue.withOpacity(wave.opacity),
          Colors.blue.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: wave.radius,
      ));

    final variation = 5 * sin(controller.value * 2 * pi);
    final path = Path();
    for (double i = 0; i < 360; i += 1) {
      final radians = i * pi / 180;
      final radiusVariation = wave.radius + variation * sin(radians * 8);
      final x = size.width / 2 + radiusVariation * cos(radians);
      final y = size.height / 2 + radiusVariation * sin(radians);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}