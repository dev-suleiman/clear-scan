import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class MetricsCard extends StatelessWidget {
  final Map<String, double> metrics;

  const MetricsCard({super.key, required this.metrics});

  static const _meta = [
    ('laplacian_variance', 'Sharpness', Icons.blur_on_rounded, 500.0, false),
    ('rms_contrast', 'Contrast', Icons.contrast_rounded, 100.0, false),
    ('shannon_entropy', 'Entropy', Icons.data_usage_rounded, 8.0, false),
    ('histogram_spread', 'Histogram Spread', Icons.tune_rounded, 255.0, false),
    ('noise_variance', 'Noise Level', Icons.grain_rounded, 0.1, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  size: 22, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Image Quality Metrics', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          ..._meta.map((m) {
            final key = m.$1;
            final label = m.$2;
            final icon = m.$3;
            final maxVal = m.$4;
            final invert = m.$5;
            final raw = metrics[key] ?? 0.0;
            final pct =
                invert ? (1 - (raw / maxVal)).clamp(0.0, 1.0) : (raw / maxVal).clamp(0.0, 1.0);
            final warn = invert ? raw > maxVal * 0.6 : raw < maxVal * 0.2;

            return _MetricRow(
              icon: icon,
              label: label,
              value: raw.toStringAsFixed(2),
              pct: pct,
              warn: warn,
            );
          }),
        ],
      ),
    );
  }
}

class _MetricRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final double pct;
  final bool warn;

  const _MetricRow({
    required this.icon, required this.label,
    required this.value, required this.pct, required this.warn,
  });

  @override
  State<_MetricRow> createState() => _MetricRowState();
}

class _MetricRowState extends State<_MetricRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0, end: widget.pct).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.warn
        ? const Color(0xFFEF9A9A)
        : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(widget.label, style: AppTextStyles.bodyLarge)),
              if (widget.warn)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(Icons.warning_rounded,
                      size: 15, color: AppColors.fair),
                ),
              Text(widget.value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.warn ? AppColors.fair : AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _anim.value,
                minHeight: 4,
                backgroundColor: AppColors.surfaceBlue,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
