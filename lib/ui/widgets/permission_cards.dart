import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/service_bridge.dart';

/// Bildirimlerin gerçekten çalışması için gereken üç izni kontrol eder ve
/// eksik olanları uyarı kartı olarak gösterir.
///
/// Üçü de tamamsa hiçbir şey çizmez — her şey yolundayken kullanıcıyı
/// uyarıyla meşgul etmenin anlamı yok.
class PermissionCards extends StatefulWidget {
  const PermissionCards({super.key});

  @override
  State<PermissionCards> createState() => _PermissionCardsState();
}

class _PermissionCardsState extends State<PermissionCards>
    with WidgetsBindingObserver {
  bool _notifications = true;
  bool _exactAlarms = true;
  bool _batteryExempt = true;
  bool _checked = false;

  bool get _relevant => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından dönünce durumu tazele.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!_relevant) return;
    final notifications = await ServiceBridge.notificationsAllowed();
    final exact = await ServiceBridge.canScheduleExactAlarms();
    final battery = await ServiceBridge.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _exactAlarms = exact;
      _batteryExempt = battery;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_relevant || !_checked) return const SizedBox.shrink();
    if (_notifications && _exactAlarms && _batteryExempt) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (!_notifications)
          _PermissionCard(
            icon: Icons.notifications_off_outlined,
            title: l10n.permissionNotificationTitle,
            body: l10n.permissionNotificationBody,
            actionLabel: l10n.grantPermission,
            onAction: () async {
              final granted =
                  await ServiceBridge.requestNotificationPermission();
              if (!granted) await ServiceBridge.openNotificationSettings();
              await _check();
            },
          ),
        if (!_exactAlarms)
          _PermissionCard(
            icon: Icons.alarm_off_outlined,
            title: l10n.permissionExactAlarmTitle,
            body: l10n.permissionExactAlarmBody,
            actionLabel: l10n.grantPermission,
            onAction: () async {
              await ServiceBridge.openExactAlarmSettings();
            },
          ),
        if (!_batteryExempt)
          _PermissionCard(
            icon: Icons.battery_alert_outlined,
            title: l10n.permissionBatteryTitle,
            body: l10n.permissionBatteryBody,
            actionLabel: l10n.grantPermission,
            onAction: () async {
              await ServiceBridge.openBatterySettings();
            },
          ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
