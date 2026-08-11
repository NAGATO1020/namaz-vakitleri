import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../platform/service_bridge.dart';

/// Kalıcı bildirimi ayakta tutar.
///
/// Bildirim üç yoldan geri gelir:
///  1. Kullanıcı kaydırıp atarsa `setDeleteIntent` tetiklenir ve native taraf
///     hemen yeniden basar (bkz. `PrayerAlarmReceiver`).
///  2. Her vakit geçişinde `AlarmManager` bildirimi yeniden kurar.
///  3. **Burada:** uygulama her öne geldiğinde yeniden kurulur — üretici
///     arayüzleri bâzen bildirimi sessizce düşürüyor, bu son güvence.
class NotificationKeeper extends StatefulWidget {
  const NotificationKeeper({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationKeeper> createState() => _NotificationKeeperState();
}

class _NotificationKeeperState extends State<NotificationKeeper>
    with WidgetsBindingObserver {
  bool get _relevant => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_relevant) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (_relevant) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Veri zaten yayınlanmış durumda; native taraf yalnızca yeniden kurar.
      ServiceBridge.syncSchedule();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
