import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/database_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xf = await _picker.pickImage(source: source, imageQuality: 95);
    if (xf == null || !mounted) return;
    final file = File(xf.path);
    context.push('/assessment', extra: file);
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SourceSheet(onPick: _pickImage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBarRow(isOnline: isOnline, pulseCtrl: _pulseCtrl),
          if (!isOnline)
            Container(
              color: const Color(0xFFFFF8E1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 16, color: Color(0xFFE65100)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline — CNN features unavailable. CLAHE mode active.',
                      style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFFE65100),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero greeting
                  GestureDetector(
                    onTap: _showSourceSheet,
                    child: Container(
                      height: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.surfaceBlue, Colors.white],
                          stops: [0, 0.78],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_rounded,
                              size: 32, color: AppColors.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good morning, Doctor',
                                    style: AppTextStyles.labelLarge),
                                Text('Ready to assess an X-ray?',
                                    style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.accent),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick actions
                  Text('Quick Actions',
                      style: AppTextStyles.labelMedium.copyWith(
                          letterSpacing: 1.2, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.upload_file_rounded,
                          title: 'Upload X-Ray',
                          sub: 'Choose from gallery',
                          cta: 'Select',
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.camera_alt_rounded,
                          title: 'Capture X-Ray',
                          sub: 'Use your camera',
                          cta: 'Open',
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // Recent sessions header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Sessions', style: AppTextStyles.titleMedium),
                      TextButton(
                        onPressed: () => context.push('/history'),
                        child:
                            Text('View All', style: AppTextStyles.labelLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseService.getSessions(limit: 4),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final sessions = snap.data ?? [];
                      if (sessions.isEmpty) {
                        return _EmptyRecent();
                      }
                      return Column(
                        children: sessions
                            .map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _SessionTile(session: s),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        active: 0,
        onScan: _showSourceSheet,
      ),
    );
  }
}

class _AppBarRow extends StatelessWidget {
  final bool isOnline;
  final AnimationController pulseCtrl;

  const _AppBarRow({required this.isOnline, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
          ),
          child: Row(
            children: [
              // Logo
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.document_scanner_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('ClearScan', style: AppTextStyles.titleLarge),
              ),
              // Connectivity dot
              Tooltip(
                message:
                    isOnline ? 'CNN Mode — Online' : 'CLAHE Mode — Offline',
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isOnline)
                        AnimatedBuilder(
                          animation: pulseCtrl,
                          builder: (_, __) {
                            final scale = Tween<double>(begin: 1, end: 1.7)
                                .evaluate(CurvedAnimation(
                                    parent: pulseCtrl, curve: Curves.easeOut));
                            final opacity = Tween<double>(begin: 0.45, end: 0)
                                .evaluate(CurvedAnimation(
                                    parent: pulseCtrl, curve: Curves.easeOut));
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.good.withValues(alpha: opacity),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.good : AppColors.fair,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final String cta;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.sub,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 2),
            Text(sub, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(cta, style: AppTextStyles.labelLarge),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded,
                    size: 13, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final qualityClass = session['quality_class'] as String;
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(session['timestamp'] as int);
    final formatted = DateFormat('MMM d, yyyy · h:mm a').format(timestamp);
    final qualityColor = qualityClass == 'Good'
        ? AppColors.good
        : qualityClass == 'Fair'
            ? AppColors.fair
            : AppColors.poor;

    return GestureDetector(
      onTap: () => context.push('/session-detail', extra: session),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0F12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_rounded,
                  color: Colors.white54, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chest X-Ray',
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: qualityColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(qualityClass.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(formatted,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.history_rounded, size: 64, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text('No scans yet',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Your scan history will appear here.',
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ── Source bottom sheet ──────────────────────────────────────
class _SourceSheet extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  const _SourceSheet({required this.onPick});

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
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Text('Choose Image Source',
                style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            _OptionTile(
              icon: Icons.photo_library_rounded,
              title: 'Upload from Gallery',
              sub: 'Choose an existing X-ray image',
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Capture with Camera',
              sub: 'Take a photo of the X-ray on the lightbox',
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
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

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
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
          color: Colors.white,
          border: Border.all(color: AppColors.divider, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
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

// ── Bottom nav ───────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int active;
  final VoidCallback onScan;

  const _BottomNav({required this.active, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: active == 0,
                  onTap: () => context.go('/home')),
              // FAB slot
              SizedBox(
                width: 72,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: -22,
                      child: GestureDetector(
                        onTap: onScan,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.document_scanner_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 4,
                      child: Text('Scan',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
              _NavItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  active: active == 1,
                  onTap: () => context.push('/history')),
              _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  active: active == 2,
                  onTap: () => context.push('/settings')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Icon(icon,
                size: 24,
                color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color:
                        active ? AppColors.primary : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
