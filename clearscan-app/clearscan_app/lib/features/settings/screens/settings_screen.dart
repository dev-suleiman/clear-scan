import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/connectivity_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _preferCnn = true;
  bool _autoEnhance = false;
  String _backendUrl = 'https://your-app.onrender.com';
  String _cacheSize = 'Calculating…';
  bool _testingConn = false;
  bool _forceOffline = false;

  @override
  void initState() {
    super.initState();
    _load();
    _calcCache();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferCnn = prefs.getBool('prefer_cnn') ?? true;
      _autoEnhance = prefs.getBool('auto_enhance') ?? false;
      _backendUrl =
          prefs.getString('backend_url') ?? 'https://your-app.onrender.com';
      _forceOffline = prefs.getBool('force_offline') ?? false;
    });
  }

  Future<void> _calcCache() async {
    try {
      final tmp = await getTemporaryDirectory();
      final bytes = tmp
          .listSync(recursive: true)
          .fold<int>(0, (sum, f) => f is File ? sum + f.lengthSync() : sum);
      final kb = bytes / 1024;
      setState(() {
        _cacheSize = kb < 1024
            ? '${kb.toStringAsFixed(1)} KB'
            : '${(kb / 1024).toStringAsFixed(1)} MB';
      });
    } catch (_) {
      setState(() => _cacheSize = 'Unknown');
    }
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
    setState(() => _backendUrl = url);
  }

  Future<void> _testConnection() async {
    setState(() => _testingConn = true);
    await ref.read(connectivityProvider.notifier).refresh();
    setState(() => _testingConn = false);
    final ok = ref.read(connectivityProvider).valueOrNull ?? false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: ok ? AppColors.good : AppColors.poor,
        content: Text(ok
            ? '✓ Connection OK — CNN backend reachable'
            : '✗ Unreachable — offline mode active'),
      ));
    }
  }

  Future<void> _clearCache() async {
    final tmp = await getTemporaryDirectory();
    for (final f in tmp.listSync()) {
      try {
        f.deleteSync(recursive: true);
      } catch (_) {}
    }
    _calcCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')));
    }
  }

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
                  border: Border(
                      bottom: BorderSide(color: AppColors.divider))),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text('Settings',
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
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              children: [
                // Profile card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dr. User',
                                  style: AppTextStyles.titleMedium),
                              Text('Tap to edit profile',
                                  style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),

                _SectionLabel('Connection'),
                _SettingsGroup(children: [
                  _SettingsRow(
                    icon: Icons.dns_rounded,
                    title: 'Backend Server',
                    sub: _backendUrl,
                    trailing: const Icon(Icons.edit_rounded,
                        size: 20, color: AppColors.textSecondary),
                    onTap: () => _editUrl(context),
                  ),
                  _SettingsRow(
                    icon: Icons.wifi_find_rounded,
                    iconColor: AppColors.primary,
                    title: 'Test Connection',
                    sub: 'Verify API connectivity',
                    trailing: _testingConn
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary))
                        : const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                    onTap: _testingConn ? null : _testConnection,
                    last: true,
                  ),
                ]),

                _SectionLabel('Processing'),
                _SettingsGroup(children: [
                  _SettingsRow(
                    title: 'Prefer CNN when Online',
                    trailing: Switch(
                      value: _preferCnn,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) async {
                        setState(() => _preferCnn = v);
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('prefer_cnn', v);
                      },
                    ),
                  ),
                  _SettingsRow(
                    title: 'Auto-enhance Poor Images',
                    trailing: Switch(
                      value: _autoEnhance,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) async {
                        setState(() => _autoEnhance = v);
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('auto_enhance', v);
                      },
                    ),
                    last: true,
                  ),
                ]),

                _SectionLabel('Storage'),
                _SettingsGroup(children: [
                  _SettingsRow(
                    icon: Icons.sd_storage_rounded,
                    title: 'Cache Size',
                    sub: _cacheSize,
                    trailing: const Icon(Icons.delete_sweep_rounded,
                        color: AppColors.textSecondary),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Clear Cache?'),
                        content: const Text(
                            'This will delete all temporary files.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _clearCache();
                              },
                              child: const Text('Clear')),
                        ],
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.history_rounded,
                    title: 'Clear History',
                    sub: 'Remove all session records',
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                    last: true,
                  ),
                ]),

                _SectionLabel('About'),
                _SettingsGroup(children: [
                  const _SettingsRow(
                    icon: Icons.info_rounded,
                    title: 'App Version',
                    sub: 'ClearScan v1.0.0',
                  ),
                  const _SettingsRow(
                    icon: Icons.school_rounded,
                    title: 'Project Info',
                    sub: 'KNUST — Computer Science — Group 6',
                  ),
                  const _SettingsRow(
                    icon: Icons.gavel_rounded,
                    title: 'Licences',
                    trailing: Icon(Icons.open_in_new_rounded,
                        size: 20, color: AppColors.textSecondary),
                    last: true,
                  ),
                ]),

                if (kDebugMode) ...[
                  _SectionLabel('Debug', tint: true),
                  _DebugGroup(children: [
                    _SettingsRow(
                      icon: Icons.warning_rounded,
                      iconColor: AppColors.fair,
                      title: 'Force Offline Mode',
                      trailing: Switch(
                        value: _forceOffline,
                        activeThumbColor: AppColors.fair,
                        onChanged: (v) async {
                          setState(() => _forceOffline = v);
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('force_offline', v);
                        },
                      ),
                      last: true,
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editUrl(BuildContext context) {
    final ctrl = TextEditingController(text: _backendUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backend URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              hintText: 'https://your-app.onrender.com'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveUrl(ctrl.text.trim());
              },
              child: const Text('Save')),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool tint;

  const _SectionLabel(this.label, {this.tint = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(label.toUpperCase(),
          style: AppTextStyles.labelMedium.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textSecondary)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _DebugGroup extends StatelessWidget {
  final List<Widget> children;

  const _DebugGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          border: Border.all(color: const Color(0xFFFCEFC7)),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  const _SettingsRow({
    this.icon,
    this.iconColor,
    required this.title,
    this.sub,
    this.trailing,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.divider))),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22,
                  color: iconColor ?? AppColors.textSecondary),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w500)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
