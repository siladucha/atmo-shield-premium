import 'dart:math';
import 'package:flutter/foundation.dart';

class SignalProcessor {
  List<double> rawSignal = [];
  List<double> filteredSignal = [];
  List<int> peakIndices = [];

  // Simple moving average filter for MVP
  List<double> applyMovingAverageFilter(List<double> signal, {int windowSize = 5}) {
    if (signal.length < windowSize) return signal;

    List<double> filtered = [];
    
    for (int i = 0; i < signal.length; i++) {
      int start = max(0, i - windowSize ~/ 2);
      int end = min(signal.length, i + windowSize ~/ 2 + 1);
      
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += signal[j];
      }
      filtered.add(sum / (end - start));
    }
    
    return filtered;
  }

  // Detect peaks with adaptive threshold
  List<int> detectPeaks(List<double> signal, int samplingRate) {
    if (signal.isEmpty) return [];

    // Calculate statistics
    double minVal = signal.reduce(min);
    double maxVal = signal.reduce(max);
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double amplitude = maxVal - minVal;
    
    // Adaptive threshold based on signal characteristics
    // For low brightness signals, use lower threshold multiplier
    double thresholdMultiplier = mean < 50 ? 0.05 : 0.1;
    double threshold = mean + (amplitude * thresholdMultiplier);

    // Minimum peak separation: 300ms (200 BPM max)
    int minSeparation = max(3, (samplingRate * 0.3).round());

    List<int> peaks = [];

    // Use wider window for peak detection (helps with noisy signal)
    for (int i = 2; i < signal.length - 2; i++) {
      // Check if it's a peak (compare with neighbors)
      bool isPeak = signal[i] > threshold &&
          signal[i] >= signal[i - 1] &&
          signal[i] >= signal[i + 1] &&
          signal[i] >= signal[i - 2] &&
          signal[i] >= signal[i + 2];

      if (isPeak) {
        // Check minimum separation
        if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
          peaks.add(i);
        }
      }
    }

    debugPrint('Detected ${peaks.length} peaks (threshold: ${threshold.toStringAsFixed(1)}, amplitude: ${amplitude.toStringAsFixed(1)}, mean: ${mean.toStringAsFixed(1)}, multiplier: $thresholdMultiplier)');
    
    // If too few peaks, try with even lower threshold
    if (peaks.length < 5 && amplitude > 10) {
      debugPrint('Too few peaks, retrying with lower threshold...');
      threshold = mean + (amplitude * 0.03); // Very sensitive
      peaks.clear();
      
      for (int i = 2; i < signal.length - 2; i++) {
        bool isPeak = signal[i] > threshold &&
            signal[i] >= signal[i - 1] &&
            signal[i] >= signal[i + 1];

        if (isPeak) {
          if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
            peaks.add(i);
          }
        }
      }
      debugPrint('Retry found ${peaks.length} peaks with threshold ${threshold.toStringAsFixed(1)}');
    }
    
    return peaks;
  }

  // Calculate BPM from peaks
  int calculateBPM(List<int> peaks, int samplingRate) {
    if (peaks.length < 3) {
      throw Exception('Not enough peaks detected (need at least 3, got ${peaks.length})');
    }

    // Calculate inter-beat intervals (IBI) in milliseconds
    List<double> ibis = [];
    for (int i = 1; i < peaks.length; i++) {
      double ibi = ((peaks[i] - peaks[i - 1]) / samplingRate) * 1000;
      
      // Filter out unrealistic IBIs (outside 250-2000ms = 30-240 BPM)
      if (ibi >= 250 && ibi <= 2000) {
        ibis.add(ibi);
      }
    }

    if (ibis.isEmpty) {
      throw Exception('No valid inter-beat intervals found');
    }

    // Calculate median IBI (more robust than mean)
    ibis.sort();
    double medianIBI = ibis.length.isOdd
        ? ibis[ibis.length ~/ 2]
        : (ibis[ibis.length ~/ 2 - 1] + ibis[ibis.length ~/ 2]) / 2;

    // BPM = 60000 / median IBI
    int bpm = (60000 / medianIBI).round();

    // Validate range: 40-180 BPM (realistic for finger measurement)
    if (bpm < 40 || bpm > 180) {
      throw Exception('BPM out of valid range: $bpm');
    }

    debugPrint('Calculated BPM: $bpm from ${peaks.length} peaks (${ibis.length} valid IBIs)');
    return bpm;
  }

  // Calculate RMSSD for HRV
  double? calculateRMSSD(List<int> peaks, int samplingRate) {
    if (peaks.length < 5) {
      debugPrint('Not enough peaks for RMSSD calculation (need at least 5)');
      return null;
    }

    // Calculate inter-beat intervals (IBI) in milliseconds
    List<double> ibis = [];
    for (int i = 1; i < peaks.length; i++) {
      double ibi = ((peaks[i] - peaks[i - 1]) / samplingRate) * 1000;
      
      // Filter out unrealistic IBIs (outside 400-1200ms = 50-150 BPM)
      // Stricter range for HRV calculation
      if (ibi >= 400 && ibi <= 1200) {
        ibis.add(ibi);
      }
    }

    if (ibis.length < 4) {
      debugPrint('Not enough valid IBIs for RMSSD calculation (got ${ibis.length})');
      return null;
    }

    // Calculate median IBI for outlier detection
    List<double> sortedIbis = List.from(ibis)..sort();
    double medianIBI = sortedIbis.length.isOdd
        ? sortedIbis[sortedIbis.length ~/ 2]
        : (sortedIbis[sortedIbis.length ~/ 2 - 1] + sortedIbis[sortedIbis.length ~/ 2]) / 2;

    // Filter outliers: keep only IBIs within 20% of median (stricter)
    List<double> filteredIbis = ibis.where((ibi) {
      double deviation = (ibi - medianIBI).abs() / medianIBI;
      return deviation < 0.2;
    }).toList();

    if (filteredIbis.length < 3) {
      debugPrint('Not enough IBIs after outlier filtering (got ${filteredIbis.length} from ${ibis.length})');
      return null;
    }

    // Calculate successive differences
    List<double> diffs = [];
    for (int i = 1; i < filteredIbis.length; i++) {
      double diff = filteredIbis[i] - filteredIbis[i - 1];
      
      // Filter extreme successive differences (> 200ms is unrealistic)
      if (diff.abs() < 200) {
        diffs.add(diff);
      }
    }

    if (diffs.length < 2) {
      debugPrint('Not enough valid successive differences (got ${diffs.length})');
      return null;
    }

    // RMSSD = sqrt(mean(diff^2))
    double sumSquares = diffs.map((d) => d * d).reduce((a, b) => a + b);
    double rmssd = sqrt(sumSquares / diffs.length);

    // Validate range: 10-150ms (realistic for camera-based measurement)
    if (rmssd < 10 || rmssd > 150) {
      debugPrint('RMSSD out of valid range: ${rmssd.toStringAsFixed(1)} ms (from ${diffs.length} diffs, ${filteredIbis.length} IBIs)');
      return null;
    }

    debugPrint('Calculated RMSSD: ${rmssd.toStringAsFixed(1)} ms (from ${diffs.length} diffs, ${filteredIbis.length} filtered IBIs)');
    return rmssd;
  }

  // Process complete measurement
  Map<String, dynamic> processMeasurement(
    List<double> intensityValues,
    int samplingRate,
    bool calculateHRV,
  ) {
    try {
      // Store raw signal
      rawSignal = intensityValues;

      // Apply filter
      filteredSignal = applyMovingAverageFilter(intensityValues);

      // Detect peaks
      peakIndices = detectPeaks(filteredSignal, samplingRate);

      // Calculate BPM
      int bpm = calculateBPM(peakIndices, samplingRate);

      // Calculate RMSSD if requested
      double? rmssd;
      if (calculateHRV) {
        rmssd = calculateRMSSD(peakIndices, samplingRate);
      }

      return {
        'success': true,
        'bpm': bpm,
        'rmssd': rmssd,
        'peakCount': peakIndices.length,
      };
    } catch (e) {
      debugPrint('Signal processing error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
