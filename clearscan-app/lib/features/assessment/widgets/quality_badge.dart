import 'package:flutter/material.dart';
import '../../../models/assessment_result.dart';

class QualityBadge extends StatelessWidget {
  final AssessmentResult result;
  final bool animated;

  const QualityBadge({
    super.key,
    required this.result,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: result.qualityBgColor,
        border: Border.all(color: result.qualityColor, width: 1.5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(result.qualityIcon, size: 26, color: result.qualityColor),
              const SizedBox(width: 8),
              Text(
                '${result.qualityClass.toUpperCase()} QUALITY',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: result.qualityColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${(result.confidence * 100).toStringAsFixed(0)}% confident',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: result.qualityColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );

    if (!animated) return badge;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: const ElasticOutCurve(0.8),
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: badge,
    );
  }
}
