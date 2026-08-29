import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/assessment_result.dart';
import '../../../models/enhancement_result.dart';

/// Formats a possibly-absent metric (backend didn't compute it for this call)
/// instead of crashing or showing a fabricated number.
String _fmt(double? v, int decimals) =>
    v == null ? '—' : v.toStringAsFixed(decimals);

/// `before`/`after` delta as "+0.12" style text, or "—" if either is absent.
String _fmtDelta(double? before, double? after, int decimals,
    {required String prefix}) {
  if (before == null || after == null) return '—';
  return '$prefix${(after - before).abs().toStringAsFixed(decimals)}';
}

/// Null if there's no baseline to compare against.
bool? _improved(double? before, double? after, {bool lowerIsBetter = false}) {
  if (before == null || after == null) return null;
  return lowerIsBetter ? after < before : after > before;
}

class ResultsScreen extends StatefulWidget {
  final File imageFile;
  final AssessmentResult assessmentResult;
  final EnhancementResult enhancementResult;

  const ResultsScreen({
    super.key,
    required this.imageFile,
    required this.assessmentResult,
    required this.enhancementResult,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkCtrl;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(
        const Duration(milliseconds: 80), () => _checkCtrl.forward());
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now());

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
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text('Analysis Complete',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => _shareReport(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  // Check animation header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: [
                        _AnimatedCheck(controller: _checkCtrl),
                        const SizedBox(height: 10),
                        Text('Analysis Complete',
                            style: AppTextStyles.displayMedium),
                        const SizedBox(height: 2),
                        Text(date, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),

                  // Before/After thumbs
                  Row(
                    children: [
                      Expanded(
                        child: _ThumbLabeled(
                            file: widget.imageFile, label: 'Before'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ThumbLabeled(
                          file: widget.imageFile,
                          label: 'After',
                          tinted:
                              widget.enhancementResult.enhancedImageB64.isEmpty,
                          bytes: widget
                                  .enhancementResult.enhancedImageB64.isNotEmpty
                              ? base64Decode(
                                  widget.enhancementResult.enhancedImageB64)
                              : null,
                        ),
                      ),
                    ],
                  ),

                  // Metrics table
                  const SizedBox(height: 18),
                  _MetricsTable(
                    assessment: widget.assessmentResult,
                    enhancement: widget.enhancementResult,
                  ),

                  // Method performance (only meaningful when both methods
                  // were actually run, i.e. the "Best Result" compare flow)
                  if (widget.enhancementResult.compositeScores != null) ...[
                    const SizedBox(height: 16),
                    _MethodPerformance(result: widget.enhancementResult),
                  ],

                  // Winner card
                  const SizedBox(height: 16),
                  _WinnerCard(result: widget.enhancementResult),

                  // Export button
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => _showExportSheet(context),
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Export Report'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExportSheet(
        onSaveGallery: _saveToGallery,
        onExportPdf: _exportPdf,
        onCopyMetrics: _copyMetrics,
      ),
    );
  }

  Future<void> _saveToGallery() async {
    await Gal.putImage(widget.imageFile.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Images saved to gallery')));
    }
  }

  Future<void> _exportPdf() async {
    Navigator.pop(context);
    final doc = pw.Document();
    final a = widget.assessmentResult;
    final e = widget.enhancementResult;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ClearScan Report',
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(DateFormat('MMMM d, yyyy – h:mm a').format(DateTime.now()),
              style:
                  const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.Divider(height: 24),
          pw.Text('Quality Assessment',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Quality Class: ${a.qualityClass}'),
          pw.Text('Confidence: ${(a.confidence * 100).toStringAsFixed(0)}%'),
          if (a.defects.isNotEmpty) pw.Text('Defects: ${a.defects.join(", ")}'),
          pw.Divider(height: 24),
          pw.Text('Enhancement Results',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Method: ${e.method.toUpperCase()}'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: ['Metric', 'Before', 'After', 'Δ']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11)),
                        ))
                    .toList(),
              ),
              ...[
                [
                  'SSIM',
                  _fmt(e.ssimBefore, 2),
                  _fmt(e.ssimAfter, 2),
                  _fmtDelta(e.ssimBefore, e.ssimAfter, 2, prefix: '+')
                ],
                [
                  'PSNR (dB)',
                  _fmt(e.psnrBefore, 1),
                  _fmt(e.psnrAfter, 1),
                  _fmtDelta(e.psnrBefore, e.psnrAfter, 1, prefix: '+')
                ],
              ].map((row) => pw.TableRow(
                    children: row
                        .map((cell) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(cell,
                                  style: const pw.TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                  )),
            ],
          ),
          pw.Spacer(),
          pw.Divider(),
          pw.Text('Generated by ClearScan — KNUST CS FYP 2025/26',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        ],
      ),
    ));

    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/clearscan_report.pdf')
      ..writeAsBytesSync(await doc.save());
    await Share.shareXFiles([XFile(f.path)], subject: 'ClearScan Report');
  }

  void _copyMetrics() {
    Navigator.pop(context);
    final a = widget.assessmentResult;
    final e = widget.enhancementResult;
    final text =
        '''ClearScan Report — ${DateFormat('MMM d, yyyy').format(DateTime.now())}
Quality: ${a.qualityClass} (${(a.confidence * 100).toStringAsFixed(0)}%)
Defects: ${a.defects.isEmpty ? 'None' : a.defects.join(', ')}
SSIM: ${_fmt(e.ssimBefore, 2)} → ${_fmt(e.ssimAfter, 2)}
PSNR: ${_fmt(e.psnrBefore, 1)} → ${_fmt(e.psnrAfter, 1)} dB''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metrics copied to clipboard')));
  }

  Future<void> _shareReport() async {
    await Share.share(
        'ClearScan Analysis: ${widget.assessmentResult.qualityClass} quality X-ray.');
  }
}

class _AnimatedCheck extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedCheck({required this.controller});

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    const r = 28.0;
    final c = 2 * 3.14159 * r;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final circleProgress = controller.value;
        final checkProgress =
            controller.value > 0.57 ? (controller.value - 0.57) / 0.43 : 0.0;
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CheckPainter(
              circleProgress: circleProgress,
              checkProgress: checkProgress,
              circumference: c,
              color: AppColors.good,
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final double circumference;
  final Color color;

  const _CheckPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.circumference,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Circle
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: 28),
      -3.14159 / 2,
      2 * 3.14159 * circleProgress,
      false,
      paint,
    );

    // Check mark
    if (checkProgress > 0) {
      final p = Path();
      p.moveTo(cx - 13, cy);
      p.lineTo(cx - 4, cy + 9);
      p.lineTo(cx + 17, cy - 10);
      final metrics = p.computeMetrics().first;
      final extracted = metrics.extractPath(0, metrics.length * checkProgress);
      canvas.drawPath(extracted, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circleProgress != circleProgress ||
      old.checkProgress != checkProgress;
}

class _ThumbLabeled extends StatelessWidget {
  final File file;
  final String label;
  final bool tinted;
  final Uint8List? bytes;

  const _ThumbLabeled(
      {required this.file,
      required this.label,
      this.tinted = false,
      this.bytes});

  @override
  Widget build(BuildContext context) {
    final image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover)
        : Image.file(file, fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            Positioned.fill(
              child: bytes != null
                  ? image
                  : ColorFiltered(
                      colorFilter: tinted
                          ? const ColorFilter.matrix([
                              1.22,
                              0,
                              0,
                              0,
                              5,
                              0,
                              1.22,
                              0,
                              0,
                              5,
                              0,
                              0,
                              1.22,
                              0,
                              5,
                              0,
                              0,
                              0,
                              1,
                              0
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.color),
                      child: image,
                    ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsTable extends StatelessWidget {
  final AssessmentResult assessment;
  final EnhancementResult enhancement;

  const _MetricsTable({required this.assessment, required this.enhancement});

  @override
  Widget build(BuildContext context) {
    final e = enhancement;
    final rows = [
      [
        'SSIM',
        _fmt(e.ssimBefore, 2),
        _fmt(e.ssimAfter, 2),
        _fmtDelta(e.ssimBefore, e.ssimAfter, 2, prefix: '+'),
        _improved(e.ssimBefore, e.ssimAfter)
      ],
      [
        'PSNR',
        _fmt(e.psnrBefore, 1),
        _fmt(e.psnrAfter, 1),
        '${_fmtDelta(e.psnrBefore, e.psnrAfter, 1, prefix: '+')}'
            '${e.psnrBefore != null && e.psnrAfter != null ? ' dB' : ''}',
        _improved(e.psnrBefore, e.psnrAfter)
      ],
    ];

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded,
                    size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Metrics Comparison', style: AppTextStyles.titleMedium),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF0F4F8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Metric', 'Original', 'Enhanced', 'Change']
                  .asMap()
                  .entries
                  .map((e) => Expanded(
                        flex: e.key == 0 ? 3 : 2,
                        child: Text(e.value,
                            textAlign:
                                e.key == 0 ? TextAlign.left : TextAlign.right,
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ))
                  .toList(),
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final improved = row[4] as bool?;
            return Container(
              color: i.isOdd ? const Color(0xFFF8FAFB) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(row[0] as String,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w500))),
                  Expanded(
                      flex: 2,
                      child: Text(row[1] as String,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodyMedium)),
                  Expanded(
                      flex: 2,
                      child: Text(row[2] as String,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 2,
                      child: Text(row[3] as String,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: improved == null
                                  ? AppColors.textSecondary
                                  : (improved
                                      ? AppColors.good
                                      : AppColors.poor)))),
                ],
              ),
            );
          }),
          // Quality class row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider))),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Quality Class',
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w500))),
                Expanded(
                  flex: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _QPill(assessment.qualityClass, assessment.qualityColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QPill extends StatelessWidget {
  final String text;
  final Color color;
  const _QPill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _MethodPerformance extends StatefulWidget {
  final EnhancementResult result;
  const _MethodPerformance({required this.result});

  @override
  State<_MethodPerformance> createState() => _MethodPerformanceState();
}

class _MethodPerformanceState extends State<_MethodPerformance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(const Duration(milliseconds: 80), () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  size: 22, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Method Performance', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          _PerfBar(
              label: 'CNN',
              value: widget.result.compositeScores?['cnn'] ?? 0.0,
              color: AppColors.primary,
              ctrl: _ctrl),
          _PerfBar(
              label: 'CLAHE',
              value: widget.result.compositeScores?['clahe'] ?? 0.0,
              color: AppColors.accent,
              ctrl: _ctrl),
        ],
      ),
    );
  }
}

class _PerfBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final AnimationController ctrl;

  const _PerfBar({
    required this.label,
    required this.value,
    required this.color,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(label,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                final w = Tween<double>(begin: 0, end: clamped).evaluate(
                    CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: w,
                    minHeight: 22,
                    backgroundColor: const Color(0xFFEEF2F6),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(clamped.toStringAsFixed(2),
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final EnhancementResult result;
  const _WinnerCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final method = result.winner ?? result.method;
    final score = result.compositeScores?[result.winner ?? result.method];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            const Border(left: BorderSide(color: AppColors.primary, width: 4)),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 32, color: Color(0xFFFFD54F)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Best Enhancement Method',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${method.toUpperCase()} Enhanced',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.primary),
                ),
                Text(
                  score != null
                      ? 'Composite Score: ${score.toStringAsFixed(3)}'
                      : 'Composite score unavailable',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportSheet extends StatelessWidget {
  final VoidCallback onSaveGallery;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyMetrics;

  const _ExportSheet({
    required this.onSaveGallery,
    required this.onExportPdf,
    required this.onCopyMetrics,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(100)),
            ),
            Text('Export Options',
                style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _ExportTile(
              icon: Icons.photo_library_rounded,
              iconColor: AppColors.primary,
              title: 'Save to Gallery',
              sub: 'Save original and enhanced images to your device',
              onTap: () {
                Navigator.pop(context);
                onSaveGallery();
              },
            ),
            const SizedBox(height: 8),
            _ExportTile(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: AppColors.poor,
              title: 'Export PDF Report',
              sub: 'Professional clinical report with all metrics and images',
              onTap: onExportPdf,
            ),
            const SizedBox(height: 8),
            _ExportTile(
              icon: Icons.content_copy_rounded,
              iconColor: AppColors.textSecondary,
              title: 'Copy Metrics to Clipboard',
              sub: 'Copy all quality metrics as formatted text',
              onTap: onCopyMetrics,
            ),
            const Divider(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(sub, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}
