import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TFLiteService {
  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    return {
      'quality_class': 'Unknown',
      'confidence': 0.0,
      'error': 'Model unavailable — using online mode',
    };
  }
}

final tfliteServiceProvider = Provider<TFLiteService>((ref) => TFLiteService());
