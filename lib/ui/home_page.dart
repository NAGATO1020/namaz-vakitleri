import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/prayer.dart';
import '../data/models/prayer_day.dart';
import '../data/sources/prayer_source.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'city_search_page.dart';
import 'month_page.dart';
import 'settings_page.dart';
import 'widgets/countdown_header.dart';
import 'widgets/holy_day_card.dart';
import 'widgets/prayer_grid.dart';
import 'widgets/update_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.settings.cityName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (state.settings.cityRegion.isNotEmpty)
              Text(state.settings.cityRegion,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.changeCity,
            icon: const Icon(Icons.place_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CitySearchPage()),
            ),
          ),
          IconButton(
            tooltip: l10n.monthlyTitle,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MonthPage()),
            ),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(homeControllerProvider.notifier).refresh(),
        child: _Body(state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (state.loading && state.today == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error is CityNotSupportedException) {
      return _FullPageMessage(
        icon: Icons.wb_twilight_outlined,
        message: l10n.errorCityNotSupported,
        actionLabel: l10n.changeCity,
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CitySearchPage()),
        ),
      );
    }

    final today = state.today;
    if (today == null) {
      return _FullPageMessage(
        icon: Icons.cloud_off_outlined,
        message: l10n.errorNoData,
        actionLabel: l10n.retry,
        onAction: () => ref.read(homeControllerProvider.notifier).refresh(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const UpdateCard(),
        if (state.error != null && state.usingCache) ...[
          _OfflineBanner(message: l10n.errorOffline),
          const SizedBox(height: 12),
        ],
        _DateHeader(day: today),
        const SizedBox(height: 16),
        const CountdownHeader(),
        const SizedBox(height: 16),
        const HolyDayCard(),
        const SizedBox(height: 16),
        PrayerGrid(
          day: today,
          visible: state.settings.effectiveVisiblePrayers,
          cityOffset: state.settings.cityOffset,
        ),
        const SizedBox(height: 16),
        _QiblaNote(day: today),
        const SizedBox(height: 24),
        const _SourceNote(),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day});

  final PrayerDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final gregorian =
        DateFormat.yMMMMEEEEd(locale).format(day.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gregorian,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (day.hijriDate.isNotEmpty)
          Text(
            day.hijriDate,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
      ],
    );
  }
}

class _QiblaNote extends ConsumerWidget {
  const _QiblaNote({required this.day});

  final PrayerDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
        homeControllerProvider.select((s) => s.settings.effectiveVisiblePrayers));
    if (!visible.contains(Prayer.kibleSaati)) return const SizedBox.shrink();

    final time = day.timeOf(Prayer.kibleSaati);
    if (time == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.explore_outlined,
              size: 20, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).qiblaHourNote,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _SourceNote extends ConsumerWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final source =
        ref.watch(homeControllerProvider.select((s) => s.settings.source));
    return Center(
      child: Text(
        AppLocalizations.of(context).sourceNote(source.displayName),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _FullPageMessage extends StatelessWidget {
  const _FullPageMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 20),
        Text(message,
            textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.tonal(
              onPressed: onAction, child: Text(actionLabel)),
        ),
      ],
    );
  }
}
