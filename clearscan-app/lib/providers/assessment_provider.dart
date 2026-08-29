import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../core/services/tflite_service.dart';
import '../core/services/connectivity_service.dart';
import '../models/assessment_result.dart';

class AssessmentNotifier extends StateNotifier<AsyncValue<AssessmentResult?>> {
  final Ref _ref;

  AssessmentNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> assess(File image) async {
    state = const AsyncValue.loading();
    try {
      final localModelReady =
          await _ref.read(tfliteServiceProvider).ensureLoaded();
      final isOnline = _ref.read(connectivityProvider).valueOrNull ?? false;

      if (isOnline && localModelReady) {
        try {
          await _assessOnline(image);
          return;
        } on ApiException catch (e) {
          if (!e.isOfflineError) {
            rethrow;
          }
        }
      }

      await _assessOffline(image);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _assessOnline(File image) async {
    final result = await _ref.read(apiServiceProvider).assess(image);
    state = AsyncValue.data(result);
  }

  Future<void> _assessOffline(File image) async {
    final raw = await _ref.read(tfliteServiceProvider).classifyImage(image);
    final result = AssessmentResult.fromJson(raw);
    state = AsyncValue.data(result);
  }

  void reset() => state = const AsyncValue.data(null);
}

final assessmentProvider =
    StateNotifierProvider<AssessmentNotifier, AsyncValue<AssessmentResult?>>(
  (ref) => AssessmentNotifier(ref),
);
