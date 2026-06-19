import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class AssessmentResult {
  final String qualityClass;
  final double confidence;
  final Map<String, double> classProbabilities;
  final List<String> defects;
  final Map<String, double> metrics;
  final double processingTimeMs;
  final String mode;

  const AssessmentResult({
    required this.qualityClass,
    required this.confidence,
    required this.classProbabilities,
    required this.defects,
    required this.metrics,
    required this.processingTimeMs,
    required this.mode,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      qualityClass: json['quality_class'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      classProbabilities: (json['class_probabilities'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      defects: (json['defects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      metrics: (json['metrics'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      processingTimeMs:
          (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'quality_class': qualityClass,
        'confidence': confidence,
        'class_probabilities': classProbabilities,
        'defects': defects,
        'metrics': metrics,
        'processing_time_ms': processingTimeMs,
        'mode': mode,
      };

  Color get qualityColor {
    switch (qualityClass.toLowerCase()) {
      case 'good':
        return AppColors.good;
      case 'fair':
        return AppColors.fair;
      case 'poor':
        return AppColors.poor;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get qualityBgColor {
    switch (qualityClass.toLowerCase()) {
      case 'good':
        return AppColors.goodBg;
      case 'fair':
        return AppColors.fairBg;
      case 'poor':
        return AppColors.poorBg;
      default:
        return AppColors.surfaceBlue;
    }
  }

  IconData get qualityIcon {
    switch (qualityClass.toLowerCase()) {
      case 'good':
        return Icons.check_circle_rounded;
      case 'fair':
        return Icons.warning_rounded;
      case 'poor':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
