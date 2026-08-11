import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prayer.dart';
import '../../core/theme.dart';
import '../../data/models/prayer_day.dart';
import '../../state/app_state.dart';

/// Günün vakitleri — turktakvim'in iki sütunlu düzenini korur.
///
/// Sol sütun İmsâk…Asr-ı Sânî, sağ sütun İsfirâr-ı Şems…Kıble Sâati.
/// Gizlenen vakitler satırdan düşer; kalanların yeri değişmez.
class PrayerGrid extends ConsumerWidget {
  const PrayerGrid({
    super.key,
    required this.day,
    required this.visible,
    required this.cityOffset,
  });

  final PrayerDay day;
  final Set<Prayer> visible;
  final Duration cityOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).valueOrNull ?? DateTime.now();
    final cityNow = now.add(cityOffset);
    final info = ref.watch(homeControllerProvider).nextPrayer(now);

    // Görünen vakitler ikiye bölünür: soldan sağa değil, yukarıdan aşağıya
    // okunur — 18 vaktin hepsi açıkken turktakvim'in 9+9 düzeniyle birebir
    // aynı olur, bir kısmı gizliyken de sütunlar dengeli kalır.
    // Kaynağın o gün için vermediği vakitler (ör. Fazilet bâzı şehirlerde
    // İşrak vermiyor) listeye "--:--" olarak girmesin.
    final shown = Prayer.values
        .where((p) => visible.contains(p) && day.timeOf(p) != null)
        .toList();
    final split = (shown.length + 1) ~/ 2;
    final left = shown.take(split).toList();
    final right = shown.skip(split).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ekran görüntüsündeki iki sütunlu düzen ancak sütun başına
            // isim + saat sığdığında açılır. Dar telefonlarda (< ~330dp
            // kullanılabilir genişlik) "Dahve-i Kübrâ" gibi uzun adlar
            // kırpılacağı için tek sütuna düşülür.
            final singleColumn = constraints.maxWidth < 330;
            if (singleColumn) {
              return Column(
                children: [
                  for (final prayer in [...left, ...right])
                    _PrayerRow(
                      prayer: prayer,
                      day: day,
                      cityNow: cityNow,
                      nextPrayer: info?.next,
                      currentPrayer: info?.current,
                    ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final prayer in left)
                        _PrayerRow(
                          prayer: prayer,
                          day: day,
                          cityNow: cityNow,
                          nextPrayer: info?.next,
                          currentPrayer: info?.current,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      for (final prayer in right)
                        _PrayerRow(
                          prayer: prayer,
                          day: day,
                          cityNow: cityNow,
                          nextPrayer: info?.next,
                          currentPrayer: info?.current,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrayerRow extends ConsumerWidget {
  const _PrayerRow({
    required this.prayer,
    required this.day,
    required this.cityNow,
    required this.nextPrayer,
    required this.currentPrayer,
  });

  final Prayer prayer;
  final PrayerDay day;
  final DateTime cityNow;
  final Prayer? nextPrayer;
  final Prayer? currentPrayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final time = day.timeOf(prayer);
    final at = day.dateTimeOf(prayer);

    final rowState = switch (prayer) {
      _ when prayer == nextPrayer => PrayerRowState.next,
      _ when prayer == currentPrayer => PrayerRowState.current,
      _ when at != null && at.isBefore(cityNow) => PrayerRowState.past,
      _ => PrayerRowState.upcoming,
    };

    final notify = ref.watch(homeControllerProvider
        .select((s) => s.settings.effectiveNotifyPrayers.contains(prayer)));
    final notificationsOn = ref.watch(homeControllerProvider
        .select((s) => s.settings.notificationsEnabled));

    final foreground = rowState.foreground(theme.colorScheme);
    final background = rowState.background(theme.colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              ref.read(homeControllerProvider.notifier).toggleNotify(prayer),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    prayer.localizedName(language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: rowState.weight,
                    ),
                  ),
                ),
                Text(
                  time ?? '--:--',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: rowState.weight,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: notify && notificationsOn
                      ? Icon(Icons.notifications_active,
                          size: 15,
                          color: foreground.withValues(alpha: 0.75))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
