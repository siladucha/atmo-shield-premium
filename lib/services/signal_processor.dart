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

  // Detect peaks with adaptive threshold and prominence check
  List<int> detectPeaks(List<double> signal, int samplingRate) {
    if (signal.isEmpty) return [];

    // Calculate statistics
    double minVal = signal.reduce(min);
    double maxVal = signal.reduce(max);
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double amplitude = maxVal - minVal;
    
    // Adaptive threshold: 15% of amplitude (increased from 10%)
    // For very dark signals, use 8% minimum
    double thresholdMultiplier = mean < 50 ? 0.08 : 0.15;
    double threshold = mean + (amplitude * thresholdMultiplier);

    // Minimum peak separation: 400ms (150 BPM max) - increased from 300ms
    int minSeparation = max(3, (samplingRate * 0.4).round());
    
    // Prominence threshold: peak must be 15% higher than surrounding valleys
    double prominenceThreshold = amplitude * 0.15;

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
        // Check prominence: peak must be significantly higher than neighbors
        double leftValley = min(signal[i - 1], signal[i - 2]);
        double rightValley = min(signal[i + 1], signal[i + 2]);
        double minValley = min(leftValley, rightValley);
        double prominence = signal[i] - minValley;
        
        if (prominence < prominenceThreshold) {
          continue; // Skip low-prominence peaks (likely noise/dicrotic notch)
        }
        
        // Check minimum separation
        if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
          peaks.add(i);
        }
      }
    }

    debugPrint('Detected ${peaks.length} peaks (threshold: ${threshold.toStringAsFixed(1)}, prominence: ${prominenceThreshold.toStringAsFixed(1)}, amplitude: ${amplitude.toStringAsFixed(1)}, mean: ${mean.toStringAsFixed(1)}, multiplier: $thresholdMultiplier)');
    
    // If too few peaks, try with lower threshold but keep prominence check
    if (peaks.length < 5 && amplitude > 10) {
      debugPrint('Too few peaks, retrying with lower threshold...');
      threshold = mean + (amplitude * 0.05); // More sensitive
      prominenceThreshold = amplitude * 0.12; // Slightly lower prominence
      peaks.clear();
      
      for (int i = 2; i < signal.length - 2; i++) {
        bool isPeak = signal[i] > threshold &&
            signal[i] >= signal[i - 1] &&
            signal[i] >= signal[i + 1];

        if (isPeak) {
          // Still check prominence
          double leftValley = min(signal[i - 1], signal[i - 2]);
          double rightValley = min(signal[i + 1], signal[i + 2]);
          double minValley = min(leftValley, rightValley);
          double prominence = signal[i] - minValley;
          
          if (prominence >= prominenceThreshold) {
            if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
              peaks.add(i);
            }
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

  // Calculate RMSSD for HRV with relaxed filtering
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

    // Filter outliers: keep IBIs within 30% of median (relaxed from 20%)
    List<double> filteredIbis = ibis.where((ibi) {
      double deviation = (ibi - medianIBI).abs() / medianIBI;
      return deviation < 0.3;
    }).toList();

    if (filteredIbis.length < 15) {
      debugPrint('Not enough IBIs after outlier filtering (got ${filteredIbis.length} from ${ibis.length}, need at least 15)');
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

    if (diffs.length < 10) {
      debugPrint('Not enough valid successive differences (got ${diffs.length}, need at least 10)');
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

    debugPrint('Calculated RMSSD: ${rmssd.toStringAsFixed(1)} ms (from ${diffs.length} diffs, ${filteredIbis.length} filtered IBIs out of ${ibis.length} total)');
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
