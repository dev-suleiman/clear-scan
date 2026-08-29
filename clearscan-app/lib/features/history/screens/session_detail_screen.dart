import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/assessment_result.dart';
import '../../assessment/widgets/quality_badge.dart';
import '../../assessment/widgets/defect_chips.dart';

/// Read-only view of a past scan session pulled from local history —
/// no re-assessment call is made, since only the original triage result
/// (not the raw IQA metrics) is persisted to the sessions table.
class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final imagePath = session['image_path'] as String;
    final qualityClass = session['quality_class'] as String;
    final confidence = (session['confidence'] as num).toDouble();
    final defectsRaw = session['defects'] as String? ?? '';
    final defects = defectsRaw.isEmpty ? <String>[] : defectsRaw.split(',');
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(session['timestamp'] as int);
    final formatted = DateFormat('MMM d, yyyy · h:mm a').format(timestamp);
    final imageFile = File(imagePath);
    final imageExists = imageFile.existsSync();

    final result = AssessmentResult(
      qualityClass: qualityClass,
      confidence: confidence,
      classProbabilities: const {},
      defects: defects,
      metrics: const {},
      processingTimeMs: 0,
      mode: 'cached',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text('Session Details',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      color: const Color(0xFF0C0F12),
                      child: imageExists
                          ? Image.file(imageFile, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.image_not_supported_rounded,
                                  color: Colors.white54, size: 48),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(formatted, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 16),
                  QualityBadge(result: result, animated: false),
                  const SizedBox(height: 16),
                  DefectChips(defects: defects),
                  if (imageExists) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push('/enhancement', extra: {
                          'file': imageFile,
                          'assessmentResult': result,
                        }),
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        label: const Text('Enhance Image'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(0, 48),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
