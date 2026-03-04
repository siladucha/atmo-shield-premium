import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/generation_config.dart';
import '../models/generation_result.dart';
import '../models/health_data_point.dart';
import '../generators/heart_rate_generator.dart';
import '../generators/hrv_generator.dart';
import '../generators/respiratory_rate_generator.dart';
import '../generators/steps_generator.dart';
import '../generators/sleep_generator.dart';
import '../utils/stress_calendar.dart';
import '../native/healthkit_bridge.dart';

/// Callback function for progress updates during data generation.
///
/// Parameters:
/// - [progress]: Progress value between 0.0 and 1.0
/// - [message]: Description of current task
typedef ProgressCallback = void Function(double progress, String message);

/// Orchestrates the generation of all synthetic health data types.
///
/// This service coordinates the generation of Heart Rate, HRV, Respiratory Rate,
/// and optional Steps and Sleep data across a 365-day baseline period. It manages
/// parallel generation, progress tracking, error handling, and HealthKit writing.
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.4**
class DataGenerationService {
  final DateTime startDate;
  final DateTime endDate;
  final HealthKitBridge _healthKitBridge;
  final int? _seed;

  // Generators
  late final HeartRateGenerator _hrGenerator;
  late final HRVGenerator _hrvGenerator;
  late final RespiratoryRateGenerator _rrGenerator;
  late final StepsGenerator _stepsGenerator;
  late final SleepGenerator _sleepGenerator;

  // Stress calendar for correlated stress events
  late final StressCalendar _stressCalendar;

  // Statistics tracking
  int _totalRecordsGenerated = 0;
  int _failedWrites = 0;
  final List<String> _errors = [];

  /// Creates a DataGenerationService with a 365-day baseline period.
  ///
  /// Parameters:
  /// - [currentDate]: The current date (defaults to DateTime.now())
  /// - [seed]: Optional random seed for reproducible generation
  /// - [healthKitBridge]: Optional HealthKitBridge instance (for testing)
  ///
  /// The baseline period is calculated as:
  /// - Start date: currentDate - 365 days
  /// - End date: currentDate
  ///
  /// **Validates: Requirements 1.1, 1.2**
  DataGenerationService({
    DateTime? currentDate,
    int? seed,
    HealthKitBridge? healthKitBridge,
  })  : _seed = seed,
        endDate = currentDate ?? DateTime.now(),
        startDate = (currentDate ?? DateTime.now()).subtract(const Duration(days: 365)),
        _healthKitBridge = healthKitBridge ?? HealthKitBridge() {
    // Initialize generators with same seed for reproducibility
    _hrGenerator = HeartRateGenerator(seed: _seed);
    _hrvGenerator = HRVGenerator(seed: _seed);
    _rrGenerator = RespiratoryRateGenerator(seed: _seed);
    _stepsGenerator = StepsGenerator(seed: _seed);
    _sleepGenerator = SleepGenerator(seed: _seed);

    // Create stress calendar for correlated stress events
    _stressCalendar = StressCalendar(startDate, endDate, seed: _seed);

    // Log baseline period
    debugPrint('[SynthData] Baseline period: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
    debugPrint('[SynthData] Generated ${_stressCalendar.stressDayCount} stress days');
  }

  /// Generates all health data types and writes them to HealthKit.
  ///
  /// This method orchestrates the entire data generation process:
  /// 1. Checks HealthKit availability
  /// 2. Requests necessary permissions
  /// 3. Generates data for all enabled types in parallel
  /// 4. Writes data to HealthKit in batches
  /// 5. Tracks progress and errors
  /// 6. Returns comprehensive results
  ///
  /// Parameters:
  /// - [config]: Configuration specifying which data types to generate
  /// - [onProgress]: Optional callback for progress updates
  ///
  /// Returns a [GenerationResult] with counts, timing, and error information.
  ///
  /// **Validates: Requirements 1.3, 1.4, 1.5, 9.1, 9.2, 9.3, 9.4**
  Future<GenerationResult> generateAllData(
    GenerationConfig config, {
    ProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalRecordsGenerated = 0;
    _failedWrites = 0;
    _errors.clear();

    try {
      // Step 1: Check HealthKit availability
      onProgress?.call(0.0, 'Checking HealthKit availability...');
      final isAvailable = await _healthKitBridge.isHealthKitAvailable();
      if (!isAvailable) {
        debugPrint('[SynthData] HealthKit is not available on this device');
        return GenerationResult.error(
          'HealthKit is not available. Please run on a physical iPhone with iOS 16+.',
        );
      }

      // Step 2: Verify permissions (should already be granted via UI button)
      onProgress?.call(0.05, 'Verifying HealthKit permissions...');
      debugPrint('[SynthData] Permissions should already be granted via UI');

      // Step 3: Generate all data types in parallel
      onProgress?.call(0.1, 'Generating health data...');
      final generationResults = await _generateAllDataParallel(config, onProgress);

      // Step 4: Write data to HealthKit
      onProgress?.call(0.7, 'Writing data to HealthKit...');
      await _writeAllDataToHealthKit(generationResults, onProgress);

      // Step 5: Complete
      stopwatch.stop();
      onProgress?.call(1.0, 'Generation complete!');

      // Create result
      final result = GenerationResult.success(
        hrRecords: generationResults['heartRate']?.length ?? 0,
        hrvRecords: generationResults['hrv']?.length ?? 0,
        rrRecords: generationResults['respiratoryRate']?.length ?? 0,
        stepsRecords: generationResults['steps']?.length ?? 0,
        sleepRecords: generationResults['sleep']?.length ?? 0,
        generationTime: stopwatch.elapsed,
        errors: _errors,
      );

      // Log summary
      debugPrint(result.toLogSummary());

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      debugPrint('[SynthData] Generation error: $e\n$stackTrace');
      return GenerationResult.error('Generation failed: $e');
    }
  }

  /// Requests HealthKit write permissions for all enabled data types.
  Future<bool> _requestPermissions(GenerationConfig config) async {
    final writeTypes = <String>[
      'heartRate',
      'hrv',
      'respiratoryRate',
    ];

    if (config.includeSteps) {
      writeTypes.add('steps');
    }

    if (config.includeSleep) {
      writeTypes.add('sleep');
    }

    debugPrint('[SynthData] Requesting permissions for: ${writeTypes.join(", ")}');

    try {
      return await _healthKitBridge.requestPermissions(writeTypes);
    } catch (e) {
      debugPrint('[SynthData] Permission request error: $e');
      _errors.add('Permission request failed: $e');
      return false;
    }
  }

  /// Generates all data types in parallel for performance.
  ///
  /// Uses Future.wait to generate all data types concurrently,
  /// significantly reducing total generation time.
  ///
  /// **Validates: Requirement 9.1**
  Future<Map<String, List<HealthDataPoint>>> _generateAllDataParallel(
    GenerationConfig config,
    ProgressCallback? onProgress,
  ) async {
    final futures = <Future<MapEntry<String, List<HealthDataPoint>>>>[];

    // Generate required data types
    futures.add(_generateHeartRate(config));
    futures.add(_generateHRV(config));
    futures.add(_generateRespiratoryRate());

    // Generate optional data types
    if (config.includeSteps) {
      futures.add(_generateSteps());
    }

    if (config.includeSleep) {
      futures.add(_generateSleep());
    }

    // Wait for all generations to complete
    final results = await Future.wait(futures);

    // Convert list of entries to map
    final resultMap = <String, List<HealthDataPoint>>{};
    for (final entry in results) {
      resultMap[entry.key] = entry.value;
    }

    // Update progress
    onProgress?.call(0.6, 'Data generation complete');

    return resultMap;
  }

  /// Generates Heart Rate data.
  Future<MapEntry<String, List<HealthDataPoint>>> _generateHeartRate(
    GenerationConfig config,
  ) async {
    try {
      debugPrint('[SynthData] Generating Heart Rate data...');
      final data = _hrGenerator.generate(
        startDate,
        endDate,
        targetCount: config.targetHRRecords,
      );
      debugPrint('[SynthData] Generated ${data.length} HR records');
      return MapEntry('heartRate', data);
    } catch (e, stackTrace) {
      debugPrint('[SynthData] HR generation error: $e\n$stackTrace');
      _errors.add('Heart Rate generation failed: $e');
      return const MapEntry('heartRate', []);
    }
  }

  /// Generates HRV data.
  Future<MapEntry<String, List<HealthDataPoint>>> _generateHRV(
    GenerationConfig config,
  ) async {
    try {
      debugPrint('[SynthData] Generating HRV data...');
      final data = _hrvGenerator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: _stressCalendar,
        trendGrowth: config.hrvTrendGrowth,
        trendDurationMonths: config.trendDurationMonths,
      );
      debugPrint('[SynthData] Generated ${data.length} HRV records');
      return MapEntry('hrv', data);
    } catch (e, stackTrace) {
      debugPrint('[SynthData] HRV generation error: $e\n$stackTrace');
      _errors.add('HRV generation failed: $e');
      return const MapEntry('hrv', []);
    }
  }

  /// Generates Respiratory Rate data.
  Future<MapEntry<String, List<HealthDataPoint>>> _generateRespiratoryRate() async {
    try {
      debugPrint('[SynthData] Generating Respiratory Rate data...');
      final data = _rrGenerator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: _stressCalendar,
      );
      debugPrint('[SynthData] Generated ${data.length} RR records');
      return MapEntry('respiratoryRate', data);
    } catch (e, stackTrace) {
      debugPrint('[SynthData] RR generation error: $e\n$stackTrace');
      _errors.add('Respiratory Rate generation failed: $e');
      return const MapEntry('respiratoryRate', []);
    }
  }

  /// Generates Steps data (optional).
  Future<MapEntry<String, List<HealthDataPoint>>> _generateSteps() async {
    try {
      debugPrint('[SynthData] Generating Steps data...');
      final data = _stepsGenerator.generate(startDate, endDate);
      debugPrint('[SynthData] Generated ${data.length} Steps records');
      return MapEntry('steps', data);
    } catch (e, stackTrace) {
      debugPrint('[SynthData] Steps generation error: $e\n$stackTrace');
      _errors.add('Steps generation failed: $e');
      return const MapEntry('steps', []);
    }
  }

  /// Generates Sleep data (optional).
  Future<MapEntry<String, List<HealthDataPoint>>> _generateSleep() async {
    try {
      debugPrint('[SynthData] Generating Sleep data...');
      final data = _sleepGenerator.generate(startDate, endDate);
      debugPrint('[SynthData] Generated ${data.length} Sleep records');
      return MapEntry('sleep', data);
    } catch (e, stackTrace) {
      debugPrint('[SynthData] Sleep generation error: $e\n$stackTrace');
      _errors.add('Sleep generation failed: $e');
      return const MapEntry('sleep', []);
    }
  }

  /// Writes all generated data to HealthKit in batches.
  ///
  /// Processes each data type separately with batch writing for performance.
  /// Continues with remaining data types if one fails.
  ///
  /// **Validates: Requirements 9.2, 9.3**
  Future<void> _writeAllDataToHealthKit(
    Map<String, List<HealthDataPoint>> data,
    ProgressCallback? onProgress,
  ) async {
    final dataTypes = data.keys.toList();
    int completedTypes = 0;

    for (final dataType in dataTypes) {
      final records = data[dataType];
      if (records == null || records.isEmpty) continue;

      try {
        await _writeBatchToHealthKit(dataType, records);
        completedTypes++;

        // Update progress
        final progress = 0.7 + (0.3 * completedTypes / dataTypes.length);
        onProgress?.call(progress, 'Writing $dataType to HealthKit...');
      } catch (e) {
        debugPrint('[SynthData] Failed to write $dataType: $e');
        _errors.add('Failed to write $dataType: $e');
      }
    }
  }

  /// Writes a batch of data points to HealthKit.
  ///
  /// Converts HealthDataPoint objects to the format expected by the native bridge
  /// and writes them in a single batch operation.
  Future<void> _writeBatchToHealthKit(
    String dataType,
    List<HealthDataPoint> records,
  ) async {
    // Convert to native format
    final nativeRecords = records.map((point) {
      return {
        'timestamp': point.timestamp.millisecondsSinceEpoch.toDouble(),
        'value': point.value,
      };
    }).toList();

    // Write batch
    final success = await _healthKitBridge.writeBatch(dataType, nativeRecords);

    if (success) {
      _totalRecordsGenerated += records.length;
      debugPrint('[SynthData] Successfully wrote ${records.length} $dataType records');
    } else {
      _failedWrites += records.length;
      throw Exception('HealthKit write failed for $dataType');
    }
  }

  /// Returns the total number of records generated.
  int get totalRecordsGenerated => _totalRecordsGenerated;

  /// Returns the number of failed write operations.
  int get failedWrites => _failedWrites;

  /// Returns the list of errors encountered during generation.
  List<String> get errors => List.unmodifiable(_errors);

  /// Returns the stress calendar used for correlated stress events.
  StressCalendar get stressCalendar => _stressCalendar;
}
