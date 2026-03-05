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
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🚀 STARTING MEASUREMENT: ${mode.displayName} (${mode.duration}s)');
      debugPrint('═══════════════════════════════════════════════════════');
      
      _setState(MeasurementState.initializing);
      _currentMode = mode;
      _intensityValues.clear();
      _elapsedSeconds = 0;
      _qualityValidator.reset();
      _cachedResult = null; // Clear cached result

      // Initialize camera
      await _cameraService.initialize(mode);
      debugPrint('✅ Camera initialized');

      // Start capturing
      _setState(MeasurementState.capturing);
      debugPrint('📹 Starting capture...');

      // Subscribe to intensity stream
      _intensitySubscription = _cameraService.intensityStream.listen(
        _onIntensityData,
        onError: (error) {
          debugPrint('❌ Intensity stream error: $error');
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
      debugPrint('❌ Failed to start measurement: $e');
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
    
    // Log progress every 5 seconds
    if (_elapsedSeconds % 5 == 0) {
      debugPrint('⏱️  Progress: ${_elapsedSeconds}s / ${totalSeconds}s (${_intensityValues.length} samples collected)');
    }
    
    if (_elapsedSeconds >= totalSeconds) {
      debugPrint('⏱️  Time complete! Starting processing...');
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

    // Check if flash turned off (brightness dropped significantly)
    if (meanBrightness < 60 && _elapsedSeconds > 5) {
      debugPrint('⚠️  Flash may have turned off (brightness: ${meanBrightness.toStringAsFixed(1)}), attempting to re-enable...');
      _cameraService.ensureFlashOn();
    }

    // Log quality metrics every 10 seconds
    if (_elapsedSeconds % 10 == 0) {
      debugPrint('📊 Quality @${_elapsedSeconds}s: brightness=${meanBrightness.toStringAsFixed(1)}, variance=${cameraVariance.toStringAsFixed(2)}, R=${meanRed?.toStringAsFixed(1)}, G=${meanBrightness.toStringAsFixed(1)}, B=${meanBlue?.toStringAsFixed(1)}');
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
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('🔄 PROCESSING MEASUREMENT');
    debugPrint('═══════════════════════════════════════════════════════');
    
    // Stop timers and stream
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    await _intensitySubscription?.cancel();
    
    // Dispose camera immediately to avoid multiple dispose calls
    await _cameraService.dispose();

    _setState(MeasurementState.processing);

    try {
      // Calculate actual sampling rate from collected data
      final samplingRate = _intensityValues.length ~/ totalSeconds;
      debugPrint('📊 Collected ${_intensityValues.length} samples over $totalSeconds seconds');
      debugPrint('📊 Actual sampling rate: $samplingRate FPS');
      debugPrint('📊 Final quality: ${_currentQuality.displayName}');
      
      // Process signal (always calculate HRV, even for Quick mode)
      final result = _signalProcessor.processMeasurement(
        _intensityValues,
        samplingRate,
        true, // Always calculate HRV
        totalSeconds: totalSeconds,
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
          peakCount: result['peakCount'] as int,
          sampleCount: _intensityValues.length,
          samplingRate: samplingRate.toDouble(),
          signalMean: result['signalMean'] as double,
          signalVariance: result['signalVariance'] as double,
          signalAmplitude: result['signalAmplitude'] as double,
        );
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('✅ MEASUREMENT COMPLETE');
        debugPrint('   BPM: ${result['bpm']}');
        debugPrint('   RMSSD: ${result['rmssd']?.toStringAsFixed(1) ?? "N/A"} ms');
        debugPrint('   Peaks: ${result['peakCount']}');
        debugPrint('   Quality: ${_currentQuality.displayName}');
        debugPrint('═══════════════════════════════════════════════════════');
        _setState(MeasurementState.complete);
      } else {
        // Processing failed, but don't call _handleError (camera already disposed)
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('❌ PROCESSING FAILED: ${result['error']}');
        debugPrint('═══════════════════════════════════════════════════════');
        _cachedResult = null;
        _setState(MeasurementState.error);
      }
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('❌ PROCESSING ERROR: $e');
      debugPrint('═══════════════════════════════════════════════════════');
      _cachedResult = null;
      _setState(MeasurementState.error);
    }
  }

  MeasurementResult? getResult() {
    // Return cached result (already processed in _completeMeasurement)
    return _cachedResult;
  }

  Future<void> cancelMeasurement() async {
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    await _intensitySubscription?.cancel();
    _intensitySubscription = null;
    await _cameraService.dispose();
    _setState(MeasurementState.idle);
  }

  Future<void> _handleError(String message) async {
    debugPrint('Error: $message');
    _measurementTimer?.cancel();
    _qualityTimer?.cancel();
    await _intensitySubscription?.cancel();
    _intensitySubscription = null;
    await _cameraService.dispose();
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
    _intensitySubscription = null;
    // Safe to call dispose - it has guard flag
    _cameraService.dispose();
    super.dispose();
  }

  int min(int a, int b) => a < b ? a : b;
}
