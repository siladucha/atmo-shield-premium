/// Result of a health data generation operation.
///
/// This model encapsulates the outcome of generating synthetic HealthKit data,
/// including record counts, timing information, errors, and overall status.
class GenerationResult {
  /// Number of heart rate records successfully generated.
  final int hrRecordsGenerated;

  /// Number of HRV records successfully generated.
  final int hrvRecordsGenerated;

  /// Number of respiratory rate records successfully generated.
  final int rrRecordsGenerated;

  /// Number of step count records successfully generated (0 if not enabled).
  final int stepsRecordsGenerated;

  /// Number of sleep duration records successfully generated (0 if not enabled).
  final int sleepRecordsGenerated;

  /// Total time taken to generate all data.
  final Duration generationTime;

  /// List of error messages encountered during generation.
  final List<String> errors;

  /// Overall status of the generation operation.
  final GenerationStatus status;

  const GenerationResult({
    required this.hrRecordsGenerated,
    required this.hrvRecordsGenerated,
    required this.rrRecordsGenerated,
    this.stepsRecordsGenerated = 0,
    this.sleepRecordsGenerated = 0,
    required this.generationTime,
    this.errors = const [],
    required this.status,
  });

  /// Creates a successful generation result.
  ///
  /// Use this factory when data generation completes successfully.
  factory GenerationResult.success({
    required int hrRecords,
    required int hrvRecords,
    required int rrRecords,
    int stepsRecords = 0,
    int sleepRecords = 0,
    required Duration generationTime,
    List<String> errors = const [],
  }) {
    return GenerationResult(
      hrRecordsGenerated: hrRecords,
      hrvRecordsGenerated: hrvRecords,
      rrRecordsGenerated: rrRecords,
      stepsRecordsGenerated: stepsRecords,
      sleepRecordsGenerated: sleepRecords,
      generationTime: generationTime,
      errors: errors,
      status: GenerationStatus.success,
    );
  }

  /// Creates a result indicating permission was denied.
  ///
  /// Use this factory when HealthKit write permissions are not granted.
  factory GenerationResult.permissionDenied() {
    return GenerationResult(
      hrRecordsGenerated: 0,
      hrvRecordsGenerated: 0,
      rrRecordsGenerated: 0,
      generationTime: Duration.zero,
      errors: const ['HealthKit write permission denied'],
      status: GenerationStatus.permissionDenied,
    );
  }

  /// Creates a result indicating an error occurred.
  ///
  /// Use this factory when generation fails due to an error.
  factory GenerationResult.error(String errorMessage) {
    return GenerationResult(
      hrRecordsGenerated: 0,
      hrvRecordsGenerated: 0,
      rrRecordsGenerated: 0,
      generationTime: Duration.zero,
      errors: [errorMessage],
      status: GenerationStatus.error,
    );
  }

  /// Total number of records generated across all data types.
  int get totalRecords =>
      hrRecordsGenerated +
      hrvRecordsGenerated +
      rrRecordsGenerated +
      stepsRecordsGenerated +
      sleepRecordsGenerated;

  /// Whether the generation completed successfully.
  bool get isSuccess => status == GenerationStatus.success;

  /// Whether any errors occurred during generation.
  bool get hasErrors => errors.isNotEmpty;

  /// Creates a formatted summary string for logging.
  ///
  /// Format: "[SynthData] Generated X HR records, Y HRV records, Z RR records"
  String toLogSummary() {
    final buffer = StringBuffer('[SynthData] Generated ');
    buffer.write('$hrRecordsGenerated HR records, ');
    buffer.write('$hrvRecordsGenerated HRV records, ');
    buffer.write('$rrRecordsGenerated RR records');

    if (stepsRecordsGenerated > 0) {
      buffer.write(', $stepsRecordsGenerated Steps records');
    }
    if (sleepRecordsGenerated > 0) {
      buffer.write(', $sleepRecordsGenerated Sleep records');
    }

    buffer.write(' in ${generationTime.inSeconds}s');

    if (hasErrors) {
      buffer.write(' (${errors.length} errors)');
    }

    return buffer.toString();
  }

  /// Creates a user-friendly summary for display in the UI.
  String toDisplaySummary() {
    if (status == GenerationStatus.permissionDenied) {
      return 'Permission denied. Please enable HealthKit access in Settings.';
    }

    if (status == GenerationStatus.error) {
      return 'Generation failed: ${errors.first}';
    }

    final buffer = StringBuffer();
    buffer.writeln('Generated HR records: $hrRecordsGenerated');
    buffer.writeln('Generated HRV records: $hrvRecordsGenerated');
    buffer.writeln('Generated RR records: $rrRecordsGenerated');

    if (stepsRecordsGenerated > 0) {
      buffer.writeln('Generated Steps records: $stepsRecordsGenerated');
    }
    if (sleepRecordsGenerated > 0) {
      buffer.writeln('Generated Sleep records: $sleepRecordsGenerated');
    }

    buffer.writeln('\nTotal: $totalRecords records');
    buffer.write('Time: ${generationTime.inSeconds}s');

    if (hasErrors) {
      buffer.write('\n\nWarnings: ${errors.length} issues encountered');
    }

    return buffer.toString();
  }

  /// Creates a copy of this result with optional parameter overrides.
  GenerationResult copyWith({
    int? hrRecordsGenerated,
    int? hrvRecordsGenerated,
    int? rrRecordsGenerated,
    int? stepsRecordsGenerated,
    int? sleepRecordsGenerated,
    Duration? generationTime,
    List<String>? errors,
    GenerationStatus? status,
  }) {
    return GenerationResult(
      hrRecordsGenerated: hrRecordsGenerated ?? this.hrRecordsGenerated,
      hrvRecordsGenerated: hrvRecordsGenerated ?? this.hrvRecordsGenerated,
      rrRecordsGenerated: rrRecordsGenerated ?? this.rrRecordsGenerated,
      stepsRecordsGenerated:
          stepsRecordsGenerated ?? this.stepsRecordsGenerated,
      sleepRecordsGenerated:
          sleepRecordsGenerated ?? this.sleepRecordsGenerated,
      generationTime: generationTime ?? this.generationTime,
      errors: errors ?? this.errors,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'GenerationResult('
        'hrRecords: $hrRecordsGenerated, '
        'hrvRecords: $hrvRecordsGenerated, '
        'rrRecords: $rrRecordsGenerated, '
        'stepsRecords: $stepsRecordsGenerated, '
        'sleepRecords: $sleepRecordsGenerated, '
        'time: ${generationTime.inSeconds}s, '
        'status: $status, '
        'errors: ${errors.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GenerationResult &&
        other.hrRecordsGenerated == hrRecordsGenerated &&
        other.hrvRecordsGenerated == hrvRecordsGenerated &&
        other.rrRecordsGenerated == rrRecordsGenerated &&
        other.stepsRecordsGenerated == stepsRecordsGenerated &&
        other.sleepRecordsGenerated == sleepRecordsGenerated &&
        other.generationTime == generationTime &&
        _listEquals(other.errors, errors) &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      hrRecordsGenerated,
      hrvRecordsGenerated,
      rrRecordsGenerated,
      stepsRecordsGenerated,
      sleepRecordsGenerated,
      generationTime,
      Object.hashAll(errors),
      status,
    );
  }

  /// Helper method to compare two lists for equality.
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Status of a data generation operation.
enum GenerationStatus {
  /// Generation completed successfully.
  success,

  /// HealthKit write permission was denied by the user.
  permissionDenied,

  /// An error occurred during generation.
  error,
}
