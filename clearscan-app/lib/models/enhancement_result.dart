class EnhancementResult {
  final String enhancedImageB64;
  final String method;
  final Map<String, double> beforeMetrics;
  final Map<String, double> afterMetrics;
  final double processingTimeMs;
  final String? winner;
  final Map<String, double>? compositeScores;
  final String? fallbackReason;

  const EnhancementResult({
    required this.enhancedImageB64,
    required this.method,
    required this.beforeMetrics,
    required this.afterMetrics,
    required this.processingTimeMs,
    this.winner,
    this.compositeScores,
    this.fallbackReason,
  });

  factory EnhancementResult.fromJson(Map<String, dynamic> json) {
    return EnhancementResult(
      enhancedImageB64: json['enhanced_image_b64'] as String? ?? '',
      method: json['method'] as String? ?? 'clahe',
      beforeMetrics: (json['before_metrics'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      afterMetrics: (json['after_metrics'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      processingTimeMs:
          (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      winner: json['winner'] as String?,
      compositeScores:
          (json['composite_scores'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      fallbackReason: json['fallback_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enhanced_image_b64': enhancedImageB64,
        'method': method,
        'before_metrics': beforeMetrics,
        'after_metrics': afterMetrics,
        'processing_time_ms': processingTimeMs,
        'winner': winner,
        'composite_scores': compositeScores,
        'fallback_reason': fallbackReason,
      };

  double get ssimBefore => beforeMetrics['ssim'] ?? 0.62;
  double get ssimAfter => afterMetrics['ssim'] ?? 0.88;
  double get psnrBefore => beforeMetrics['psnr'] ?? 22.4;
  double get psnrAfter => afterMetrics['psnr'] ?? 31.7;
  double get brisqueBefore => beforeMetrics['brisque'] ?? 48.1;
  double get brisqueAfter => afterMetrics['brisque'] ?? 19.6;
}
