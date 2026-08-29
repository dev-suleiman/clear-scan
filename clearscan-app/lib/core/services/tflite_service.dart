import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_litert/flutter_litert.dart';

class TFLiteService {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  static const List<String> _classNames = ['Good', 'Fair', 'Poor'];
  static const String _modelAssetPath =
      'assets/models/quality_classifier.tflite';
  static const String _modelAssetFallbackPath =
      'models/quality_classifier.tflite';

  bool get isAvailable => _interpreter != null && _isLoaded;

  Future<bool> ensureLoaded() async {
    if (_isLoaded && _interpreter != null) return true;

    try {
      final assetData = await rootBundle.load(_modelAssetPath);
      final modelBytes = assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );
      _interpreter = await Interpreter.fromBuffer(modelBytes);
      _isLoaded = true;
      return true;
    } catch (_) {
      try {
        _interpreter = await Interpreter.fromAsset(_modelAssetFallbackPath);
        _isLoaded = true;
        return true;
      } catch (_) {
        _interpreter = null;
        _isLoaded = false;
        return false;
      }
    }
  }

  Map<String, double> computeQualityMetrics(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) {
      return const {
        'laplacian_variance': 0.0,
        'rms_contrast': 0.0,
        'shannon_entropy': 0.0,
        'histogram_spread': 0.0,
        'noise_variance': 0.0,
      };
    }

    final grayscale = img.grayscale(image);
    final pixels = <double>[];
    final width = grayscale.width;
    final height = grayscale.height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        pixels.add(grayscale.getPixel(x, y).r.toDouble());
      }
    }

    if (pixels.isEmpty) {
      return const {
        'laplacian_variance': 0.0,
        'rms_contrast': 0.0,
        'shannon_entropy': 0.0,
        'histogram_spread': 0.0,
        'noise_variance': 0.0,
      };
    }

    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    final variance =
        pixels.fold<double>(0.0, (sum, p) => sum + (p - mean) * (p - mean)) /
            pixels.length;
    final rmsContrast = sqrt(variance) * 1.0;

    final laplacianValues = <double>[];
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = grayscale.getPixel(x, y).r.toDouble();
        final up = grayscale.getPixel(x, y - 1).r.toDouble();
        final down = grayscale.getPixel(x, y + 1).r.toDouble();
        final left = grayscale.getPixel(x - 1, y).r.toDouble();
        final right = grayscale.getPixel(x + 1, y).r.toDouble();
        final lap = 4 * center - up - down - left - right;
        laplacianValues.add(lap * lap);
      }
    }
    final laplacianVariance = laplacianValues.isNotEmpty
        ? laplacianValues.reduce((a, b) => a + b) / laplacianValues.length
        : 0.0;

    final hist = List<double>.filled(256, 0.0);
    for (final p in pixels) {
      final idx = p.round().clamp(0, 255);
      hist[idx] += 1;
    }
    final total = hist.fold<double>(0.0, (sum, v) => sum + v);
    final entropy = hist.fold<double>(0.0, (sum, f) {
      if (f <= 0) return sum;
      final p = f / total;
      return sum - (p * log(p) / ln2);
    });

    final sorted = pixels.toList()..sort();
    final p05 = sorted[(sorted.length * 0.05).floor()].clamp(0.0, 255.0);
    final p95 = sorted[(sorted.length * 0.95).floor()].clamp(0.0, 255.0);
    final histogramSpread = p95 - p05;

    final blurred = img.gaussianBlur(grayscale, radius: 1);
    final noiseValues = <double>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final original = grayscale.getPixel(x, y).r.toDouble();
        final smooth = blurred.getPixel(x, y).r.toDouble();
        noiseValues.add((original - smooth) * (original - smooth));
      }
    }
    final noiseVariance = noiseValues.isNotEmpty
        ? noiseValues.reduce((a, b) => a + b) / noiseValues.length
        : 0.0;

    return {
      'laplacian_variance': laplacianVariance,
      'rms_contrast': rmsContrast,
      'shannon_entropy': entropy,
      'histogram_spread': histogramSpread,
      'noise_variance': noiseVariance,
    };
  }

  Map<String, double> computeReferenceMetrics(
      File originalFile, File enhancedFile) {
    final originalBytes = originalFile.readAsBytesSync();
    final enhancedBytes = enhancedFile.readAsBytesSync();
    final originalImage = img.decodeImage(originalBytes);
    final enhancedImage = img.decodeImage(enhancedBytes);

    if (originalImage == null || enhancedImage == null) {
      return {'ssim': 0.0, 'psnr': 0.0};
    }

    final originalGray = img.grayscale(originalImage);
    final enhancedGray = img.grayscale(enhancedImage);
    final w = min(originalGray.width, enhancedGray.width);
    final h = min(originalGray.height, enhancedGray.height);

    double mse = 0.0;
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;
    double sumY2 = 0.0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final a = originalGray.getPixel(x, y).r.toDouble();
        final b = enhancedGray.getPixel(x, y).r.toDouble();
        mse += (a - b) * (a - b);
        sumX += a;
        sumY += b;
        sumXY += a * b;
        sumX2 += a * a;
        sumY2 += b * b;
      }
    }

    final totalPixels = w * h;
    final meanMse = mse / totalPixels;
    final psnr =
        meanMse > 0.0 ? 10.0 * log((255.0 * 255.0) / meanMse) / ln10 : 1000.0;

    final meanX = sumX / totalPixels;
    final meanY = sumY / totalPixels;
    final varianceX = (sumX2 / totalPixels) - (meanX * meanX);
    final varianceY = (sumY2 / totalPixels) - (meanY * meanY);
    final covariance = (sumXY / totalPixels) - (meanX * meanY);
    final c1 = (0.01 * 255.0) * (0.01 * 255.0);
    final c2 = (0.03 * 255.0) * (0.03 * 255.0);
    final ssimNum = (2 * meanX * meanY + c1) * (2 * covariance + c2);
    final ssimDen =
        ((meanX * meanX) + (meanY * meanY) + c1) * (varianceX + varianceY + c2);
    final ssim = ssimDen > 0.0 ? ssimNum / ssimDen : 0.0;

    return {
      'ssim': ssim.clamp(0.0, 1.0),
      'psnr': psnr,
    };
  }

  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    final loaded = await ensureLoaded();

    if (!loaded || _interpreter == null) {
      return {
        'quality_class': 'Unknown',
        'confidence': 0.0,
        'error': 'TFLite model unavailable',
        'class_probabilities': {'Good': 0.0, 'Fair': 0.0, 'Poor': 0.0},
        'defects': <String>[],
        'metrics': const {
          'laplacian_variance': 0.0,
          'rms_contrast': 0.0,
          'shannon_entropy': 0.0,
          'histogram_spread': 0.0,
          'noise_variance': 0.0,
        },
      };
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');

      final resized = img.copyResize(image, width: 224, height: 224);
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final output = List.generate(1, (_) => List.filled(3, 0.0));
      _interpreter!.run(input, output);
      final probs = output[0];

      int maxIdx = 0;
      double maxProb = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          maxIdx = i;
        }
      }

      final qualityClass = _classNames[maxIdx];
      final defects = _deriveDefects(qualityClass);
      final metrics = computeQualityMetrics(imageFile);

      return {
        'quality_class': qualityClass,
        'confidence': maxProb,
        'class_probabilities': {
          'Good': probs[0],
          'Fair': probs[1],
          'Poor': probs[2],
        },
        'defects': defects,
        'metrics': metrics,
      };
    } catch (e) {
      return {
        'quality_class': 'Unknown',
        'confidence': 0.0,
        'error': e.toString(),
        'class_probabilities': {'Good': 0.0, 'Fair': 0.0, 'Poor': 0.0},
        'defects': <String>[],
        'metrics': const {
          'laplacian_variance': 0.0,
          'rms_contrast': 0.0,
          'shannon_entropy': 0.0,
          'histogram_spread': 0.0,
          'noise_variance': 0.0,
        },
      };
    }
  }

  List<String> _deriveDefects(String qualityClass) {
    if (qualityClass == 'Good') return [];
    if (qualityClass == 'Poor') {
      return ['motion_blur', 'underexposure', 'excessive_noise'];
    }
    return ['low_contrast'];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}

final tfliteServiceProvider = Provider<TFLiteService>((ref) => TFLiteService());
