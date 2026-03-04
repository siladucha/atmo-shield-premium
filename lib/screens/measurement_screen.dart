import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../models/measurement_mode.dart';
import '../models/quality_level.dart';
import '../services/measurement_orchestrator.dart';
import 'results_screen_hrv.dart';
import 'dart:math' as math;

class MeasurementScreen extends StatefulWidget {
  final MeasurementMode mode;

  const MeasurementScreen({super.key, required this.mode});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen>
    with SingleTickerProviderStateMixin {
  late MeasurementOrchestrator _orchestrator;
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _orchestrator = MeasurementOrchestrator();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // 6 breaths/min
    )..repeat();

    // Start measurement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMeasurement();
    });
  }

  Future<void> _startMeasurement() async {
    try {
      await _orchestrator.startMeasurement(widget.mode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _onCancel() {
    _orchestrator.cancelMeasurement();
    Navigator.of(context).pop();
  }

  void _onComplete() {
    final result = _orchestrator.getResult();
    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreenHRV(result: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _orchestrator,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Consumer<MeasurementOrchestrator>(
            builder: (context, orchestrator, child) {
              if (orchestrator.state == MeasurementState.complete) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onComplete();
                });
              }

              return Column(
                children: [
                  // Header with cancel button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _onCancel,
                        ),
                        const Spacer(),
                        Text(
                          widget.mode.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // Camera preview
                  Expanded(
                    flex: 3,
                    child: _buildCameraPreview(orchestrator),
                  ),

                  // Quality indicator
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildQualityIndicator(orchestrator),
                  ),

                  // Breathing metronome (Accurate Mode only)
                  if (widget.mode == MeasurementMode.accurate)
                    Expanded(
                      flex: 2,
                      child: _buildBreathingMetronome(),
                    ),

                  // Waveform
                  Expanded(
                    flex: 2,
                    child: _buildWaveform(orchestrator),
                  ),

                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildProgress(orchestrator),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview(MeasurementOrchestrator orchestrator) {
    final controller = orchestrator.cameraService.controller;
    
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        // ROI overlay
        Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.fingerprint, size: 60, color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityIndicator(MeasurementOrchestrator orchestrator) {
    Color qualityColor;
    switch (orchestrator.currentQuality) {
      case QualityLevel.poor:
        qualityColor = Colors.red;
        break;
      case QualityLevel.fair:
        qualityColor = Colors.orange;
        break;
      case QualityLevel.good:
        qualityColor = Colors.green;
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Signal Quality: ',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: orchestrator.currentQuality == QualityLevel.good
                    ? 1.0
                    : orchestrator.currentQuality == QualityLevel.fair
                        ? 0.6
                        : 0.3,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation(qualityColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              orchestrator.currentQuality.displayName,
              style: TextStyle(
                color: qualityColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          orchestrator.qualityMessage,
          style: TextStyle(color: qualityColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildBreathingMetronome() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        final value = _breathingController.value;
        final isInhale = value < 0.4; // 4s inhale
        final scale = isInhale
            ? 0.5 + (value / 0.4) * 0.5
            : 1.0 - ((value - 0.4) / 0.6) * 0.5;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isInhale ? 'Breathe In' : 'Breathe Out',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.3),
                    border: Border.all(color: Colors.blue, width: 3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveform(MeasurementOrchestrator orchestrator) {
    final signal = orchestrator.recentSignal;
    
    if (signal.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for signal...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return CustomPaint(
      painter: WaveformPainter(signal),
      child: Container(),
    );
  }

  Widget _buildProgress(MeasurementOrchestrator orchestrator) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: orchestrator.progress,
          backgroundColor: Colors.grey[800],
          valueColor: const AlwaysStoppedAnimation(Colors.blue),
          minHeight: 8,
        ),
        const SizedBox(height: 8),
        Text(
          '${orchestrator.elapsedSeconds}s / ${orchestrator.totalSeconds}s',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> signal;

  WaveformPainter(this.signal);

  @override
  void paint(Canvas canvas, Size size) {
    if (signal.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Normalize signal
    final minVal = signal.reduce(math.min);
    final maxVal = signal.reduce(math.max);
    final range = maxVal - minVal;
    
    if (range == 0) return;

    for (int i = 0; i < signal.length; i++) {
      final x = (i / signal.length) * size.width;
      final normalized = (signal[i] - minVal) / range;
      final y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) => true;
}
