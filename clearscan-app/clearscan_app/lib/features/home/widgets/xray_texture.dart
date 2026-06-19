import 'package:flutter/material.dart';

enum XRayVariant { orig, enhanced, good, poor, fair, plain }

class XRayTexture extends StatelessWidget {
  final XRayVariant variant;

  const XRayTexture({super.key, this.variant = XRayVariant.orig});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: _filter,
      child: Container(
        color: const Color(0xFF0C0F12),
        child: CustomPaint(painter: _XRayBodyPainter()),
      ),
    );
  }

  ColorFilter get _filter {
    switch (variant) {
      case XRayVariant.orig:
        return const ColorFilter.matrix([
          0.86, 0, 0, 0, -10,
          0, 0.86, 0, 0, -10,
          0, 0, 0.86, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case XRayVariant.enhanced:
        return const ColorFilter.matrix([
          1.22, 0, 0, 0, 5,
          0, 1.22, 0, 0, 5,
          0, 0, 1.22, 0, 5,
          0, 0, 0, 1, 0,
        ]);
      case XRayVariant.good:
        return const ColorFilter.matrix([
          1.12, 0, 0, 0, 2,
          0, 1.12, 0, 0, 2,
          0, 0, 1.12, 0, 2,
          0, 0, 0, 1, 0,
        ]);
      case XRayVariant.poor:
        return const ColorFilter.matrix([
          0.72, 0, 0, 0, -15,
          0, 0.72, 0, 0, -15,
          0, 0, 0.72, 0, -15,
          0, 0, 0, 1, 0,
        ]);
      case XRayVariant.fair:
        return const ColorFilter.matrix([
          0.95, 0, 0, 0, -5,
          0, 0.95, 0, 0, -5,
          0, 0, 0.95, 0, -5,
          0, 0, 0, 1, 0,
        ]);
      case XRayVariant.plain:
        return const ColorFilter.mode(Colors.transparent, BlendMode.color);
    }
  }
}

class _XRayBodyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // Shoulder / clavicle glow
    paint.color = const Color(0x4DCED6DE);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.2),
          width: size.width * 0.78,
          height: size.height * 0.26),
      paint,
    );

    // Mediastinum / spine column
    paint.color = const Color(0x6BD6E2E8);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.56),
          width: size.width * 0.16,
          height: size.height * 0.64),
      paint,
    );

    // Left lung field (dark)
    paint.color = const Color(0x8C282830);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.3, size.height * 0.54),
          width: size.width * 0.30,
          height: size.height * 0.42),
      paint,
    );

    // Right lung field
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.7, size.height * 0.54),
          width: size.width * 0.30,
          height: size.height * 0.42),
      paint,
    );

    // Diaphragm base glow
    paint.color = const Color(0x38969098);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.86),
          width: size.width * 0.64,
          height: size.height * 0.22),
      paint,
    );

    // Vignette
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        stops: const [0.42, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(_) => false;
}
