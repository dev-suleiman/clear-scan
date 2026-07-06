import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _Slide1(onSkip: _finish, onNext: _next),
              _Slide2(onSkip: _finish, onNext: _next),
              _Slide3(onStart: _finish),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared bottom nav row ────────────────────────────────────
class _OnbNav extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _OnbNav({required this.onSkip, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 46),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onSkip,
            child: Text('Skip',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Next'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dots indicator ───────────────────────────────────────────
class _Dots extends StatelessWidget {
  final int active;
  final bool onDark;

  const _Dots({required this.active, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final activeColor = onDark ? Colors.white : AppColors.primary;
    final inactiveColor =
        onDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFFCBD5E1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}

// ── X-Ray texture widget ─────────────────────────────────────
class _XRayTexture extends StatelessWidget {
  const _XRayTexture();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0F12),
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.2,
          colors: [Color(0x4DCED6DE), Color(0x00000000)],
        ),
      ),
      child: Stack(
        children: [
          // Lung fields
          Positioned.fill(
            child: CustomPaint(painter: _XRayPainter()),
          ),
        ],
      ),
    );
  }
}

class _XRayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Left lung
    paint.color = const Color(0x8C282830);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.3, size.height * 0.54),
          width: size.width * 0.3,
          height: size.height * 0.42),
      paint,
    );

    // Right lung
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.7, size.height * 0.54),
          width: size.width * 0.3,
          height: size.height * 0.42),
      paint,
    );

    // Spine
    paint.color = const Color(0x6BD6E0E8);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.56),
          width: size.width * 0.16,
          height: size.height * 0.64),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Slide 1: Know Before You Read ───────────────────────────
class _Slide1 extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _Slide1({required this.onSkip, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blue gradient top half
        Positioned(
          top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1565C0), Color(0xFF2D7DD2),
                  Color(0xFFF8FAFB)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const _Dots(active: 0, onDark: true),
              const SizedBox(height: 8),
              // X-ray card
              Expanded(
                child: Center(
                  child: Container(
                    width: 210, height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 40, offset: const Offset(0, 18),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          const Positioned.fill(child: _XRayTexture()),
                          // Scan lines
                          ...[0.28, 0.50, 0.72].map((t) => Positioned(
                            left: 0, right: 0,
                            top: 250 * t - 8,
                            child: Container(height: 2,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                boxShadow: [BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                )],
                              ),
                            ),
                          )),
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.good,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('GOOD',
                                style: TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text('Know Before You Read',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: 10),
                    Text(
                      'ClearScan instantly analyses your chest X-ray images for sharpness, contrast, noise, and exposure — so you never miss a quality issue.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OnbNav(onSkip: onSkip, onNext: onNext),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Slide 2: Works Anywhere ──────────────────────────────────
class _Slide2 extends StatelessWidget {
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _Slide2({required this.onSkip, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _Dots(active: 1),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniPhoneCard(
                    variant: 'online',
                    icon: Icons.wifi_rounded,
                    iconColor: AppColors.good,
                    dotColor: AppColors.good,
                    label: 'Online\nCNN Mode',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.sync_alt_rounded,
                        color: AppColors.textSecondary),
                  ),
                  _MiniPhoneCard(
                    variant: 'offline',
                    icon: Icons.wifi_off_rounded,
                    iconColor: AppColors.fair,
                    dotColor: AppColors.fair,
                    label: 'Offline\nCLAHE Mode',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text('Works Anywhere',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayMedium),
                const SizedBox(height: 10),
                Text(
                  'Full AI-powered CNN analysis when connected. Automatic CLAHE enhancement and on-device quality assessment when offline. No internet? No problem.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OnbNav(onSkip: onSkip, onNext: onNext),
        ],
      ),
    );
  }
}

class _MiniPhoneCard extends StatelessWidget {
  final String variant;
  final IconData icon;
  final Color iconColor;
  final Color dotColor;
  final String label;

  const _MiniPhoneCard({
    required this.variant,
    required this.icon,
    required this.iconColor,
    required this.dotColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 90,
              child: Stack(
                children: [
                  const Positioned.fill(child: _XRayTexture()),
                  if (variant == 'offline')
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 5),
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Slide 3: Enhance & Report ────────────────────────────────
class _Slide3 extends StatelessWidget {
  final VoidCallback onStart;

  const _Slide3({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _Dots(active: 2),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Before/after comparison preview
                  SizedBox(
                    width: 230, height: 230,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          const Positioned.fill(child: _XRayTexture()),
                          // Poor overlay on left
                          Positioned(
                            left: 0, top: 0, bottom: 0, width: 115,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                          // Labels
                          Positioned(
                            top: 10, left: 10,
                            child: _QLabel('POOR', AppColors.poor),
                          ),
                          Positioned(
                            top: 10, right: 10,
                            child: _QLabel('GOOD', AppColors.good),
                          ),
                          // Divider
                          Positioned(
                            left: 112, top: 0, bottom: 0,
                            child: Container(
                              width: 3,
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Container(
                                width: 34, height: 34,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: Color(0x4D000000),
                                    blurRadius: 8,
                                  )],
                                ),
                                child: const Icon(Icons.swap_horiz_rounded,
                                    color: AppColors.primary, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MetaChip(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'PDF Report'),
                      const SizedBox(width: 8),
                      _MetaChip(
                          icon: Icons.image_rounded, label: 'Save to Gallery'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Text('Enhance & Report',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayMedium),
                const SizedBox(height: 10),
                Text(
                  'Improve degraded images with our hybrid pipeline, compare enhancement methods, and export professional PDF reports for clinical records.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 46),
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              child: Text('Get Started',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _QLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(7)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlue,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primary,
                      fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
