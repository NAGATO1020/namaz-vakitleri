import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/service_bridge.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService();
  ref.onDispose(service.close);
  return service;
});

/// Açılışta yeni sürüm var mı diye bakar; varsa "1.2.4 güncellemesi var"
/// kartını gösterir ve tek dokunuşla indirip kurulumu başlatır.
///
/// Android sessiz kuruluma izin vermediği için son onay sistem ekranında
/// kullanıcıya sorulur — kartın yaptığı indirmek ve o ekranı açmaktır.
class UpdateCard extends ConsumerStatefulWidget {
  const UpdateCard({super.key});

  @override
  ConsumerState<UpdateCard> createState() => _UpdateCardState();
}

enum _Stage { idle, downloading, ready, failed }

class _UpdateCardState extends ConsumerState<UpdateCard> {
  AppRelease? _release;
  _Stage _stage = _Stage.idle;
  double? _progress;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final release = await ref.read(updateServiceProvider).check();
    if (!mounted || release == null) return;
    setState(() => _release = release);
  }

  Future<void> _update() async {
    final release = _release;
    if (release == null) return;

    if (!await ServiceBridge.canInstallPackages()) {
      await ServiceBridge.openInstallPermissionSettings();
      return;
    }

    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
    });

    try {
      final file = await ref.read(updateServiceProvider).download(
            release,
            onProgress: (fraction) {
              if (mounted) setState(() => _progress = fraction);
            },
          );
      if (!mounted) return;
      setState(() => _stage = _Stage.ready);
      await ServiceBridge.installApk(file.path);
    } catch (e) {
      debugPrint('Güncelleme indirilemedi: $e');
      if (mounted) setState(() => _stage = _Stage.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null || (_dismissed && !release.mandatory)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_alt,
                  size: 20, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.updateAvailable(release.versionName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!release.mandatory && _stage == _Stage.idle)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close,
                      size: 18, color: theme.colorScheme.onPrimaryContainer),
                  tooltip: l10n.later,
                  onPressed: () => setState(() => _dismissed = true),
                ),
            ],
          ),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              release.notes,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer, height: 1.3),
            ),
          ],
          if (_stage == _Stage.downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress, minHeight: 5),
            ),
            const SizedBox(height: 6),
            Text(
              _progress == null
                  ? l10n.updateDownloading
                  : l10n.updateDownloadingPercent((_progress! * 100).round()),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (_stage == _Stage.failed)
                  Expanded(
                    child: Text(
                      l10n.updateFailed,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  )
                else
                  const Spacer(),
                FilledButton(
                  onPressed: _update,
                  child: Text(_stage == _Stage.failed
                      ? l10n.retry
                      : l10n.updateNow),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
