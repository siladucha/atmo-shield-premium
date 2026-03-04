import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_ppg/flutter_ppg.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.red, useMaterial3: true),
      home: const PPGExamplePage(),
    );
  }
}

class PPGExamplePage extends StatefulWidget {
  const PPGExamplePage({super.key});

  @override
  State<PPGExamplePage> createState() => _PPGExamplePageState();
}

class _PPGExamplePageState extends State<PPGExamplePage> {
  CameraController? _controller;
  final _ppgService = FlutterPPGService();

  // State for UI
  PPGSignal? _currentSignal;
  String _status = 'Initializing...';
  bool _isScanning = false;
  bool _isTransitioning = false;
  int _timeLeft = 30;
  Timer? _timer;
  Timer? _uiUpdateTimer;
  DateTime? _lastLogTime;
  static const Duration _logInterval = Duration(seconds: 1);
  final bool _enableConsoleLog = true;
  static const int _bpmWindowSize = 12;  // Увеличено с 8 до 12
  static const int _statsWindowSize = 60;
  int _secondsRunning = 0;  // Для адаптивной валидации
  
  // Финальные результаты измерения
  int? _finalBPM;
  double? _finalHRV;
  DateTime? _measurementTime;
  
  // Валидация измерения
  static const int _minValidRRCount = 20;  // Минимум 20 RR для статистически значимого результата
  static const double _minHRV = 15.0;      // Минимальная HRV (защита от артефактов)
  static const double _maxHRV = 200.0;     // Максимальная HRV (защита от шума)
  static const int _measurementDuration = 60; // Длительность измерения (секунды)

  // Data buffers for visualization
  final List<double> _rawHistory = [];
  final List<double> _filteredHistory = [];
  final List<double> _rrHistory = [];
  final List<double> _hrvHistory = []; // История HRV (SDRR)
  List<int> _currentPeakIndices = [];
  static const int _historyLimit = 150;

  PPGSignal? _pendingSignal;
  StreamController<CameraImage>? _imageStreamController;
  StreamSubscription<PPGSignal>? _ppgSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Dispose старого контроллера если есть
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = 'No cameras found.');
        return;
      }

      // Логируем все доступные камеры для отладки
      for (var i = 0; i < cameras.length; i++) {
        debugPrint('📷 Camera $i: ${cameras[i].name}, lens: ${cameras[i].lensDirection}');
      }

      // Стратегия выбора камеры:
      // 1. Сначала ищем заднюю камеру с самой высокой позицией (на iPhone это основная)
      // 2. Если не нашли, берём любую заднюю
      // 3. В крайнем случае первую попавшуюся
      CameraDescription? selectedCamera;

      // Сначала ищем заднюю камеру с индексом 0 (на iPhone это основная с вспышкой)
      if (cameras.isNotEmpty && cameras[0].lensDirection == CameraLensDirection.back) {
        selectedCamera = cameras[0];
        debugPrint('✅ Выбрана камера с индексом 0: ${cameras[0].name}');
      } else {
        // Если нет, ищем любую заднюю камеру
        for (var camera in cameras) {
          if (camera.lensDirection == CameraLensDirection.back) {
            selectedCamera = camera;
            debugPrint('✅ Выбрана задняя камера: ${camera.name}');
            break;
          }
        }
      }

      // Если всё ещё не нашли, берём первую попавшуюся
      selectedCamera ??= cameras.first;
      if (selectedCamera.lensDirection != CameraLensDirection.back) {
        debugPrint('⚠️ Внимание: используется не задняя камера!');
      }

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,  // Изменено с low на medium для лучшего качества
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.yuv420    // Android лучше работает с yuv420
            : ImageFormatGroup.bgra8888, // iOS лучше с bgra8888
      );
      
      await _controller!.initialize();

      // Проверяем поддержку вспышки
      if (_controller != null && _controller!.value.isInitialized) {
        final hasFlash = _controller!.value.flashMode != null;
        debugPrint('💡 Вспышка поддерживается: $hasFlash');
        if (!hasFlash) {
          debugPrint('⚠️ Выбранная камера не поддерживает вспышку!');
        }
      }

      if (mounted) {
        setState(() => _status = 'Ready. Press Start to measure.');
      }
    } catch (e) {
      debugPrint('❌ Camera initialization error: $e');
      if (mounted) setState(() => _status = 'Camera error: $e');
      // Очищаем контроллер при ошибке
      _controller = null;
    }
  }

  void _toggleScanning() {
    if (_isTransitioning) return;
    if (_isScanning) {
      _stopProcessing();
    } else {
      // Очищаем предыдущие финальные результаты при новом измерении
      _finalBPM = null;
      _finalHRV = null;
      _measurementTime = null;
      
      // Haptic feedback при старте
      HapticFeedback.mediumImpact();
      
      _startProcessing();
    }
  }

  Future<void> _startProcessing() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTransitioning) return;
    _isTransitioning = true;

    setState(() {
      _isScanning = true;
      _timeLeft = _measurementDuration;  // 60 секунд для качественного измерения
      _secondsRunning = 0;
      _rawHistory.clear();
      _filteredHistory.clear();
      _rrHistory.clear();
      _hrvHistory.clear();
      _currentPeakIndices = [];
      _currentSignal = null;
      _pendingSignal = null;
      _status = 'Стабилизация сигнала... Держите палец плотно 5-8 сек';
    });

    try {
      await _controller!.setFlashMode(FlashMode.torch);
      debugPrint('✅ Flash enabled');
    } catch (e) {
      debugPrint('❌ Flash error: $e');
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isScanning) {
        setState(() {
          _timeLeft--;
          _secondsRunning++;
          
          // Обновляем статус в зависимости от времени
          if (_secondsRunning <= 5) {
            _status = 'Стабилизация сигнала... Держите палец плотно';
          } else if (_secondsRunning <= 10) {
            _status = 'Идёт измерение... Не двигайтесь';
          } else {
            _status = _currentSignal?.quality == SignalQuality.good
                ? 'Отличный сигнал - продолжаем'
                : 'Держите палец плотно';
          }
          
          // Авто-стоп при достижении минимума валидных данных
          if (_rrHistory.length >= _minValidRRCount && _secondsRunning >= 20) {
            debugPrint('✅ Достигнуто минимальное количество данных: ${_rrHistory.length} RR');
            _stopProcessing();
          }
        });
        if (_timeLeft <= 0) _stopProcessing();
      }
    });

    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _pendingSignal != null) _applyPendingSignal();
    });

    _imageStreamController = StreamController<CameraImage>();
    try {
      debugPrint('🎥 Starting image stream...');
      int imageCount = 0;
      await _controller!.startImageStream((image) {
        imageCount++;
        if (imageCount % 30 == 0) {
          debugPrint('📷 Camera: received $imageCount images, format: ${image.format.group}');
        }
        if (_imageStreamController != null && !_imageStreamController!.isClosed) {
          _imageStreamController!.add(image);
        }
      });
      debugPrint('✅ Image stream started');
    } catch (e) {
      debugPrint('❌ Image stream error: $e');
      _isTransitioning = false;
      await _stopProcessing();
      return;
    }

    debugPrint('🔄 Starting PPG processing...');
    int frameCount = 0;
    _ppgSubscription = _ppgService.processImageStream(_imageStreamController!.stream).listen(
      (signal) {
        frameCount++;
        
        // Детальное логирование каждого сигнала
        if (frameCount % 30 == 0) {
          debugPrint('🔥 Signal #$frameCount: '
              'quality=${signal.quality.name}, '
              'fps=${signal.frameRate.toStringAsFixed(1)}, '
              'stable=${signal.isFPSStable}, '
              'rrIntervals=${signal.rrIntervals.length}, '
              'sdrr=${signal.sdrr.toStringAsFixed(1)}, '
              'peaks=${signal.peakIndices.length}');
        }
        
        // КРИТИЧНО: логируем каждый RR интервал
        if (signal.rrIntervals.isNotEmpty) {
          debugPrint('🎯 RR INTERVALS RECEIVED: ${signal.rrIntervals.length} intervals: ${signal.rrIntervals.map((rr) => rr.toStringAsFixed(0)).join(", ")}');
        }
        
        _maybeLogSignal(signal);
        _pendingSignal = signal;
        _rawHistory.add(signal.rawIntensity);
        _filteredHistory.add(signal.filteredIntensity);
        if (_rawHistory.length > _historyLimit) _rawHistory.removeAt(0);
        if (_filteredHistory.length > _historyLimit) _filteredHistory.removeAt(0);
        _currentPeakIndices = signal.peakIndices;
        
        // Добавляем RR интервалы с фильтрацией выбросов
        final isValid = _isSignalValid(signal);
        
        if (isValid) {
          for (final rr in signal.rrIntervals) {
            // Жёсткий фильтр выбросов: нормальный пульс 40-180 bpm = 333-1500 ms
            // Используем более узкий диапазон: 450-1400 ms (43-133 bpm)
            if (rr > 450 && rr < 1400) {
              _rrHistory.add(rr);
              debugPrint('✅ Added RR: ${rr.toStringAsFixed(0)} ms, total: ${_rrHistory.length}');
            } else {
              debugPrint('❌ RR outlier rejected: ${rr.toStringAsFixed(0)} ms');
            }
          }
          
          // Ограничиваем историю 40 последними интервалами
          while (_rrHistory.length > 40) {
            _rrHistory.removeAt(0);
          }
          
          // Вычисляем и добавляем HRV в историю каждые несколько измерений
          if (_rrHistory.length >= 8 && frameCount % 10 == 0) {
            final hrv = _calculateCurrentHRV();
            if (hrv > 0) {
              _hrvHistory.add(hrv);
              if (_hrvHistory.length > 30) _hrvHistory.removeAt(0);
              debugPrint('📈 HRV calculated: ${hrv.toStringAsFixed(1)} ms');
            }
          }
        } else {
          // Если сигнал невалидный, логируем почему
          if (signal.rrIntervals.isNotEmpty) {
            debugPrint('⚠️ Skipping ${signal.rrIntervals.length} RR intervals - signal invalid: '
                'quality=${signal.quality.name}, '
                'isSDRRAcceptable=${signal.isSDRRAcceptable}, '
                'rejection=${(signal.rejectionRatio * 100).toStringAsFixed(0)}%, '
                'secondsRunning=$_secondsRunning');
          }
        }
      },
      onError: (error) {
        debugPrint('❌ PPG Stream Error: $error');
      },
      onDone: () {
        debugPrint('⚠️ PPG Stream Done');
      },
    );

    _isTransitioning = false;
    debugPrint('✅ Processing started');
  }

  void _maybeLogSignal(PPGSignal signal) {
    if (!_enableConsoleLog) return;
    final now = DateTime.now();
    if (_lastLogTime != null && now.difference(_lastLogTime!) < _logInterval) return;
    _lastLogTime = now;

    final meanRR = _meanRecentRR();
    final bpm = meanRR > 0 ? (60000 / meanRR).round() : 0;
    final isValid = _isSignalValid(signal);
    final validityReason = _validityReason(signal);
    final rawStats = _calcStats(_rawHistory);
    final filteredStats = _calcStats(_filteredHistory);

    debugPrint(
      '[flutter_ppg][example] '
      'fps=${signal.frameRate.toStringAsFixed(1)} '
      'stable=${signal.isFPSStable} '
      'quality=${signal.quality.name} '
      'snr=${signal.snr.toStringAsFixed(1)}dB '
      'bpm=${bpm == 0 ? "--" : bpm} '
      'sdrr=${signal.sdrr.toStringAsFixed(1)} '
      'rej=${(signal.rejectionRatio * 100).toStringAsFixed(0)}% '
      'drift=${signal.driftRate.toStringAsFixed(1)} '
      'valid=$isValid '
      'reason=${validityReason.isEmpty ? "-" : validityReason} '
      'raw=${signal.rawIntensity.toStringAsFixed(1)} '
      'rawMean=${rawStats.mean.toStringAsFixed(1)} '
      'rawRange=${rawStats.min.toStringAsFixed(1)}..${rawStats.max.toStringAsFixed(1)} '
      'filt=${signal.filteredIntensity.toStringAsFixed(2)} '
      'filtMean=${filteredStats.mean.toStringAsFixed(2)} '
      'filtRange=${filteredStats.min.toStringAsFixed(2)}..${filteredStats.max.toStringAsFixed(2)} '
      'peaks=${_currentPeakIndices.length} '
      'rrCount=${signal.rrIntervals.length} '
      'rrHistorySize=${_rrHistory.length}',
    );
    
    // КРИТИЧНО: если FPS нестабилен, RR интервалы не генерируются
    if (!signal.isFPSStable) {
      debugPrint('⚠️⚠️⚠️ FPS НЕСТАБИЛЕН! RR интервалы НЕ будут генерироваться пока FPS не стабилизируется!');
    }
  }

  double _meanRecentRR() {
    if (_rrHistory.length < 6) return 0.0;  // Минимум 6 RR для расчёта
    
    // Берём последние 12 RR интервалов
    final recent = _rrHistory.length > _bpmWindowSize 
        ? _rrHistory.sublist(_rrHistory.length - _bpmWindowSize)
        : _rrHistory;
    
    if (recent.length < 6) return 0.0;
    
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    
    // Диагностика
    debugPrint('📊 RR History: count=${recent.length}, mean=${mean.toStringAsFixed(1)} ms, last=${_rrHistory.last.toStringAsFixed(1)} ms');
    
    return mean;
  }

  bool _isSignalValid(PPGSignal signal) {
    // Адаптивная валидация в зависимости от времени измерения
    if (signal.quality == SignalQuality.poor) return false;
    
    // Первые 7 секунд - мягкие условия (стабилизация)
    if (_secondsRunning < 7) {
      return signal.isSDRRAcceptable || signal.snr > 0.5;
    }
    
    // После 7 секунд - проверяем только SDRR, игнорируем rejection ratio
    // Rejection ratio часто высокий даже при хорошем сигнале из-за движения крови
    return signal.isSDRRAcceptable;
  }

  String _validityReason(PPGSignal signal) {
    final reasons = <String>[];
    if (signal.quality == SignalQuality.poor) reasons.add('quality');
    if (!signal.isSDRRAcceptable) reasons.add('sdrr');
    // Не проверяем rejection - при легком касании он всегда высокий
    return reasons.join('+');
  }

  _Stats _calcStats(List<double> values) {
    if (values.isEmpty) return const _Stats(0.0, 0.0, 0.0);
    final start = values.length > _statsWindowSize ? values.length - _statsWindowSize : 0;
    double sum = 0.0;
    double minV = double.maxFinite;
    double maxV = -double.maxFinite;
    int count = 0;
    for (int i = start; i < values.length; i++) {
      final v = values[i];
      sum += v;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
      count++;
    }
    final mean = count == 0 ? 0.0 : sum / count;
    if (count == 0) return const _Stats(0.0, 0.0, 0.0);
    return _Stats(mean, minV, maxV);
  }

  void _applyPendingSignal() {
    if (_pendingSignal == null) return;
    final signal = _pendingSignal!;
    _pendingSignal = null;
    
    final isValid = _isSignalValid(signal);
    
    // Детальное логирование для отладки
    debugPrint('🔍 Signal validation: valid=$isValid, quality=${signal.quality.name}, '
        'isSDRRAcceptable=${signal.isSDRRAcceptable}, rejectionRatio=${signal.rejectionRatio.toStringAsFixed(2)}, '
        'sdrr=${signal.sdrr.toStringAsFixed(1)}, rrCount=${signal.rrIntervals.length}');
    
    // Очищаем историю RR если сигнал невалидный
    if (!isValid && _rrHistory.isNotEmpty) {
      debugPrint('⚠️ Clearing RR history due to invalid signal');
      _rrHistory.clear();
    }
    
    setState(() {
      _currentSignal = signal;
      // Более точные сообщения о качестве сигнала
      if (signal.quality == SignalQuality.good) {
        _status = 'Отличный сигнал! Продолжаем измерение...';
      } else if (signal.quality == SignalQuality.fair) {
        _status = 'Сигнал средний. Держите палец плотнее и не двигайтесь.';
      } else {
        _status = 'Слабый сигнал. Плотно прижмите палец к камере и вспышке.';
      }
    });
  }

  Future<void> _stopProcessing() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    debugPrint('🛑 Stopping processing...');

    _timer?.cancel();
    _uiUpdateTimer?.cancel();
    _timer = null;
    _uiUpdateTimer = null;

    await _ppgSubscription?.cancel();
    _ppgSubscription = null;

    await _imageStreamController?.close();
    _imageStreamController = null;

    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.stopImageStream();
        debugPrint('✅ Image stream stopped');
      } catch (e) {
        debugPrint('⚠️ Stop image stream error (may be already stopped): $e');
      }
      
      try {
        await _controller!.setFlashMode(FlashMode.off);
        debugPrint('✅ Flash disabled');
      } catch (e) {
        debugPrint('⚠️ Flash disable error: $e');
      }
    }

    // Сохраняем финальные результаты только если измерение валидно
    if (_isPhysiologicallyValid()) {
      final meanRR = _meanRecentRR();
      final calculatedHRV = _calculateCurrentHRV();
      
      _finalBPM = (60000 / meanRR).round();
      _finalHRV = calculatedHRV > 0 ? calculatedHRV : (_currentSignal?.sdrr ?? 0.0);
      _measurementTime = DateTime.now();
      
      // Haptic feedback при успешном завершении
      HapticFeedback.heavyImpact();
      
      debugPrint('✅ РЕЗУЛЬТАТЫ СОХРАНЕНЫ:');
      debugPrint('   BPM: $_finalBPM');
      debugPrint('   HRV: ${_finalHRV?.toStringAsFixed(1)} ms');
      debugPrint('   Время: $_measurementTime');
      debugPrint('   RR интервалов: ${_rrHistory.length}');
    } else {
      // Haptic feedback при ошибке
      HapticFeedback.vibrate();
      
      debugPrint('❌ Измерение не прошло валидацию - результаты не сохранены');
      debugPrint('   Рекомендация: держите палец плотнее и не двигайтесь');
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        if (_finalBPM != null) {
          _status = 'Измерение завершено. Готово к сохранению в Health.';
        } else {
          _status = 'Недостаточно данных. Попробуйте ещё раз: держите палец плотнее.';
        }
      });
    }
    
    _isTransitioning = false;
    debugPrint('✅ Processing stopped');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _uiUpdateTimer?.cancel();
    _ppgSubscription?.cancel();
    _imageStreamController?.close();
    _controller?.dispose();
    _ppgService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Показываем финальные результаты если измерение завершено
    final displayBPM = _finalBPM ?? (_isScanning ? _calculateLiveBPM() : 0);
    final displayHRV = _finalHRV ?? (_isScanning ? _calculateCurrentHRV() : 0.0);
    final isValid = _currentSignal != null && _isSignalValid(_currentSignal!);

    return Scaffold(
      appBar: AppBar(title: const Text('HRV Measurement')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Камера + таймер
                    Row(
                      children: [
                        // Окно камеры
                        _buildCameraPreview(),
                        const SizedBox(width: 20),
                        // Таймер или время измерения
                        Expanded(
                          child: _isScanning
                              ? Text(
                                  '$_timeLeft sec',
                                  style: const TextStyle(fontSize: 24, color: Colors.grey),
                                )
                              : _measurementTime != null
                                  ? Text(
                                      'Measured at ${_measurementTime!.hour}:${_measurementTime!.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    )
                                  : const SizedBox(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    // Финальные результаты - крупно
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // BPM
                        Text(
                          displayBPM > 0 ? '$displayBPM' : '--',
                          semanticsLabel: displayBPM > 0 ? 'Пульс $displayBPM ударов в минуту' : 'Пульс не определён',
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: displayBPM > 0 ? Colors.greenAccent : Colors.grey,
                          ),
                        ),
                        const Text('BPM', style: TextStyle(fontSize: 24, color: Colors.grey)),
                        const SizedBox(height: 40),
                        
                        // HRV
                        Text(
                          displayHRV > 0 ? displayHRV.toStringAsFixed(1) : '--',
                          semanticsLabel: displayHRV > 0 ? 'Вариабельность ${displayHRV.toStringAsFixed(1)} миллисекунд' : 'Вариабельность не определена',
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: displayHRV > 0 ? Colors.blueAccent : Colors.grey,
                          ),
                        ),
                        const Text('HRV (ms)', style: TextStyle(fontSize: 24, color: Colors.grey)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // График HRV истории
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('HRV History', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: _buildHRVHistoryChart(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Статус + диагностика
                    Column(
                      children: [
                        Center(
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: _isScanning ? _getQualityColor() : Colors.greenAccent,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_isScanning && _enableConsoleLog) ...[
                          const SizedBox(height: 8),
                          Text(
                            'RR: ${_rrHistory.length}/$_minValidRRCount | FPS: ${_currentSignal?.frameRate.toStringAsFixed(1) ?? "--"} | '
                            'Rej: ${_currentSignal != null ? ((_currentSignal!.rejectionRatio * 100).toStringAsFixed(0)) : "--"}%',
                            style: TextStyle(
                              fontSize: 11, 
                              color: _rrHistory.length >= _minValidRRCount ? Colors.greenAccent : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Кнопка START/STOP - всегда внизу экрана
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isTransitioning ? null : _toggleScanning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTransitioning ? Colors.grey : (_isScanning ? Colors.red : Colors.green),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow, size: 28),
                label: Text(
                  _isScanning ? 'STOP' : 'START',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  int _calculateLiveBPM() {
    if (_rrHistory.length < 6) return 0;  // Минимум 6 RR для расчёта
    
    final meanRR = _meanRecentRR();
    if (meanRR <= 0) return 0;
    
    final bpm = (60000 / meanRR).round();
    
    // Расширенный диапазон: 35-220 bpm (спортсмены могут иметь 35-40, стресс до 220)
    return (bpm >= 35 && bpm <= 220) ? bpm : 0;
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade800),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final qualityColor = _getQualityColor();
    final isGoodSignal = _currentSignal?.quality == SignalQuality.good;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: qualityColor, 
          width: isGoodSignal ? 4 : 3,
        ),
        // Пульсация при хорошем сигнале (Apple-style)
        boxShadow: isGoodSignal ? [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.6),
            blurRadius: 16,
            spreadRadius: 4,
          )
        ] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: CameraPreview(_controller!),
    );
  }

  // График истории HRV
  Widget _buildHRVHistoryChart() {
    if (_hrvHistory.isEmpty) {
      return const Center(
        child: Text('Collecting HRV data...', style: TextStyle(color: Colors.white54)),
      );
    }
    
    // Фильтруем нулевые значения
    final validHRV = _hrvHistory.where((v) => v > 0).toList();
    if (validHRV.isEmpty) {
      return const Center(
        child: Text('Waiting for valid HRV...', style: TextStyle(color: Colors.white54)),
      );
    }
    
    return CustomPaint(
      painter: _HRVHistoryPainter(validHRV, Colors.blueAccent),
      child: Container(),
    );
  }
  
  // Вычисляем HRV из накопленных RR интервалов (SDRR - стандартное отклонение)
  double _calculateCurrentHRV() {
    if (_rrHistory.length < 8) return 0.0;
    
    // Берем последние 20 RR интервалов для расчета (или все если меньше)
    final window = _rrHistory.length > 20 
        ? _rrHistory.sublist(_rrHistory.length - 20) 
        : _rrHistory;
    
    if (window.length < 8) return 0.0;
    
    // Вычисляем среднее
    final mean = window.reduce((a, b) => a + b) / window.length;
    
    // Вычисляем стандартное отклонение (SDRR)
    double sumSquares = 0.0;
    for (final rr in window) {
      sumSquares += (rr - mean) * (rr - mean);
    }
    final variance = sumSquares / window.length;
    final sdrr = sqrt(variance).clamp(0.0, 250.0);  // RMSSD/SDRR
    
    return sdrr;
  }
  
  // Проверка технической валидности измерения
  bool _isPhysiologicallyValid() {
    // Минимум 20 RR интервалов для статистически значимого результата
    if (_rrHistory.length < _minValidRRCount) {
      debugPrint('❌ Недостаточно данных: ${_rrHistory.length} RR (нужно минимум $_minValidRRCount)');
      return false;
    }
    
    final meanRR = _meanRecentRR();
    if (meanRR <= 0) {
      debugPrint('❌ Некорректный средний RR: $meanRR');
      return false;
    }
    
    final bpm = (60000 / meanRR).round();
    
    // Технический диапазон для человека: 35-220 bpm
    if (bpm < 35 || bpm > 220) {
      debugPrint('❌ BPM вне допустимого диапазона: $bpm (допустимо: 35-220)');
      return false;
    }
    
    // Проверка HRV - ключевой показатель качества данных
    final hrv = _calculateCurrentHRV();
    
    // Слишком низкая HRV = технический артефакт (все значения почти одинаковые)
    if (hrv < _minHRV) {
      debugPrint('❌ HRV слишком низкая: ${hrv.toStringAsFixed(1)} ms (минимум $_minHRV ms)');
      debugPrint('   Вероятные причины: технический артефакт, плохой контакт');
      return false;
    }
    
    // Слишком высокая HRV = слишком много шума
    if (hrv > _maxHRV) {
      debugPrint('❌ HRV слишком высокая: ${hrv.toStringAsFixed(1)} ms (максимум $_maxHRV ms)');
      debugPrint('   Вероятные причины: шум, движение, нестабильный сигнал');
      return false;
    }
    
    // Коэффициент вариации - проверка стабильности измерения
    final cv = (hrv / meanRR) * 100;
    if (cv > 35) {
      debugPrint('⚠️ Высокая вариабельность: CV=${cv.toStringAsFixed(1)}% (норма: <35%)');
      debugPrint('   Возможно движение или нестабильный контакт');
    }
    
    // Проверка разнообразия данных (защита от артефактов)
    final uniqueRR = _rrHistory.toSet().length;
    final uniqueRatio = uniqueRR / _rrHistory.length;
    if (uniqueRatio < 0.4) {
      debugPrint('⚠️ Низкое разнообразие данных: только $uniqueRR уникальных значений из ${_rrHistory.length}');
      debugPrint('   Соотношение: ${(uniqueRatio * 100).toStringAsFixed(0)}% (норма: >40%)');
      debugPrint('   Возможен технический артефакт');
    }
    
    // Проверка диапазона RR интервалов
    final minRR = _rrHistory.reduce((a, b) => a < b ? a : b);
    final maxRR = _rrHistory.reduce((a, b) => a > b ? a : b);
    final rrRange = maxRR - minRR;
    
    if (rrRange < 30) {
      debugPrint('⚠️ Слишком узкий диапазон RR: ${rrRange.toStringAsFixed(0)} ms');
      debugPrint('   Возможен технический артефакт');
    }
    
    debugPrint('✅ Измерение технически валидно:');
    debugPrint('   BPM: $bpm (диапазон: 35-220)');
    debugPrint('   HRV: ${hrv.toStringAsFixed(1)} ms (диапазон: $_minHRV-$_maxHRV)');
    debugPrint('   RR интервалов: ${_rrHistory.length} (минимум: $_minValidRRCount)');
    debugPrint('   CV: ${cv.toStringAsFixed(1)}% (норма: <35%)');
    debugPrint('   Уникальных RR: $uniqueRR/${_rrHistory.length} (${(uniqueRatio * 100).toStringAsFixed(0)}%)');
    debugPrint('   Диапазон RR: ${minRR.toStringAsFixed(0)}-${maxRR.toStringAsFixed(0)} ms (размах: ${rrRange.toStringAsFixed(0)} ms)');
    
    return true;
  }

  Widget _buildStatsPanel() {
    // Валидация сигнала
    final isValid = _currentSignal != null && _isSignalValid(_currentSignal!);
    
    // Расчет BPM из RR интервалов
    String bpmDisplay = '--';
    final meanRR = _meanRecentRR();
    
    // ВРЕМЕННО: показываем BPM даже если невалидный, для диагностики
    if (meanRR > 0) {
      final bpm = (60000 / meanRR).round();
      bpmDisplay = '$bpm';
      debugPrint('💓 BPM calculated: $bpm (from meanRR: ${meanRR.toStringAsFixed(1)} ms, valid: $isValid)');
    } else {
      debugPrint('⚠️ No BPM: meanRR=$meanRR, rrHistory.length=${_rrHistory.length}');
    }
    
    // HRV (SDRR) из сигнала
    String hrvDisplay = '--';
    final sdrr = _currentSignal?.sdrr ?? 0.0;
    
    // ВРЕМЕННО: показываем HRV даже если невалидный, для диагностики
    if (sdrr > 0) {
      hrvDisplay = '${sdrr.toStringAsFixed(1)}';
      debugPrint('💚 HRV (SDRR): $hrvDisplay ms (valid: $isValid)');
    } else {
      debugPrint('⚠️ No HRV: sdrr=$sdrr, currentSignal=${_currentSignal != null}');
    }
    
    // Остальные параметры
    final snr = _currentSignal?.snr ?? 0.0;
    final quality = _currentSignal?.quality ?? SignalQuality.poor;
    final rejectionRatio = _currentSignal?.rejectionRatio ?? 0.0;
    final isFPSStable = _currentSignal?.isFPSStable ?? false;
    final isSDRRAcceptable = _currentSignal?.isSDRRAcceptable ?? false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Таймер
            if (_isScanning)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Text('$_timeLeft s', style: const TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 8),
            
            // BPM - большой и заметный
            Row(
              children: [
                const Text('BPM: ', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text(
                  bpmDisplay,
                  style: TextStyle(
                    fontSize: 48, 
                    fontWeight: FontWeight.bold, 
                    color: isValid ? Colors.greenAccent : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // HRV - тоже большой и заметный
            Row(
              children: [
                const Text('HRV: ', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text(
                  hrvDisplay,
                  style: TextStyle(
                    fontSize: 36, 
                    fontWeight: FontWeight.bold, 
                    color: isValid ? Colors.blueAccent : Colors.orange,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('ms', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Статус
            Text(_status, style: TextStyle(color: _getQualityColor(), fontSize: 14)),
            const Divider(height: 16),
            
            // Детальная информация для диагностики
            Text(
              'Quality: ${quality.name.toUpperCase()} | SNR: ${snr.toStringAsFixed(1)} dB',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Valid: ${isValid ? "✅" : "❌"} | FPS: ${isFPSStable ? "✅" : "❌"} | SDRR_OK: ${isSDRRAcceptable ? "✅" : "❌"} | Rej: ${(rejectionRatio * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Peaks: ${_currentPeakIndices.length} | RR count: ${_rrHistory.length}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformCard(String title, List<double> data, Color color, List<int> peaks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: CustomPaint(painter: _WaveformPainter(data, color, peaks), child: Container()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRRHistoryCard() {
    final isValid = _currentSignal != null && _isSignalValid(_currentSignal!);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RR Intervals (ms)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            !isValid
                ? const Text('Waiting for valid signal...', style: TextStyle(color: Colors.orange))
                : _rrHistory.isEmpty
                    ? const Text('Collecting data...', style: TextStyle(color: Colors.white54))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _rrHistory.map((rr) {
                          final isOutlier = rr < 400 || rr > 1500;
                          return Chip(
                            label: Text('${rr.round()}'),
                            backgroundColor: isOutlier ? Colors.orange.shade800 : Colors.green.shade800,
                            labelStyle: const TextStyle(fontSize: 11),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor() {
    if (_currentSignal == null) return Colors.grey;
    return switch (_currentSignal!.quality) {
      SignalQuality.good => Colors.greenAccent,
      SignalQuality.fair => Colors.orangeAccent,
      SignalQuality.poor => Colors.redAccent,
    };
  }
}

/// Painter для графика истории HRV
class _HRVHistoryPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _HRVHistoryPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final w = size.width, h = size.height, len = data.length;

    double minV = data.reduce((a, b) => a < b ? a : b);
    double maxV = data.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;
    final pad = range * 0.1;
    minV -= pad;
    maxV += pad;
    final scaleY = (maxV == minV) ? 1.0 : h / (maxV - minV);
    final stepX = w / (len - 1);

    for (int i = 0; i < len; i++) {
      final x = i * stepX;
      final y = h - ((data[i] - minV) * scaleY);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
    
    // Рисуем точки
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < len; i++) {
      final x = i * stepX;
      final y = h - ((data[i] - minV) * scaleY);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HRVHistoryPainter old) => old.data != data;
}

/// Lightweight waveform painter with optional peak markers.
class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final List<int> peaks;

  _WaveformPainter(this.data, this.color, this.peaks);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final w = size.width, h = size.height, len = data.length;

    double minV = data.reduce((a, b) => a < b ? a : b), maxV = data.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV, pad = range * 0.1;
    minV -= pad;
    maxV += pad;
    final scaleY = (maxV == minV) ? 1.0 : h / (maxV - minV);
    final stepX = w / (len - 1);

    for (int i = 0; i < len; i++) {
      final x = i * stepX, y = h - ((data[i] - minV) * scaleY);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    if (peaks.isNotEmpty) {
      final peakPaint = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.fill;
      for (final idx in peaks) {
        if (idx >= 0 && idx < len) {
          canvas.drawCircle(Offset(idx * stepX, h - ((data[idx] - minV) * scaleY)), 5, peakPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.data != data || old.peaks != peaks || old.color != color;
}

class _Stats {
  final double mean;
  final double min;
  final double max;

  const _Stats(this.mean, this.min, this.max);
}