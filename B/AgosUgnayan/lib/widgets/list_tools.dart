// The tools every long list uses, so search, filters, sorting and page
// numbers look and work the same everywhere (Nielsen: consistency):
// - SearchBox: waits 300 ms after typing (debounce), has a clear button
// - SortMenu: "Sort: Newest" button that opens the choices
// - ListToolbar: search + filters + sort, and "Clear all" when filtered
// - PaginationBar: "Showing 13-24 of 57" with Previous / Next and pages

import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/paging.dart';
import '../utils/theme.dart';

/// A search field that reports what was typed 300 ms after the last key,
/// so the list doesn't jump on every letter. Enter searches right away.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialText = '',
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final String initialText;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final _controller = TextEditingController(text: widget.initialText);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    setState(() {}); // shows or hides the clear button
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => widget.onChanged(text.trim()),
    );
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _changed,
      // Enter searches at once instead of waiting.
      onSubmitted: (text) {
        _timer?.cancel();
        widget.onChanged(text.trim());
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: _clear,
              ),
        isDense: true,
      ),
    );
  }
}

/// A "Sort: Newest" button. [options] maps each value to its label.
class SortMenu<T> extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Change the order',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              'Sort: ${options[value]}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A compact dropdown used as a filter, e.g. "All towns" / "Leon".
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
    this.icon,
    this.width = 170,
  });

  final String? value; // null = all
  final String allLabel;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final IconData? icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        // A new key when the value changes from outside (e.g. Clear all).
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: AppColors.textMuted),
          // A narrow icon area leaves room for the text, e.g. "All towns".
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(value: null, child: Text(allLabel)),
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Search on top (full width on phones), then filters and sort in a row
/// that wraps, then "N results" and "Clear all" when something is filtered.
class ListToolbar extends StatelessWidget {
  const ListToolbar({
    super.key,
    required this.search,
    this.filters = const [],
    this.sort,
    this.resultText,
    this.onClearAll,
  });

  final Widget search;
  final List<Widget> filters;
  final Widget? sort;

  /// e.g. "12 crops found".
  final String? resultText;

  /// Shown as "Clear all" when not null (only while something is filtered).
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final controls = Wrap(
          spacing: AppSizes.small,
          runSpacing: AppSizes.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [...filters, ?sort],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: AppSizes.small),
                  controls,
                ],
              )
            else ...[
              search,
              if (filters.isNotEmpty || sort != null) ...[
                const SizedBox(height: AppSizes.small),
                controls,
              ],
            ],
            if (resultText != null || onClearAll != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (resultText != null)
                      Text(resultText!, style: AppTextStyles.meta),
                    const Spacer(),
                    if (onClearAll != null)
                      TextButton.icon(
                        onPressed: onClearAll,
                        icon: const Icon(Icons.filter_alt_off, size: 16),
                        label: const Text('Clear all filters'),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Showing 13-24 of 57" with Previous / Next and the page number.
/// Hidden when everything fits on one page.
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.slice, required this.onPage});

  final PageSlice<dynamic> slice;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (slice.pageCount <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          slice.summary,
          textAlign: TextAlign.center,
          style: AppTextStyles.meta,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSizes.small,
        runSpacing: AppSizes.small,
        children: [
          Text(slice.summary, style: AppTextStyles.meta),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: slice.hasPrevious
                    ? () => onPage(slice.page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page ${slice.page} of ${slice.pageCount}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: slice.hasNext ? () => onPage(slice.page + 1) : null,
                // Icon after the text, so it points the way it goes.
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tabs like "Active (3) | Sold out (1) | Removed (0)" above a list.
/// [labels] maps each tab to its name; [counts] to how many it holds.
class StatusTabs<T> extends StatelessWidget {
  const StatusTabs({
    super.key,
    required this.value,
    required this.labels,
    required this.counts,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> labels;
  final Map<T, int> counts;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Many tabs on a narrow phone: one smaller size for all of them,
        // so "Waiting (2)" stays on one line and the tabs look the same.
        final compact = constraints.maxWidth / labels.length < 100;
        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final entry in labels.entries)
                ButtonSegment(
                  value: entry.key,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${entry.value} (${counts[entry.key] ?? 0})',
                      maxLines: 1,
                      style: compact ? const TextStyle(fontSize: 12) : null,
                    ),
                  ),
                ),
            ],
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        );
      },
    );
  }
}
