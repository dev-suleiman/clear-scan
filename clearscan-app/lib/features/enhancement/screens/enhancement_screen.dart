import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../models/assessment_result.dart';
import '../../../models/enhancement_result.dart';
import '../../../providers/enhancement_provider.dart';
import '../widgets/image_comparison_slider.dart';

class EnhancementScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final AssessmentResult assessmentResult;

  const EnhancementScreen({
    super.key,
    required this.imageFile,
    required this.assessmentResult,
  });

  @override
  ConsumerState<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends ConsumerState<EnhancementScreen> {
  EnhancementMode _mode = EnhancementMode.best;
  File? _enhancedFile;
  Uint8List? _enhancedBytes;
  String? _extractedB64;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndEnhance());
  }

  Future<void> _initAndEnhance() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _mode = (prefs.getBool('prefer_cnn') ?? true)
          ? EnhancementMode.best
          : EnhancementMode.clahe);
    }
    await _runEnhance();
  }

  Future<void> _runEnhance() async {
    await ref.read(enhancementProvider.notifier).enhance(
          widget.imageFile,
          mode: _mode,
        );
    _extractEnhancedFile();
  }

  void _extractEnhancedFile() {
    final result = ref.read(enhancementProvider).valueOrNull;
    final b64 = result?.enhancedImageB64;
    if (b64 == _extractedB64) return; // already up to date, avoid rebuild loop
    _extractedB64 = b64;

    if (b64 == null || b64.isEmpty) {
      setState(() {
        _enhancedBytes = null;
        _enhancedFile = widget.imageFile;
      });
      return;
    }
    try {
      final bytes = base64Decode(b64);
      setState(() {
        _enhancedBytes = bytes;
        _enhancedFile = null; // lazily written to disk only if the user saves
      });
    } catch (_) {
      setState(() {
        _enhancedBytes = null;
        _enhancedFile = widget.imageFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enhState = ref.watch(enhancementProvider);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // AppBar
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.divider, width: 1)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text('Image Enhancement',
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
                  // Seg toggle
                  _buildSegToggle(isOnline),
                  const SizedBox(height: 16),

                  // Content
                  enhState.when(
                    data: (result) {
                      if (result == null) return const SizedBox();
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _extractEnhancedFile());
                      final enhancedImage = _enhancedBytes != null
                          ? MemoryImage(_enhancedBytes!)
                          : FileImage(_enhancedFile ?? widget.imageFile)
                              as ImageProvider;
                      return Column(
                        children: [
                          ImageComparisonSlider(
                            originalImage: FileImage(widget.imageFile),
                            enhancedImage: enhancedImage,
                          ),
                          const SizedBox(height: 16),
                          _MetricsRow(result: result),
                          if (result.winner != null &&
                              isOnline &&
                              _mode == EnhancementMode.best) ...[
                            const SizedBox(height: 16),
                            _WinnerCard(result: result),
                          ],
                        ],
                      );
                    },
                    loading: () => _buildLoading(),
                    error: (e, _) => _ErrorCard(
                      message: e.toString(),
                      onRetry: _runEnhance,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom actions
          enhState.when(
            data: (result) {
              if (result == null) return const SizedBox();
              return Container(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        _ActionIcon(
                          icon: Icons.save_alt_rounded,
                          label: 'Save',
                          onTap: () async {
                            final ef = await _getEnhancedFileForSave();
                            if (ef == null) return;
                            await Gal.putImage(ef.path);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Image saved to gallery')),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _ActionIcon(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'Report',
                          onTap: () => context.push('/results', extra: {
                            'file': widget.imageFile,
                            'assessmentResult': widget.assessmentResult,
                            'enhancementResult': result,
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.push('/results', extra: {
                              'file': widget.imageFile,
                              'assessmentResult': widget.assessmentResult,
                              'enhancementResult': result,
                            }),
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 18),
                            label: const Text('View Full Results'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(0, 44),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Future<File?> _getEnhancedFileForSave() async {
    final file = _enhancedFile;
    if (file != null) {
      return file;
    }
    final bytes = _enhancedBytes;
    if (bytes == null) {
      return null;
    }
    final tmp = await getTemporaryDirectory();
    final f = File(
        '${tmp.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.png')
      ..writeAsBytesSync(bytes);
    _enhancedFile = f;
    return f;
  }

  Widget _buildSegToggle(bool isOnline) {
    if (!isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.offline_bolt_rounded,
                size: 16, color: Color(0xFFE65100)),
            const SizedBox(width: 6),
            Text('Offline — CLAHE only',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFFE65100))),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _SegBtn(
              label: 'CLAHE',
              active: _mode == EnhancementMode.clahe,
              onTap: () {
                setState(() => _mode = EnhancementMode.clahe);
                _runEnhance();
              }),
          _SegBtn(
              label: 'CNN',
              active: _mode == EnhancementMode.cnn,
              onTap: () {
                setState(() => _mode = EnhancementMode.cnn);
                _runEnhance();
              }),
          _SegBtn(
              label: 'Best ✦',
              active: _mode == EnhancementMode.best,
              onTap: () {
                setState(() => _mode = EnhancementMode.best);
                _runEnhance();
              }),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0A0A0A),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 14),
                Text('Enhancing image…',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(
              3,
              (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                      child: Container(
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )),
        ),
      ],
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final EnhancementResult result;
  const _MetricsRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enhancement Metrics', style: AppTextStyles.titleMedium),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EnhMetric(
                  name: 'SSIM',
                  before: result.ssimBefore,
                  after: result.ssimAfter,
                  decimals: 2),
              _EnhMetric(
                  name: 'PSNR (dB)',
                  before: result.psnrBefore,
                  after: result.psnrAfter,
                  decimals: 1),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnhMetric extends StatelessWidget {
  final String name;
  final double? before;
  final double? after;
  final int decimals;
  final bool lowerIsBetter;

  const _EnhMetric({
    required this.name,
    required this.before,
    required this.after,
    required this.decimals,
    this.lowerIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = before, a = after;
    final improved =
        (b != null && a != null) ? (lowerIsBetter ? a < b : a > b) : null;
    return Column(
      children: [
        Text(name, style: AppTextStyles.caption),
        Text(b != null ? b.toStringAsFixed(decimals) : '—',
            style: AppTextStyles.bodyMedium.copyWith(
                decoration: b != null ? TextDecoration.lineThrough : null)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (improved != null)
              Icon(
                  improved
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: AppColors.good),
            Text(a != null ? a.toStringAsFixed(decimals) : '—',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.primary, fontSize: 15)),
          ],
        ),
      ],
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final EnhancementResult result;
  const _WinnerCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.compositeScores?[result.winner ?? result.method];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 28, color: Color(0xFFFFD54F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Method: ${result.winner?.toUpperCase() ?? 'CNN'} Enhanced',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  score != null
                      ? 'Composite score: ${score.toStringAsFixed(3)}'
                      : 'Composite score unavailable',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionIcon(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
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
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.poor),
          const SizedBox(height: 12),
          Text('Enhancement failed', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
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
