import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../models/measurement_mode.dart';

class CameraService {
  CameraController? _controller;
  StreamController<Map<String, dynamic>>? _intensityController;
  bool _isProcessing = false;
  int _frameCount = 0;
  DateTime _lastFpsCheck = DateTime.now();
  
  Stream<Map<String, dynamic>> get intensityStream =>
      _intensityController?.stream ?? const Stream.empty();

  Future<void> initialize(MeasurementMode mode) async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.low, // Changed from medium to low for higher FPS
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      
      // Set FPS to maximum available (typically 30 FPS on low resolution)
      await _controller!.setFocusMode(FocusMode.locked);
      
      await _controller!.setFlashMode(FlashMode.torch);

      _intensityController = StreamController<Map<String, dynamic>>.broadcast();
      
      await _controller!.startImageStream(_processImage);
      
      debugPrint('Camera initialized successfully');
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      rethrow;
    }
  }

  void _processImage(CameraImage image) {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _frameCount++;

    try {
      // Extract green channel and calculate mean intensity
      final result = _extractGreenMean(image);
      
      // Log every 30 frames (~1 second at 30 FPS)
      if (_frameCount % 30 == 0) {
        final now = DateTime.now();
        final elapsed = now.difference(_lastFpsCheck).inMilliseconds;
        final fps = (30 * 1000 / elapsed).round();
        _lastFpsCheck = now;
        debugPrint('Camera: ${result['meanGreen'].toStringAsFixed(1)} green, ${result['variance'].toStringAsFixed(2)} var, $fps FPS');
      }
      
      _intensityController?.add(result);
    } catch (e) {
      debugPrint('Image processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Map<String, dynamic> _extractGreenMean(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    
    // Calculate ROI: 5% of sensor width (reduced from 10%), clamped to 50-100px, centered
    final int roiSize = (width * 0.05).round().clamp(50, 100);
    final int startX = (width - roiSize) ~/ 2;
    final int startY = (height - roiSize) ~/ 2;

    // Check plane count - iOS can have 2 or 3 planes depending on format
    if (image.planes.length < 2) {
      debugPrint('Unexpected plane count: ${image.planes.length}');
      return {
        'meanRed': 0.0,
        'meanGreen': 0.0,
        'meanBlue': 0.0,
        'variance': 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    
    // For biplanar format (NV12/NV21), UV data is interleaved in plane[1]
    final bool isBiplanar = image.planes.length == 2;

    // Use Y channel directly for intensity (brightness)
    // This is more reliable than RGB conversion for PPG
    double sumY = 0;
    double sumRed = 0;
    double sumGreen = 0;
    double sumBlue = 0;
    int pixelCount = 0;
    List<double> yValues = [];

    for (int y = startY; y < startY + roiSize; y++) {
      for (int x = startX; x < startX + roiSize; x++) {
        final int yIndex = y * yPlane.bytesPerRow + x;
        
        if (yIndex >= yPlane.bytes.length) {
          continue;
        }

        final int yValue = yPlane.bytes[yIndex];
        sumY += yValue;
        yValues.add(yValue.toDouble());
        pixelCount++;
        
        // Also calculate RGB for color ratio checks (finger detection)
        if (pixelCount % 10 == 0) { // Sample every 10th pixel for RGB
          int uValue, vValue;
          
          if (isBiplanar) {
            final int uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * 2;
            if (uvIndex + 1 < uPlane.bytes.length) {
              uValue = uPlane.bytes[uvIndex] - 128;
              vValue = uPlane.bytes[uvIndex + 1] - 128;
              
              final int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
              final int g = (yValue - 0.344136 * uValue - 0.714136 * vValue).round().clamp(0, 255);
              final int b = (yValue + 1.772 * uValue).round().clamp(0, 255);
              
              sumRed += r;
              sumGreen += g;
              sumBlue += b;
            }
          }
        }
      }
    }

    final double meanY = pixelCount > 0 ? sumY / pixelCount : 0;
    final int rgbSamples = pixelCount ~/ 10;
    final double meanRed = rgbSamples > 0 ? sumRed / rgbSamples : 0;
    final double meanGreen = rgbSamples > 0 ? sumGreen / rgbSamples : 0;
    final double meanBlue = rgbSamples > 0 ? sumBlue / rgbSamples : 0;
    
    // Calculate variance of Y channel (brightness pulsation)
    double variance = 0;
    if (pixelCount > 0) {
      for (final value in yValues) {
        variance += (value - meanY) * (value - meanY);
      }
      variance /= pixelCount;
    }

    return {
      'meanRed': meanRed,
      'meanGreen': meanY, // Use Y channel as "green" for signal processing
      'meanBlue': meanBlue,
      'variance': variance,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  bool _isDisposed = false;

  Future<void> dispose() async {
    if (_isDisposed) {
      debugPrint('⚠️ Camera already disposed, skipping');
      return;
    }
    
    _isDisposed = true;
    
    try {
      // Check if controller is initialized before stopping stream
      if (_controller?.value.isInitialized == true) {
        try {
          await _controller?.stopImageStream();
        } catch (e) {
          debugPrint('Error stopping image stream (safe to ignore): $e');
        }
        
        try {
          await _controller?.setFlashMode(FlashMode.off);
        } catch (e) {
          debugPrint('Error turning off flash (safe to ignore): $e');
        }
      }
      
      await _controller?.dispose();
      await _intensityController?.close();
      
      _controller = null;
      _intensityController = null;
      debugPrint('Camera disposed');
    } catch (e) {
      debugPrint('Camera disposal error (safe to ignore): $e');
      // Clean up anyway
      _controller = null;
      _intensityController = null;
    }
  }

  // Ensure flash is on (iOS may turn it off due to heat/battery)
  Future<void> ensureFlashOn() async {
    try {
      if (_controller?.value.isInitialized == true) {
        await _controller?.setFlashMode(FlashMode.torch);
      }
    } catch (e) {
      debugPrint('Failed to re-enable flash: $e');
    }
  }

  CameraController? get controller => _controller;
}
