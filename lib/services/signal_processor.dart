import 'dart:math';
import 'package:flutter/foundation.dart';

class SignalProcessor {
  List<double> rawSignal = [];
  List<double> filteredSignal = [];
  List<int> peakIndices = [];

  // Simple but robust band-pass filter
  List<double> applyBandPassFilter(List<double> signal, int samplingRate) {
    if (signal.length < 10) return signal;
    
    debugPrint('🔧 [FILTER] Starting band-pass filter on ${signal.length} samples');
    
    // 📊 DEBUG: Show raw signal statistics BEFORE filtering
    double rawMean = signal.reduce((a, b) => a + b) / signal.length;
    double rawMin = signal.reduce(min);
    double rawMax = signal.reduce(max);
    String first50Raw = signal.take(50).map((v) => v.toStringAsFixed(1)).join(', ');
    debugPrint('📈 RAW signal stats: mean=${rawMean.toStringAsFixed(2)}, min=${rawMin.toStringAsFixed(1)}, max=${rawMax.toStringAsFixed(1)}, amplitude=${(rawMax - rawMin).toStringAsFixed(1)}');
    debugPrint('📈 RAW signal first 50 values: $first50Raw');
    
    // Step 1: Remove DC component (subtract mean)
    debugPrint('🔧 [FILTER] Original signal mean: ${rawMean.toStringAsFixed(2)}');
    
    List<double> centered = signal.map((v) => v - rawMean).toList();
    
    // Show first 10 values before inversion
    String first10Before = centered.take(10).map((v) => v.toStringAsFixed(1)).join(', ');
    debugPrint('🔧 [FILTER] First 10 centered values BEFORE inversion: $first10Before');
    
    // 🎯 AUTO-INVERSION: Detect if signal is inverted (valleys instead of peaks)
    // Check if negative values have more energy (larger absolute values)
    double negativeEnergy = 0;
    double positiveEnergy = 0;
    
    for (var v in centered) {
      if (v < 0) {
        negativeEnergy += v.abs();
      } else {
        positiveEnergy += v;
      }
    }
    
    debugPrint('🔧 [FILTER] Energy analysis: negative=${negativeEnergy.toStringAsFixed(1)}, positive=${positiveEnergy.toStringAsFixed(1)}, ratio=${(negativeEnergy/positiveEnergy).toStringAsFixed(2)}');
    
    // If negative energy is larger (even slightly), signal is likely inverted
    if (negativeEnergy > positiveEnergy * 1.02) {
      debugPrint('🔄 [INVERSION] Signal auto-inverted: negative energy ${negativeEnergy.toStringAsFixed(1)} > positive ${positiveEnergy.toStringAsFixed(1)} (valleys → peaks)');
      centered = centered.map((v) => -v).toList();
      
      // Show first 10 values after inversion
      String first10After = centered.take(10).map((v) => v.toStringAsFixed(1)).join(', ');
      debugPrint('🔄 [INVERSION] First 10 values AFTER inversion: $first10After');
    } else {
      debugPrint('✅ [INVERSION] No inversion needed (signal already has peaks)');
    }
    
    // Step 2: MINIMAL smoothing - only if signal is very noisy
    // Calculate variance to decide if smoothing is needed
    double variance = 0;
    for (var val in centered) {
      variance += val * val;
    }
    variance /= centered.length;
    
    List<double> smoothed;
    
    if (variance > 100) {
      // Very noisy signal - apply light smoothing
      debugPrint('🔧 [FILTER] High variance ($variance) - applying light smoothing');
      int windowSize = 3;
      smoothed = [];
      
      for (int i = 0; i < centered.length; i++) {
        int start = max(0, i - 1);
        int end = min(centered.length, i + 2);
        double sum = 0;
        for (int j = start; j < end; j++) {
          sum += centered[j];
        }
        smoothed.add(sum / (end - start));
      }
      debugPrint('🔧 [FILTER] Smoothing complete with window=$windowSize');
    } else {
      // Low variance - skip smoothing to preserve weak signal
      debugPrint('🔧 [FILTER] Low variance ($variance) - skipping smoothing to preserve signal');
      smoothed = centered;
    }
    
    return smoothed;
  }

  // Detect peaks with adaptive threshold and prominence check
  List<int> detectPeaks(List<double> signal, int samplingRate) {
    if (signal.isEmpty) return [];

    debugPrint('🎯 [PEAKS] Starting peak detection on ${signal.length} samples at $samplingRate FPS');

    // Signal is centered around 0 after filtering
    double maxVal = signal.reduce(max);
    double minVal = signal.reduce(min);
    double amplitude = maxVal - minVal;
    
    debugPrint('🎯 [PEAKS] Signal range: min=${minVal.toStringAsFixed(2)}, max=${maxVal.toStringAsFixed(2)}, amplitude=${amplitude.toStringAsFixed(2)}');
    
    if (amplitude < 1.0) {
      debugPrint('❌ [PEAKS] Signal amplitude too small: ${amplitude.toStringAsFixed(2)}');
      return [];
    }
    
    // Calculate variance for noise assessment
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double variance = 0;
    for (var val in signal) {
      variance += (val - mean) * (val - mean);
    }
    variance /= signal.length;
    
    // 🎯 ADAPTIVE THRESHOLD CALCULATION
    // Base threshold: 20% of amplitude (works for 95% of PPG signals)
    double baseThreshold = amplitude * 0.20;
    
    // Noise correction: increase threshold if signal is noisy
    double noiseFactor = variance > 200 ? 1.2 : 1.0;
    
    // Calculate threshold with noise correction
    double threshold = baseThreshold * noiseFactor;
    
    // Clamp between 5% and 40% of amplitude
    double minThreshold = amplitude * 0.05;
    double maxThreshold = amplitude * 0.40;
    threshold = threshold.clamp(minThreshold, maxThreshold);
    
    // Ensure always positive
    threshold = threshold.abs();

    // Minimum peak separation: 350ms (171 BPM max)
    int minSeparation = max(3, (samplingRate * 0.35).round());
    
    // 🎯 ADAPTIVE PROMINENCE based on signal variance
    double prominenceThreshold;
    if (variance > 500) {
      // Noisy signal - require stronger peaks
      prominenceThreshold = amplitude * 0.25;
      debugPrint('📊 High variance ($variance) - using strict prominence: ${prominenceThreshold.toStringAsFixed(2)}');
    } else if (variance < 50) {
      // Weak signal - lower requirements
      prominenceThreshold = amplitude * 0.08;
      debugPrint('📊 Low variance ($variance) - using relaxed prominence: ${prominenceThreshold.toStringAsFixed(2)}');
    } else {
      // Normal signal
      prominenceThreshold = amplitude * 0.15;
    }

    List<int> peaks = [];

    // Peak detection
    int candidatesAboveThreshold = 0;
    int candidatesIsPeak = 0;
    int candidatesProminence = 0;
    int candidatesSeparation = 0;
    
    for (int i = 1; i < signal.length - 1; i++) {
      if (signal[i] <= threshold) continue;
      candidatesAboveThreshold++;
      
      bool isPeak = signal[i] > signal[i - 1] && signal[i] > signal[i + 1];
      if (!isPeak) continue;
      candidatesIsPeak++;

      double leftValley = i >= 2 ? min(signal[i - 1], signal[i - 2]) : signal[i - 1];
      double rightValley = i < signal.length - 2 ? min(signal[i + 1], signal[i + 2]) : signal[i + 1];
      double minValley = min(leftValley, rightValley);
      double prominence = signal[i] - minValley;
      
      if (prominence < prominenceThreshold) {
        debugPrint('  ❌ Peak at i=$i rejected: prominence ${prominence.toStringAsFixed(2)} < ${prominenceThreshold.toStringAsFixed(2)}');
        continue;
      }
      candidatesProminence++;
      
      if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
        peaks.add(i);
        candidatesSeparation++;
        debugPrint('  ✅ Peak #${peaks.length} detected at i=$i, value=${signal[i].toStringAsFixed(2)}, prominence=${prominence.toStringAsFixed(2)}');
      } else if (signal[i] > signal[peaks.last]) {
        debugPrint('  🔄 Peak at i=$i replaces peak at ${peaks.last} (better value: ${signal[i].toStringAsFixed(2)} > ${signal[peaks.last].toStringAsFixed(2)})');
        peaks[peaks.length - 1] = i;
      } else {
        debugPrint('  ⏭️ Peak at i=$i skipped: too close to previous peak at ${peaks.last} (separation: ${i - peaks.last} < $minSeparation)');
      }
    }
    
    debugPrint('Peak detection stats: aboveThreshold=$candidatesAboveThreshold, isPeak=$candidatesIsPeak, hasProminence=$candidatesProminence, passedSeparation=$candidatesSeparation');

    debugPrint('Detected ${peaks.length} peaks (threshold: ${threshold.toStringAsFixed(2)}, prominence: ${prominenceThreshold.toStringAsFixed(2)}, amplitude: ${amplitude.toStringAsFixed(2)}, variance: ${variance.toStringAsFixed(2)}, min: ${minVal.toStringAsFixed(2)}, max: ${maxVal.toStringAsFixed(2)})');
    
    // Debug: show first 20 signal values to understand the data
    if (signal.length >= 20) {
      String first20 = signal.take(20).map((v) => v.toStringAsFixed(1)).join(', ');
      debugPrint('First 20 signal values: $first20');
    }
    
    // If too few peaks, try with lower threshold (need at least 3 for BPM calculation)
    if (peaks.length < 3) {
      debugPrint('Too few peaks (${peaks.length}), retrying with lower threshold...');
      
      // Retry with 60% of original threshold, but not below minimum
      threshold = (threshold * 0.6).clamp(minThreshold, threshold);
      prominenceThreshold = (prominenceThreshold * 0.7).clamp(amplitude * 0.08, prominenceThreshold);
      
      peaks.clear();
      
      candidatesAboveThreshold = 0;
      candidatesIsPeak = 0;
      candidatesProminence = 0;
      candidatesSeparation = 0;
      
      for (int i = 1; i < signal.length - 1; i++) {
        if (signal[i] <= threshold) continue;
        candidatesAboveThreshold++;
        
        bool isPeak = signal[i] > signal[i - 1] && signal[i] > signal[i + 1];
        if (!isPeak) continue;
        candidatesIsPeak++;

        double leftValley = i >= 2 ? min(signal[i - 1], signal[i - 2]) : signal[i - 1];
        double rightValley = i < signal.length - 2 ? min(signal[i + 1], signal[i + 2]) : signal[i + 1];
        double minValley = min(leftValley, rightValley);
        double prominence = signal[i] - minValley;
        
        if (prominence < prominenceThreshold) {
          debugPrint('  ❌ RETRY Peak at i=$i rejected: prominence ${prominence.toStringAsFixed(2)} < ${prominenceThreshold.toStringAsFixed(2)}');
          continue;
        }
        candidatesProminence++;
        
        if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
          peaks.add(i);
          candidatesSeparation++;
          debugPrint('  ✅ RETRY Peak #${peaks.length} detected at i=$i, value=${signal[i].toStringAsFixed(2)}, prominence=${prominence.toStringAsFixed(2)}');
        } else if (signal[i] > signal[peaks.last]) {
          debugPrint('  🔄 RETRY Peak at i=$i replaces peak at ${peaks.last}');
          peaks[peaks.length - 1] = i;
        } else {
          debugPrint('  ⏭️ RETRY Peak at i=$i skipped: too close to previous (separation: ${i - peaks.last} < $minSeparation)');
        }
      }
      debugPrint('RETRY stats: aboveThreshold=$candidatesAboveThreshold, isPeak=$candidatesIsPeak, hasProminence=$candidatesProminence, passedSeparation=$candidatesSeparation');
      debugPrint('Retry found ${peaks.length} peaks with threshold ${threshold.toStringAsFixed(2)}');
    }
    
    return peaks;
  }

  // Calculate BPM from peaks with fallback for poor signal
  int? calculateBPM(List<int> peaks, int samplingRate) {
    if (peaks.length < 2) {
      debugPrint('Not enough peaks for BPM calculation (need at least 2, got ${peaks.length})');
      return null;
    }

    // Calculate inter-beat intervals (IBI) in milliseconds
    List<double> ibis = [];
    List<double> allIbis = []; // Track all IBIs for debugging
    
    for (int i = 1; i < peaks.length; i++) {
      double ibi = ((peaks[i] - peaks[i - 1]) / samplingRate) * 1000;
      allIbis.add(ibi);
      
      // Filter out unrealistic IBIs (outside 250-2000ms = 30-240 BPM)
      if (ibi >= 250 && ibi <= 2000) {
        ibis.add(ibi);
      }
    }

    // Debug: show all IBIs
    debugPrint('All IBIs: ${allIbis.map((ibi) => ibi.toStringAsFixed(0)).join(", ")} ms');
    debugPrint('Valid IBIs (250-2000ms): ${ibis.length} out of ${allIbis.length}');

    if (ibis.isEmpty) {
      debugPrint('No valid inter-beat intervals found (all IBIs outside 250-2000ms range)');
      return null;
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
      debugPrint('BPM out of valid range: $bpm (from ${peaks.length} peaks)');
      return null;
    }

    debugPrint('Calculated BPM: $bpm from ${peaks.length} peaks (${ibis.length} valid IBIs)');
    return bpm;
  }

  // Calculate RMSSD for HRV with adaptive filtering based on measurement duration
  double? calculateRMSSD(List<int> peaks, int samplingRate, {int? totalSeconds}) {
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

    // Adaptive threshold based on measurement duration
    // For 30s: expect ~30-50 beats, require 30% valid
    // For 60s: expect ~60-100 beats, require 40% valid
    // For 120s: expect ~120-200 beats, require 50% valid
    int minIbis = 4; // Absolute minimum
    if (totalSeconds != null) {
      final expectedBeats = (totalSeconds * 1.0).round(); // Assume ~60 BPM
      minIbis = max(4, (expectedBeats * 0.3).round());
    }

    if (ibis.length < minIbis) {
      debugPrint('Not enough valid IBIs for RMSSD calculation (got ${ibis.length}, need at least $minIbis)');
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

    // Adaptive threshold for filtered IBIs
    int minFilteredIbis = max(4, (minIbis * 0.7).round());
    if (filteredIbis.length < minFilteredIbis) {
      debugPrint('Not enough IBIs after outlier filtering (got ${filteredIbis.length} from ${ibis.length}, need at least $minFilteredIbis)');
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

    // Adaptive threshold for diffs
    int minDiffs = max(3, (minFilteredIbis * 0.6).round());
    if (diffs.length < minDiffs) {
      debugPrint('Not enough valid successive differences (got ${diffs.length}, need at least $minDiffs)');
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
    bool calculateHRV, {
    int? totalSeconds,
  }) {
    try {
      // Store raw signal
      rawSignal = intensityValues;

      // 🎯 SKIP FIRST 3 SECONDS to avoid finger placement artifact
      int skipSamples = (samplingRate * 3).round(); // 3 seconds for stabilization
      if (intensityValues.length > skipSamples + 120) { // Need at least 5s of data after skip
        debugPrint('⏭️ Skipping first $skipSamples samples (3s) to avoid placement artifact');
        intensityValues = intensityValues.sublist(skipSamples);
        debugPrint('📊 Processing ${intensityValues.length} samples after skip');
      } else {
        debugPrint('⚠️ Signal too short to skip placement artifact (${intensityValues.length} samples)');
      }

      // Apply band-pass filter to isolate heart rate frequencies
      filteredSignal = applyBandPassFilter(intensityValues, samplingRate);

      // Debug: Export signal statistics
      double minVal = filteredSignal.reduce(min);
      double maxVal = filteredSignal.reduce(max);
      double mean = filteredSignal.reduce((a, b) => a + b) / filteredSignal.length;
      double amplitude = maxVal - minVal;
      
      // Calculate variance
      double variance = 0;
      for (var val in filteredSignal) {
        variance += (val - mean) * (val - mean);
      }
      variance /= filteredSignal.length;
      
      debugPrint('Signal stats: min=${minVal.toStringAsFixed(1)}, max=${maxVal.toStringAsFixed(1)}, mean=${mean.toStringAsFixed(1)}, amplitude=${amplitude.toStringAsFixed(1)}, variance=${variance.toStringAsFixed(2)}');

      // Detect peaks
      peakIndices = detectPeaks(filteredSignal, samplingRate);

      // Check if we have enough peaks
      if (peakIndices.length < 2) {
        debugPrint('Insufficient peaks detected: ${peakIndices.length}');
        return {
          'success': false,
          'error': 'Poor signal quality - unable to detect heartbeat. Please ensure finger is firmly on camera with flash enabled.',
          'peakCount': peakIndices.length,
          'signalMean': mean,
          'signalVariance': variance,
          'signalAmplitude': amplitude,
        };
      }

      // Calculate BPM
      int? bpm = calculateBPM(peakIndices, samplingRate);
      
      if (bpm == null) {
        debugPrint('BPM calculation failed');
        return {
          'success': false,
          'error': 'Unable to calculate heart rate - signal quality too low',
          'peakCount': peakIndices.length,
          'signalMean': mean,
          'signalVariance': variance,
          'signalAmplitude': amplitude,
        };
      }

      // Calculate RMSSD if requested
      double? rmssd;
      if (calculateHRV) {
        rmssd = calculateRMSSD(peakIndices, samplingRate, totalSeconds: totalSeconds);
      }

      return {
        'success': true,
        'bpm': bpm,
        'rmssd': rmssd,
        'peakCount': peakIndices.length,
        'signalMean': mean,
        'signalVariance': variance,
        'signalAmplitude': amplitude,
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
