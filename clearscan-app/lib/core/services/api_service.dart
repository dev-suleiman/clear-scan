import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';
import '../../models/assessment_result.dart';
import '../../models/enhancement_result.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final bool isOfflineError;

  const ApiException({
    this.statusCode,
    required this.message,
    this.isOfflineError = false,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  late final Dio _dio;

  ApiService({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    const delays = [1, 2, 4];
    for (int attempt = 0; attempt <= delays.length; attempt++) {
      try {
        return await fn();
      } on DioException catch (e) {
        if (attempt == delays.length) {
          throw _toDomain(e);
        }
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          await Future.delayed(Duration(seconds: delays[attempt]));
        } else {
          throw _toDomain(e);
        }
      }
    }
    throw const ApiException(message: 'Max retries exceeded');
  }

  ApiException _toDomain(DioException e) {
    final offline = e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout;
    return ApiException(
      statusCode: e.response?.statusCode,
      message: e.response?.data?['detail']?.toString() ??
          e.message ??
          'Network error',
      isOfflineError: offline,
    );
  }

  Future<AssessmentResult> assess(File image) => _withRetry(() async {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(image.path,
              filename: 'xray.png'),
        });
        final r = await _dio.post(ApiEndpoints.assess, data: form);
        return AssessmentResult.fromJson(r.data as Map<String, dynamic>);
      });

  Future<EnhancementResult> enhanceClahe(File image) =>
      _withRetry(() async {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(image.path,
              filename: 'xray.png'),
        });
        final r =
            await _dio.post(ApiEndpoints.enhanceClahe, data: form);
        return EnhancementResult.fromJson(r.data as Map<String, dynamic>);
      });

  Future<EnhancementResult> enhanceCnn(File image) =>
      _withRetry(() async {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(image.path,
              filename: 'xray.png'),
        });
        final r = await _dio.post(ApiEndpoints.enhanceCnn, data: form);
        return EnhancementResult.fromJson(r.data as Map<String, dynamic>);
      });

  Future<EnhancementResult> compare(File image) =>
      _withRetry(() async {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(image.path,
              filename: 'xray.png'),
        });
        final r = await _dio.post(ApiEndpoints.compare, data: form);
        return EnhancementResult.fromJson(r.data as Map<String, dynamic>);
      });
}

/// Backend base URL, seeded from [ApiEndpoints.baseUrl] and overridden at
/// startup / from Settings with the user's persisted `backend_url` value.
final backendUrlProvider = StateProvider<String>((ref) => ApiEndpoints.baseUrl);

final apiServiceProvider = Provider<ApiService>((ref) {
  final baseUrl = ref.watch(backendUrlProvider);
  return ApiService(baseUrl: baseUrl);
});
