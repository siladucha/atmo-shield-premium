import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/measurement_mode.dart';
import '../models/measurement_result.dart';
import '../models/quality_level.dart';
import 'camera_service.dart';
import 'signal_processor.dart';
import 'quality_validator.dart';

enum MeasurementState {
  idle,
  initializing,
  capturing,
  processing,
  complete,
  error,
}

class MeasurementOrchestrator extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  final SignalProcessor _signalProcessor = SignalProcessor();
  final QualityValidator _qualityValidator = QualityValidator();

  MeasurementState _state = MeasurementState.idle;
  MeasurementMode? _currentMode;
  
  List<double> _intensityValues = [];
  QualityLevel _currentQuality = QualityLevel.poor;
  String _qualityMessage = 'Initializing...';
  int _elapsedSeconds = 0;
  Timer? _measurementTimer;
  Timer? _qualityTimer;
  StreamSubscription? _intensitySubscription;
  
  // Cached result to avoid reprocessing
  MeasurementResult? _cachedResult;

  // Getters
  MeasurementState get state => _state;
  MeasurementMode? get currentMode => _currentMode;
  QualityLevel get currentQuality => _currentQuality;
  String get qualityMessage => _qualityMessage;
  int get elapsedSeconds => _elapsedSeconds;
  int get totalSeconds => _currentMode?.duration ?? 0;
  double get progress => totalSeconds > 0 ? _elapsedSeconds / totalSeconds : 0;
  List<double> get recentSignal {
    // Return last 10 seconds of signal for waveform display
    final samplesPerSecond = 10; // Approximate
    final samplesToShow = 10 * samplesPerSecond;
    if (_intensityValues.length <= samplesToShow) {
      return _intensityValues;
    }
    return _intensityValues.sublist(_intensityValues.length - samplesToShow);
  }

  CameraService get cameraService => _cameraService;

  Future<void> startMeasurement(MeasurementMode mode) async {
    try {
      _setState(MeasurementState.initializing);
      _currentMode = mode;
      _intensityValues.clear();
      _elapsedSeconds = 0;
      _qualityValidator.reset();
      _cachedResult = null; // Clear cached result

      // Initialize camera
      await _cameraService.initialize(mode);

      // Start capturing
      _setState(MeasurementState.capturing);

      // Subscribe to intensity stream
      _intensitySubscription = _cameraService.intensityStream.listen(
        _onIntensityData,
        onError: (error) {
          debugPrint('Intensity stream error: $error');
          _handleError('Camera stream error');
        },
      );

      // Start measurement timer
      _measurementTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onTimerTick,
      );

      // Start quality assessment timer
      _qualityTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onQualityCheck,
      );

      notifyListeners();
    } catch (e) {
      _handleError('Failed to start measurement: $e');
    }
  }

  void _onIntensityData(Map<String, dynamic> data) {
    final double meanGreen = data['meanGreen'] as double;
    _intensityValues.add(meanGreen);
    
    // Store latest data for quality check
    _latestIntensityData = data;
    
    notifyListeners();
  }

  Map<String, dynamic>? _latestIntensityData;

  void _onTimerTick(Timer timer) {
    _elapsedSeconds++;
    
    if (_elapsedSeconds >= totalSeconds) {
      _completeMeasurement();
    }
    
    notifyListeners();
  }

  void _onQualityCheck(Timer timer) {
    if (_intensityValues.isEmpty || _latestIntensityData == null) return;

    // Get recent values for quality assessment
    final recentCount = min(_intensityValues.length, 10);
    final recentValues = _intensityValues.sublist(
      _intensityValues.length - recentCount,
    );

    final double meanBrightness = recentValues.reduce((a, b) => a + b) / recentValues.length;
    
    // Use variance from camera data (calculated from full ROI pixels)
    // This is more accurate than variance of 10 mean values
    final double cameraVariance = _latestIntensityData!['variance'] as double? ?? 0.0;

    // Get color channels from latest data
    final double? meanRed = _latestIntensityData!['meanRed'] as double?;
    final double? meanBlue = _latestIntensityData!['meanBlue'] as double?;

    // Log quality metrics for debugging
    if (_elapsedSeconds % 5 == 0) {
      debugPrint('Quality check: brightness=${meanBrightness.toStringAsFixed(1)}, variance=${cameraVariance.toStringAsFixed(2)}, R=${meanRed?.toStringAsFixed(1)}, G=${meanBrightness.toStringAsFixed(1)}, B=${meanBlue?.toStringAsFixed(1)}');
    }

    // Assess quality with color information
    _currentQuality = _qualityValidator.assessQuality(
      meanBrightness,
      cameraVariance,
      redMean: meanRed,
      blueMean: meanBlue,
    );
    _qualityMessage = _qualityValidator.getQualityMessage(
      _currentQuality,
      cameraVariance,
      meanBrightness,
    );
    
    notifyListeners();
  }

  Future<void> _completeMeasurement() async {
    // Stop timers and stream
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    await _intensitySubscription?.cancel();
    
    // Dispose camera immediately to avoid multiple dispose calls
    _cameraService.dispose();

    _setState(MeasurementState.processing);

    try {
      // Calculate actual sampling rate from collected data
      final samplingRate = _intensityValues.length ~/ totalSeconds;
      debugPrint('Processing ${_intensityValues.length} samples over $totalSeconds seconds ($samplingRate FPS)');
      
      // Process signal (always calculate HRV, even for Quick mode)
      final result = _signalProcessor.processMeasurement(
        _intensityValues,
        samplingRate,
        true, // Always calculate HRV
      );

      if (result['success'] == true) {
        // Measurement successful - cache the result
        _cachedResult = MeasurementResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          mode: _currentMode!,
          bpm: result['bpm'] as int,
          rmssd: result['rmssd'] as double?,
          quality: _currentQuality,
        );
        debugPrint('Measurement complete: BPM=${result['bpm']}, RMSSD=${result['rmssd']}');
        _setState(MeasurementState.complete);
      } else {
        // Processing failed, but don't call _handleError (camera already disposed)
        debugPrint('Processing failed: ${result['error']}');
        _cachedResult = null;
        _setState(MeasurementState.error);
      }
    } catch (e) {
      debugPrint('Processing error: $e');
      _cachedResult = null;
      _setState(MeasurementState.error);
    }
  }

  MeasurementResult? getResult() {
    // Return cached result (already processed in _completeMeasurement)
    return _cachedResult;
  }

  void cancelMeasurement() {
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    _intensitySubscription?.cancel();
    _cameraService.dispose();
    _setState(MeasurementState.idle);
  }

  void _handleError(String message) {
    debugPrint('Measurement error: $message');
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    _intensitySubscription?.cancel();
    _cameraService.dispose();
    _setState(MeasurementState.error);
  }

  void _setState(MeasurementState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    _intensitySubscription?.cancel();
    // Safe to call dispose - it checks if camera is initialized
    _cameraService.dispose();
    super.dispose();
  }

  int min(int a, int b) => a < b ? a : b;
}
