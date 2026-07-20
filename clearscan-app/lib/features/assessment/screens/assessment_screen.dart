import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/database_service.dart';
import '../../../providers/assessment_provider.dart';
import '../widgets/quality_badge.dart';
import '../widgets/metrics_card.dart';
import '../widgets/defect_chips.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  final File imageFile;
  const AssessmentScreen({super.key, required this.imageFile});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assessmentProvider.notifier).assess(widget.imageFile);
    });
  }

  Future<void> _saveSession(String qualityClass, double confidence,
      List<String> defects) async {
    await DatabaseService.insertSession(
      imagePath: widget.imageFile.path,
      qualityClass: qualityClass,
      confidence: confidence,
      defects: defects,
    );
  }

  @override
  Widget build(BuildContext context) {
    final assessState = ref.watch(assessmentProvider);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? false;

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
                  border: Border(bottom:
                      BorderSide(color: AppColors.divider, width: 1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text('Quality Assessment',
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.35,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            PhotoView(
                              imageProvider: FileImage(widget.imageFile),
                              backgroundDecoration: const BoxDecoration(
                                  color: Color(0xFF0A0A0A)),
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 3,
                            ),
                            Positioned(
                              top: 10, right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.white.withValues(alpha: 0.95)
                                      : const Color(0xFFFFF8E1),
                                  border: Border.all(
                                      color: isOnline
                                          ? AppColors.primary
                                          : AppColors.fair,
                                      width: 1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOnline
                                          ? Icons.cloud_rounded
                                          : Icons.offline_bolt_rounded,
                                      size: 14,
                                      color: isOnline
                                          ? AppColors.primary
                                          : AppColors.fair,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isOnline ? 'CNN Mode' : 'Offline Mode',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isOnline
                                            ? AppColors.primary
                                            : AppColors.fair,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: assessState.when(
                      data: (result) {
                        if (result == null) return const SizedBox();
                        final shouldShowEnhanceButton =
                            result.defects.isNotEmpty ||
                            result.qualityClass.toLowerCase() == 'poor';
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _saveSession(result.qualityClass,
                              result.confidence, result.defects);
                        });
                        return Column(
                          children: [
                            AnimatedOpacity(
                              opacity: 1,
                              duration: const Duration(milliseconds: 500),
                              child: QualityBadge(result: result),
                            ),
                            const SizedBox(height: 16),
                            AnimatedSlide(
                              offset: Offset.zero,
                              duration: const Duration(milliseconds: 500),
                              child: DefectChips(defects: result.defects),
                            ),
                            const SizedBox(height: 16),
                            AnimatedSlide(
                              offset: Offset.zero,
                              duration: const Duration(milliseconds: 600),
                              child: MetricsCard(metrics: result.metrics),
                            ),
                            if (shouldShowEnhanceButton) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => context.push('/enhancement', extra: {
                                    'file': widget.imageFile,
                                    'assessmentResult': result,
                                  }),
                                  icon: const Icon(Icons.auto_fix_high_rounded,
                                      size: 18),
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
                        );
                      },
                      loading: () => _ShimmerLoading(),
                      error: (e, _) => _ErrorCard(
                        message: e.toString(),
                        onRetry: () => ref
                            .read(assessmentProvider.notifier)
                            .assess(widget.imageFile),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          assessState.when(
            data: (result) {
              if (result == null) return const SizedBox();
              final shouldShowEnhanceButton =
                  result.defects.isNotEmpty ||
                  result.qualityClass.toLowerCase() == 'poor';
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                child: shouldShowEnhanceButton
                    ? Row(
                        children: [
                          Expanded(
                            flex: 34,
                            child: OutlinedButton(
                              onPressed: () => context.go('/home'),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48)),
                              child: const Text('New Scan'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.push('/enhancement', extra: {
                                'file': widget.imageFile,
                                'assessmentResult': result,
                              }),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  size: 18),
                              label: const Text('Enhance Image'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(0, 48),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/home'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                          child: const Text('New Scan'),
                        ),
                      ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _ShimmerLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF2F4F6),
      highlightColor: const Color(0xFFE6E9ED),
      child: Column(
        children: [
          Container(height: 100, decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 14),
          Container(height: 80, decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 14),
          Container(height: 140, decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Container(height: 48, decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100)))),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 48, decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100)))),
          ]),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.poor),
          const SizedBox(height: 12),
          Text('Assessment failed', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
