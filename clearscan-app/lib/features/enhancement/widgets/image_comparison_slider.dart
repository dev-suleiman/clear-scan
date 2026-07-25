import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ImageComparisonSlider extends StatefulWidget {
  final ImageProvider originalImage;
  final ImageProvider enhancedImage;
  final double height;

  const ImageComparisonSlider({
    super.key,
    required this.originalImage,
    required this.enhancedImage,
    this.height = 300,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider>
    with SingleTickerProviderStateMixin {
  double _position = 0.5;
  late AnimationController _hintCtrl;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Slide hint: 50% → 35% → 50%
    _hintCtrl.addListener(() {
      final t = _hintCtrl.value;
      final tri = t < 0.5 ? t * 2 : (1 - t) * 2;
      setState(() => _position = 0.5 - tri * 0.15);
    });
    _hintCtrl.forward();
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  void _onDrag(DragUpdateDetails d, BoxConstraints constraints) {
    _hintCtrl.stop();
    setState(() {
      _position = (_position + d.delta.dx / constraints.maxWidth)
          .clamp(0.02, 0.98);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDrag(d, constraints),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                children: [
                  // Enhanced (right, full)
                  Positioned.fill(
                    child: Image(
                      image: widget.enhancedImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Original (left, clipped)
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    width: w * _position,
                    child: ClipRect(
                      child: SizedBox(
                        width: w,
                        child: Image(
                          image: widget.originalImage,
                          fit: BoxFit.cover,
                          width: w,
                        ),
                      ),
                    ),
                  ),
                  // Labels
                  Positioned(
                    left: 10, bottom: 10,
                    child: _Label('Original',
                        color: Colors.black.withValues(alpha: 0.5)),
                  ),
                  Positioned(
                    right: 10, bottom: 10,
                    child: _Label('Enhanced',
                        color: AppColors.primary.withValues(alpha: 0.85)),
                  ),
                  // Divider line
                  Positioned(
                    left: w * _position - 1.5,
                    top: 0, bottom: 0,
                    child: Container(
                      width: 3,
                      color: AppColors.primary,
                      alignment: Alignment.center,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(
                            color: Color(0x4D000000), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(100)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
