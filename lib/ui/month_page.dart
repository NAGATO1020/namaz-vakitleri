import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/prayer.dart';
import '../data/models/prayer_day.dart';
import '../data/prayer_repository.dart';
import '../data/sources/prayer_source.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

/// Aylık vakit tablosu ve "bir aylık veriyi telefona indir" akışı.
class MonthPage extends ConsumerStatefulWidget {
  const MonthPage({super.key});

  @override
  ConsumerState<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends ConsumerState<MonthPage> {
  late DateTime _month;
  List<PrayerDay> _days = const [];
  MonthDownloadProgress? _progress;
  bool _downloading = false;
  String? _error;

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _loadCache();
  }

  Future<void> _loadCache() async {
    final cityId = ref.read(homeControllerProvider).settings.cityId;
    final days =
        await ref.read(prayerRepositoryProvider).monthFromCache(cityId, _month);
    if (mounted) setState(() => _days = days);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _days = const [];
      _progress = null;
      _error = null;
    });
    _loadCache();
  }

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context);
    final cityId = ref.read(homeControllerProvider).settings.cityId;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = MonthDownloadProgress(done: 0, total: _daysInMonth);
    });

    try {
      final result = await ref.read(prayerRepositoryProvider).downloadMonth(
            ref.read(homeControllerProvider).settings.source,
            cityId,
            _month,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      await _loadCache();
      if (!mounted) return;
      setState(() => _downloading = false);
      final message = result.failed > 0
          ? l10n.monthPartial(result.failed)
          : l10n.monthDownloaded(result.total);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on CityNotSupportedException {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = l10n.errorCityNotSupported;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = l10n.errorGeneric(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = ref.watch(homeControllerProvider).settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.monthlyTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _downloading ? null : () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(_month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: l10n.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _downloading ? null : () => _shiftMonth(1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!settings.source.supportsArbitraryDate)
            // Fazilet ileriye dönük veri vermiyor; indirme düğmesi yerine
            // sebebini yazmak, çalışmayan bir düğme koymaktan iyi.
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.monthUnsupported(settings.source.displayName),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else
            _DownloadBar(
              cached: _days.length,
              total: _daysInMonth,
              downloading: _downloading,
              progress: _progress,
              onDownload: _download,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ),
          const Divider(height: 1),
          Expanded(
            child: _days.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.errorNoData,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : _MonthTable(
                    days: _days,
                    visible: settings.effectiveVisiblePrayers,
                    locale: locale,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DownloadBar extends StatelessWidget {
  const _DownloadBar({
    required this.cached,
    required this.total,
    required this.downloading,
    required this.progress,
    required this.onDownload,
  });

  final int cached;
  final int total;
  final bool downloading;
  final MonthDownloadProgress? progress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                cached >= total
                    ? Icons.offline_pin_outlined
                    : Icons.cloud_download_outlined,
                size: 20,
                color: cached >= total
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  downloading && progress != null
                      ? l10n.downloading(progress!.done, progress!.total)
                      : l10n.monthCached(cached, total),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              FilledButton.tonal(
                onPressed: downloading || cached >= total ? null : onDownload,
                child: Text(l10n.downloadMonth),
              ),
            ],
          ),
          if (downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress?.fraction,
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({
    required this.days,
    required this.visible,
    required this.locale,
  });

  final List<PrayerDay> days;
  final Set<Prayer> visible;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final columns = Prayer.values.where(visible.contains).toList();
    final today = DateTime.now();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 38,
          columnSpacing: 18,
          headingTextStyle: theme.textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          columns: [
            const DataColumn(label: Text('')),
            for (final p in columns)
              DataColumn(label: Text(p.localizedName(language))),
          ],
          rows: [
            for (final day in days)
              DataRow(
                color: WidgetStateProperty.resolveWith((_) =>
                    _isSameDay(day.date, today)
                        ? theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.4)
                        : null),
                cells: [
                  DataCell(Text(
                    DateFormat.MEd(locale).format(day.date),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  )),
                  for (final p in columns)
                    DataCell(Text(
                      day.timeOf(p) ?? '--:--',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
