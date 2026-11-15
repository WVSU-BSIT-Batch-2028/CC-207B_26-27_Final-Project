import 'package:flutter/material.dart';

// Priority level determining whether a column is displayed on narrower widths
enum TabletColumnPriority {
  high, // Always shown
  medium, // Hidden on small tablet / split-screen
  low, // Only on full-width tablet
}

// Definition of a table column
class TabletColumn {
  final String title;
  final TabletColumnPriority priority;
  final double? width;
  final int flex;
  final Alignment alignment;

  const TabletColumn({
    required this.title,
    this.priority = TabletColumnPriority.high,
    this.width,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
}

// Reusable responsive data table with column priorities, search, filtering, and bulk actions
class TabletDataTable<T> extends StatelessWidget {
  final String searchHint;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final int totalCount;
  final int filteredCount;
  final String countLabel;
  final VoidCallback? onFiltersTap;
  final int activeFilterCount;
  final List<Widget>? headerActions;
  final List<TabletColumn> columns;
  final List<T> items;
  final List<Widget> Function(BuildContext context, T item, int index) rowBuilder;
  final ValueChanged<T>? onItemTap;
  final bool selectable;
  final Set<String> selectedIds;
  final String Function(T item)? idGetter;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final List<Widget>? bulkActions;
  final Widget? emptyState;

  const TabletDataTable({
    super.key,
    this.searchHint = 'Search...',
    this.searchQuery,
    this.onSearchChanged,
    required this.totalCount,
    required this.filteredCount,
    this.countLabel = 'items',
    this.onFiltersTap,
    this.activeFilterCount = 0,
    this.headerActions,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.onItemTap,
    this.selectable = false,
    this.selectedIds = const {},
    this.idGetter,
    this.onSelectionChanged,
    this.bulkActions,
    this.emptyState,
  });

  bool _isColumnVisible(TabletColumn col, double availableWidth) {
    if (col.priority == TabletColumnPriority.high) return true;
    if (col.priority == TabletColumnPriority.medium) return availableWidth >= 700;
    return availableWidth >= 950;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final visibleColumns = columns
            .where((col) => _isColumnVisible(col, availableWidth))
            .toList();

        final allSelected = items.isNotEmpty &&
            idGetter != null &&
            items.every((it) => selectedIds.contains(idGetter!(it)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Controls Bar (Search, Filter, Count, Action buttons)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  // Search Input
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: TextField(
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Filter Button
                  OutlinedButton.icon(
                    onPressed: onFiltersTap,
                    icon: Icon(
                      Icons.filter_list,
                      size: 18,
                      color: activeFilterCount > 0
                          ? const Color(0xFF1E6B3E)
                          : const Color(0xFF4B5563),
                    ),
                    label: Text(
                      activeFilterCount > 0
                          ? 'Filters ($activeFilterCount)'
                          : 'Filters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: activeFilterCount > 0
                            ? const Color(0xFF1E6B3E)
                            : const Color(0xFF374151),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      side: BorderSide(
                        color: activeFilterCount > 0
                            ? const Color(0xFF1E6B3E)
                            : const Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: activeFilterCount > 0
                          ? const Color(0xFFE8F5E9)
                          : Colors.white,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Count display
                  Text(
                    '$filteredCount of $totalCount $countLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const Spacer(),

                  // Extra action buttons (e.g. + Add entry, Import)
                  ...?headerActions,
                ],
              ),
            ),

            // Bulk Actions Bar (if any rows selected)
            if (selectable && selectedIds.isNotEmpty && bulkActions != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${selectedIds.length} selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ...bulkActions!,
                    const Spacer(),
                    TextButton(
                      onPressed: () => onSelectionChanged?.call({}),
                      child: const Text(
                        'Clear selection',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Table Box
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                clipBehavior: Clip.antiAlias,
                child: items.isEmpty
                    ? (emptyState ??
                        const Center(
                          child: Text(
                            'No items found',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ))
                    : Column(
                        children: [
                          // Table Header
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9FAFB),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (selectable) ...[
                                  SizedBox(
                                    width: 36,
                                    child: Checkbox(
                                      value: allSelected,
                                      onChanged: (val) {
                                        if (idGetter == null) return;
                                        if (val == true) {
                                          onSelectionChanged?.call(
                                            items.map(idGetter!).toSet(),
                                          );
                                        } else {
                                          onSelectionChanged?.call({});
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                for (final col in visibleColumns)
                                  col.width != null
                                      ? SizedBox(
                                          width: col.width,
                                          child: Align(
                                            alignment: col.alignment,
                                            child: Text(
                                              col.title,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF4B5563),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Expanded(
                                          flex: col.flex,
                                          child: Align(
                                            alignment: col.alignment,
                                            child: Text(
                                              col.title,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF4B5563),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                              ],
                            ),
                          ),

                          // Table Rows
                          Expanded(
                            child: ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFF3F4F6),
                              ),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final itemId = idGetter?.call(item);
                                final isSelected = itemId != null &&
                                    selectedIds.contains(itemId);
                                final cells = rowBuilder(context, item, index);

                                return InkWell(
                                  onTap: onItemTap != null
                                      ? () => onItemTap!(item)
                                      : null,
                                  child: Container(
                                    height: 56,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    color: isSelected
                                        ? const Color(0xFFF0FDF4)
                                        : Colors.white,
                                    child: Row(
                                      children: [
                                        if (selectable) ...[
                                          SizedBox(
                                            width: 36,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (val) {
                                                if (itemId == null) return;
                                                final next =
                                                    Set<String>.from(selectedIds);
                                                if (val == true) {
                                                  next.add(itemId);
                                                } else {
                                                  next.remove(itemId);
                                                }
                                                onSelectionChanged?.call(next);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        for (int i = 0;
                                            i < visibleColumns.length;
                                            i++)
                                          visibleColumns[i].width != null
                                              ? SizedBox(
                                                  width: visibleColumns[i].width,
                                                  child: Align(
                                                    alignment: visibleColumns[i]
                                                        .alignment,
                                                    child: i < cells.length
                                                        ? cells[i]
                                                        : const SizedBox.shrink(),
                                                  ),
                                                )
                                              : Expanded(
                                                  flex: visibleColumns[i].flex,
                                                  child: Align(
                                                    alignment: visibleColumns[i]
                                                        .alignment,
                                                    child: i < cells.length
                                                        ? cells[i]
                                                        : const SizedBox.shrink(),
                                                  ),
                                                ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}