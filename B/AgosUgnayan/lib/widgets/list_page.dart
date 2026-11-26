// The layout every list tab uses (Market, Demand, My Crops, Requests,
// Prices, Following, Messages): heading, toolbar (search / filters / sort),
// the items, and the page numbers, all in one scrolling area so a phone
// never loses half its screen to a fixed header. On wide screens it stays
// centered and at most 1200 px wide. Pull down to refresh.

import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/theme.dart';
import 'async_state_view.dart';

/// One list page. [sliverBuilder] builds the items for the available
/// content width (e.g. a grid with more columns when there is room).
class ListPage extends StatelessWidget {
  const ListPage({
    super.key,
    required this.header,
    required this.isLoading,
    required this.isEmpty,
    required this.emptyMessage,
    required this.sliverBuilder,
    required this.onRefresh,
    this.toolbar,
    this.errorMessage,
    this.onRetry,
    this.emptyAction,
    this.pagination,
    this.controller,
  });

  final Widget header;
  final Widget? toolbar;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final String emptyMessage;
  final Widget? emptyAction;

  /// Builds the items (a SliverList or SliverGrid) for [contentWidth].
  final Widget Function(BuildContext context, double contentWidth)
  sliverBuilder;

  /// Usually a PaginationBar, under the items.
  final Widget? pagination;

  final Future<void> Function() onRefresh;

  /// Lets the page scroll back to the top when the page number changes.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side padding that also centers the content on very wide screens.
        final side = max(
          AppSizes.pagePadding,
          (constraints.maxWidth - AppSizes.maxListWidth) / 2,
        );
        final contentWidth = constraints.maxWidth - side * 2;
        final showState = isLoading || errorMessage != null || isEmpty;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            controller: controller,
            // Pull-to-refresh works even when the list is short.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSizes.pagePadding,
                  side,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      if (toolbar != null) ...[
                        const SizedBox(height: 14),
                        toolbar!,
                      ],
                    ],
                  ),
                ),
              ),
              if (showState)
                // Loading, error or empty, centered in the space left.
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AsyncStateView(
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onRetry: onRetry,
                    isEmpty: isEmpty,
                    emptyMessage: emptyMessage,
                    emptyAction: emptyAction,
                    builder: (_) => const SizedBox.shrink(),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: sliverBuilder(context, contentWidth),
                ),
                if (pagination != null)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(side, 8, side, 24),
                    sliver: SliverToBoxAdapter(child: pagination),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A list of cards with an 8 px gap, as a sliver (for [ListPage]).
Widget sliverCardList(int count, IndexedWidgetBuilder itemBuilder) {
  return SliverList.separated(
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.small),
    itemBuilder: itemBuilder,
  );
}

/// Cards in a grid with as many columns as fit [minTileWidth] (at least
/// [minColumns]), as a sliver. Use for wide screens.
Widget sliverCardGrid({
  required double contentWidth,
  required int count,
  required IndexedWidgetBuilder itemBuilder,
  double minTileWidth = 360,
  int minColumns = 1,
  int maxColumns = 3,
  double? tileHeight,
  double Function(double tileWidth)? tileHeightFor,
}) {
  const gap = 10.0;
  final columns = (contentWidth / minTileWidth).floor().clamp(
    minColumns,
    maxColumns,
  );
  final tileWidth = (contentWidth - gap * (columns - 1)) / columns;
  return SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      mainAxisExtent: tileHeightFor?.call(tileWidth) ?? tileHeight,
    ),
    delegate: SliverChildBuilderDelegate(itemBuilder, childCount: count),
  );
}
