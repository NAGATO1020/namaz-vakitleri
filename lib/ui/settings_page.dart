import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/calendar_source.dart';
import '../core/prayer.dart';
import '../data/update_service.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'city_search_page.dart';
import 'widgets/permission_cards.dart';
import 'widgets/update_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final settings = state.settings;
    final language = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionTitle(l10n.calendarSourceTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.calendarSourceSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          RadioGroup<CalendarSource>(
            groupValue: settings.source,
            onChanged: (value) {
              if (value != null) _confirmSourceChange(context, ref, value);
            },
            child: Column(
              children: [
                for (final source in CalendarSource.values)
                  RadioListTile<CalendarSource>(
                    value: source,
                    title: Text(source.displayName),
                    subtitle: Text(
                      source.supportsArbitraryDate
                          ? l10n.sourceFull(source.supportedPrayers.length)
                          : l10n.sourceLimited(source.supportedPrayers.length),
                    ),
                    isThreeLine: false,
                  ),
              ],
            ),
          ),

          _SectionTitle(l10n.location),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(settings.cityId <= 0
                ? l10n.citySearchTitle
                : settings.cityDisplayName),
            subtitle: Text(l10n.changeCity),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CitySearchPage()),
            ),
          ),

          _SectionTitle(l10n.theme),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) controller.setThemeMode(mode);
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                    value: ThemeMode.system, title: Text(l10n.themeSystem)),
                RadioListTile<ThemeMode>(
                    value: ThemeMode.light, title: Text(l10n.themeLight)),
                RadioListTile<ThemeMode>(
                    value: ThemeMode.dark, title: Text(l10n.themeDark)),
              ],
            ),
          ),

          _SectionTitle(l10n.language),
          RadioGroup<String?>(
            groupValue: settings.languageCode,
            onChanged: controller.setLanguage,
            child: Column(
              children: [
                RadioListTile<String?>(
                    value: null, title: Text(l10n.languageSystem)),
                RadioListTile<String?>(
                    value: 'tr', title: Text(l10n.languageTurkish)),
                RadioListTile<String?>(
                    value: 'en', title: Text(l10n.languageEnglish)),
              ],
            ),
          ),

          _SectionTitle(l10n.visiblePrayersTitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.visiblePrayersSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text(l10n.selectAll),
                  onPressed: () =>
                      controller.setVisible(Prayer.values.toSet()),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.remove_done, size: 18),
                  label: Text(l10n.clearAll),
                  onPressed: () => controller.setVisible(const {}),
                ),
              ],
            ),
          ),
          // Seçili kaynağın vermediği vakitler listelenmez; olmayan bir vakti
          // açtırmak yanıltıcı olurdu.
          for (final prayer in Prayer.values)
            if (settings.source.supportedPrayers.contains(prayer))
              CheckboxListTile(
                dense: true,
                value: settings.visiblePrayers.contains(prayer),
                title: Text(prayer.localizedName(language)),
                onChanged: (_) => controller.toggleVisible(prayer),
              ),

          _SectionTitle(l10n.notificationsTitle),
          const PermissionCards(),
          SwitchListTile(
            value: settings.notificationsEnabled,
            title: Text(l10n.prayerNotifications),
            subtitle: Text(l10n.prayerNotificationsSubtitle),
            onChanged: controller.setNotificationsEnabled,
          ),
          SwitchListTile(
            value: settings.persistentNotification,
            title: Text(l10n.persistentNotification),
            subtitle: Text(l10n.persistentNotificationSubtitle),
            onChanged: controller.setPersistentNotification,
          ),
          SwitchListTile(
            value: settings.showSecondsInCountdown,
            title: Text(l10n.showSeconds),
            onChanged: controller.setShowSeconds,
          ),
          if (settings.notificationsEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.notifyPrayersTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final prayer in Prayer.values)
              if (prayer.isInChronologicalChain)
                CheckboxListTile(
                  dense: true,
                  value: settings.notifyPrayers.contains(prayer),
                  title: Text(prayer.localizedName(language)),
                  onChanged: (_) => controller.toggleNotify(prayer),
                ),
          ],

          _SectionTitle(l10n.sourceTitle),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(l10n.sourceNote(settings.source.displayName)),
            subtitle: Text(l10n.openSource(
                Uri.parse(settings.source.homepage).host)),
            onTap: () => launchUrl(
              Uri.parse(settings.source.homepage),
              mode: LaunchMode.externalApplication,
            ),
          ),

          const _VersionTile(),
        ],
      ),
    );
  }
}

/// Kaynak değişimi indirilen vakitleri sildiği için önce onay alınır.
Future<void> _confirmSourceChange(
  BuildContext context,
  WidgetRef ref,
  CalendarSource target,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.sourceChangeTitle(target.displayName)),
      content: Text(l10n.sourceChangeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.done),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await ref.read(homeControllerProvider.notifier).setSource(target);
  if (!context.mounted) return;
  // Şehir kimlikleri kaynaklar arasında uyuşmuyor; yeni listeden seçtiriyoruz.
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CitySearchPage()),
  );
}

/// Kurulu sürümü gösterir; dokununca güncelleme denetler.
class _VersionTile extends ConsumerStatefulWidget {
  const _VersionTile();

  @override
  ConsumerState<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends ConsumerState<_VersionTile> {
  String? _version;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    UpdateService.currentVersion().then((v) {
      if (mounted) setState(() => _version = v.name);
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final release = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(release == null
          ? l10n.updateUpToDate
          : l10n.updateAvailable(release.versionName)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(_version == null
          ? l10n.updateCheck
          : l10n.updateCurrentVersion(_version!)),
      subtitle: Text(l10n.updateCheck),
      trailing: _checking
          ? const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: _checking ? null : _check,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
