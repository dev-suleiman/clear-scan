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

  /// Converts a raw JSON map to `Map<String, double>`, dropping any entry
  /// whose value is missing/null/negative-sentinel instead of crashing or
  /// keeping a fake number — absence means "not computed for this call".
  static Map<String, double> _numMap(Map<String, dynamic>? m,
      {Iterable<String>? keys}) {
    if (m == null) return {};
    final out = <String, double>{};
    for (final key in keys ?? m.keys) {
      final v = (m[key] as num?)?.toDouble();
      if (v != null) out[key] = v;
    }
    return out;
  }

  factory EnhancementResult.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('winning_image_b64')) {
      final winner = json['winner'] as String? ?? 'clahe';
      final clahe = (json['clahe_result'] as Map<String, dynamic>?) ?? {};
      final cnn = (json['cnn_result'] as Map<String, dynamic>?) ?? {};
      final winnerMetrics = winner == 'cnn' ? cnn : clahe;
      const refKeys = ['ssim', 'psnr'];

      return EnhancementResult(
        enhancedImageB64: json['winning_image_b64'] as String? ?? '',
        method: winner,
        beforeMetrics: _numMap(clahe, keys: refKeys),
        afterMetrics: _numMap(winnerMetrics, keys: refKeys),
        processingTimeMs:
            (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
        winner: winner,
        compositeScores: (json['composite_scores'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
        fallbackReason: json['fallback_reason'] as String?,
      );
    }

    return EnhancementResult(
      enhancedImageB64: json['enhanced_image_b64'] as String? ?? '',
      method: json['method'] as String? ?? 'clahe',
      beforeMetrics: _numMap(json['before_metrics'] as Map<String, dynamic>?),
      afterMetrics: _numMap(json['after_metrics'] as Map<String, dynamic>?),
      processingTimeMs: (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      winner: json['winner'] as String?,
      compositeScores: (json['composite_scores'] as Map<String, dynamic>?)
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

  double? get ssimBefore => beforeMetrics['ssim'];
  double? get ssimAfter => afterMetrics['ssim'];
  double? get psnrBefore => beforeMetrics['psnr'];
  double? get psnrAfter => afterMetrics['psnr'];
}
