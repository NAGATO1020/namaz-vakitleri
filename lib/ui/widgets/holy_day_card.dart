import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/holy_day.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Bugün mübârek bir güne denk geliyorsa öne çıkan kart, aksi hâlde
/// yaklaşan mübârek günlerin kısa listesi.
///
/// Günler ve isimleri turktakvim'in "Senelik Hicrî Kamerî Târîhler"
/// sayfasından gelir; uygulama kendisi bir gün hesaplamaz.
class HolyDayCard extends ConsumerWidget {
  const HolyDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    if (state.holyDays.isEmpty) return const SizedBox.shrink();

    final language = Localizations.localeOf(context).languageCode;
    final today = state.todayHolyDay;
    if (today != null) {
      return _TodayCard(holyDay: today, language: language);
    }

    final upcoming = state.upcomingHolyDays(count: 3);
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return _UpcomingCard(days: upcoming, language: language);
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.holyDay, required this.language});

  final HolyDay holyDay;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.seed,
            const Color(0xFF0C1A33),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.brightness_2_outlined,
              color: AppTheme.crescent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.holyDayToday,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.crescent,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holyDay.localizedName(language),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (holyDay.hijri.isNotEmpty)
                  Text(
                    holyDay.hijri,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.days, required this.language});

  final List<HolyDay> days;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_2_outlined,
                    size: 16, color: AppTheme.crescent),
                const SizedBox(width: 8),
                Text(
                  l10n.holyDaysUpcoming,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        day.localizedName(language),
                        maxLines: 2,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat.MMMd(locale).format(day.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary),
                        ),
                        Text(
                          l10n.daysAway(_daysBetween(today, day.date)),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime(to.year, to.month, to.day)
          .difference(DateTime(from.year, from.month, from.day))
          .inDays;
}
