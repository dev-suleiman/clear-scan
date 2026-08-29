import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../core/services/clahe_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/tflite_service.dart';
import '../models/enhancement_result.dart';

enum EnhancementMode { clahe, cnn, best }

class EnhancementNotifier
    extends StateNotifier<AsyncValue<EnhancementResult?>> {
  final Ref _ref;

  EnhancementNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> enhance(File image,
      {EnhancementMode mode = EnhancementMode.best}) async {
    state = const AsyncValue.loading();
    try {
      final isOnline = _ref.read(connectivityProvider).valueOrNull ?? false;
      if (isOnline) {
        final apiService = _ref.read(apiServiceProvider);
        final EnhancementResult result;
        switch (mode) {
          case EnhancementMode.best:
            result = await apiService.compare(image);
            break;
          case EnhancementMode.cnn:
            result = await apiService.enhanceCnn(image);
            break;
          case EnhancementMode.clahe:
            result = await apiService.enhanceClahe(image);
            break;
        }
        state = AsyncValue.data(result);
      } else {
        await _enhanceOffline(image);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _enhanceOffline(File image) async {
    final enhancedFile =
        await _ref.read(claheServiceProvider).enhanceImage(image);
    final bytes = await enhancedFile.readAsBytes();

    final metrics = _ref.read(tfliteServiceProvider).computeReferenceMetrics(
          image,
          enhancedFile,
        );

    final result = EnhancementResult(
      enhancedImageB64: base64Encode(bytes),
      method: 'clahe',
      beforeMetrics: {'ssim': 1.0, 'psnr': 1000.0},
      afterMetrics: metrics,
      processingTimeMs: 0,
      winner: 'clahe',
      fallbackReason: 'offline',
    );
    state = AsyncValue.data(result);
  }

  void reset() => state = const AsyncValue.data(null);
}

final enhancementProvider =
    StateNotifierProvider<EnhancementNotifier, AsyncValue<EnhancementResult?>>(
  (ref) => EnhancementNotifier(ref),
);
