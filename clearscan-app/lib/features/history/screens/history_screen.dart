import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Good', 'Fair', 'Poor'];

  @override
  Widget build(BuildContext context) {
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
                    border:
                        Border(bottom: BorderSide(color: AppColors.divider))),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text('Scan History',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final on = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.white,
                          border: Border.all(
                              color:
                                  on ? AppColors.primary : AppColors.divider),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(f,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? Colors.white
                                      : AppColors.textSecondary)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseService.getSessions(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var sessions = snap.data ?? [];
                if (_filter != 'All') {
                  sessions = sessions
                      .where((s) => s['quality_class'] == _filter)
                      .toList();
                }
                if (sessions.isEmpty) {
                  return _EmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _SessionCard(
                      session: sessions[i],
                      onDelete: () {
                        DatabaseService.deleteSession(sessions[i]['id'] as int)
                            .then((_) => setState(() {}));
                      }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onDelete;

  const _SessionCard({required this.session, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final q = session['quality_class'] as String;
    final ts = DateTime.fromMillisecondsSinceEpoch(session['timestamp'] as int);
    final formatted = DateFormat('MMM d, yyyy · h:mm a').format(ts);
    final qColor = q == 'Good'
        ? AppColors.good
        : q == 'Fair'
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
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0F12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_rounded,
                  color: Colors.white54, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chest X-Ray',
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: qColor,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(q.toUpperCase(),
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
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'share') {
                  Share.share(
                      'ClearScan Analysis: $q quality X-ray, scanned $formatted.');
                } else if (v == 'delete') {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Session?'),
                      content: const Text(
                          'This will permanently remove this scan session.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: AppColors.poor))),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppColors.poor))),
              ],
              child: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 72, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text('No sessions found', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Your scan history will appear here after your first analysis.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
