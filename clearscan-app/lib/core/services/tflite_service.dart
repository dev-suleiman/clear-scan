import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_litert/flutter_litert.dart';
class TFLiteService {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  static const List<String> _classNames = ['Good', 'Fair', 'Poor'];

  Future<void> _loadModel() async {
    if (_isLoaded) return;
    try {
      _interpreter = await Interpreter.fromAsset(
        'models/quality_classifier.tflite',
      );
      _isLoaded = true;
    } catch (e) {
      _interpreter = null;
      _isLoaded = false;
    }
  }

  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    await _loadModel();

    if (_interpreter == null) {
      return {
        'quality_class': 'Unknown',
        'confidence': 0.0,
        'error': 'TFLite model unavailable',
        'class_probabilities': {'Good': 0.0, 'Fair': 0.0, 'Poor': 0.0},
        'defects': <String>[],
      };
    }

    try {
      // Load and decode image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');

      // Resize to 224x224
      img.Image resized = img.copyResize(image, width: 224, height: 224);

      // Convert to float32 RGB input [1, 224, 224, 3]
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

      // Output buffer [1, 3]
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

      return {
        'quality_class': qualityClass,
        'confidence': maxProb,
        'class_probabilities': {
          'Good': probs[0],
          'Fair': probs[1],
          'Poor': probs[2],
        },
        'defects': defects,
      };
    } catch (e) {
      return {
        'quality_class': 'Unknown',
        'confidence': 0.0,
        'error': e.toString(),
        'class_probabilities': {'Good': 0.0, 'Fair': 0.0, 'Poor': 0.0},
        'defects': <String>[],
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
