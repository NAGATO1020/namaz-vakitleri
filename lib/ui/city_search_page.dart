import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/city.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

/// Çevrimdışı şehir arama — 234 ülke, 122.314 şehir uygulamanın içinde.
class CitySearchPage extends ConsumerStatefulWidget {
  const CitySearchPage({super.key});

  @override
  ConsumerState<CitySearchPage> createState() => _CitySearchPageState();
}

class _CitySearchPageState extends ConsumerState<CitySearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<City> _results = const [];
  bool _searching = false;
  int _cityCount = 0;

  @override
  void initState() {
    super.initState();
    // Liste ilk aramadan önce hazır olsun.
    unawaited(ref.read(cityRepositoryProvider).ensureLoaded().then((_) {
      if (mounted) {
        setState(() => _cityCount = ref.read(cityRepositoryProvider).cityCount);
      }
    }));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final found = await ref.read(cityRepositoryProvider).search(value);
      if (!mounted) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    });
  }

  Future<void> _select(City city) async {
    await ref.read(homeControllerProvider.notifier).setCity(city);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selectedId =
        ref.watch(homeControllerProvider.select((s) => s.settings.cityId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.citySearchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: l10n.citySearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildResults(l10n, theme, selectedId)),
        ],
      ),
    );
  }

  Widget _buildResults(
      AppLocalizations l10n, ThemeData theme, int selectedId) {
    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.citySearchEmpty,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (_cityCount > 0) ...[
              const SizedBox(height: 6),
              Text(l10n.cityCount(_cityCount),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      );
    }

    if (_results.isEmpty && !_searching) {
      return Center(
        child: Text(l10n.citySearchNoResult,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        final city = _results[i];
        final selected = city.id == selectedId;
        return ListTile(
          leading: Icon(
            selected ? Icons.check_circle : Icons.place_outlined,
            color: selected ? theme.colorScheme.primary : null,
          ),
          title: Text(city.shortName),
          subtitle: Text(
            city.province.isEmpty
                ? city.country
                : '${city.province} / ${city.country}',
          ),
          onTap: () => _select(city),
        );
      },
    );
  }
}
