import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DefectChips extends StatelessWidget {
  final List<String> defects;

  const DefectChips({super.key, required this.defects});

  static IconData _iconFor(String defect) {
    final d = defect.toLowerCase();
    if (d.contains('blur') || d.contains('motion')) return Icons.blur_on_rounded;
    if (d.contains('exposure') || d.contains('under')) return Icons.brightness_low_rounded;
    if (d.contains('noise')) return Icons.grain_rounded;
    if (d.contains('contrast')) return Icons.contrast_rounded;
    if (d.contains('over')) return Icons.brightness_high_rounded;
    return Icons.warning_amber_rounded;
  }

  static String _label(String defect) {
    return defect
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final hasDefects = defects.isNotEmpty;

    return Container(
      width: double.infinity,
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
              Icon(
                hasDefects ? Icons.info_rounded : Icons.check_circle_rounded,
                size: 22,
                color: hasDefects ? AppColors.primary : AppColors.good,
              ),
              const SizedBox(width: 8),
              Text(
                hasDefects ? 'Defects Detected' : 'No Defects Detected',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasDefects)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 22, color: AppColors.good),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No defects detected — image meets diagnostic quality standards.',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: defects.map((d) => _DefectChip(
                icon: _iconFor(d),
                label: _label(d),
              )).toList(),
            ),
            if (defects.length >= 2) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  border: const Border(
                      left: BorderSide(color: AppColors.fair, width: 3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_rounded,
                        size: 20, color: Color(0xFFE65100)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This image may not meet diagnostic standards. Enhancement recommended.',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: const Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DefectChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DefectChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.amberChipBg,
        border: Border.all(color: AppColors.amberChipBorder, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.amberChipBorder),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amberChipBorder)),
        ],
      ),
    );
  }
}
