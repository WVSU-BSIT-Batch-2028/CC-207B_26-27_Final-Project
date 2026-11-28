import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';
import '../../services/api_client.dart';
import '../../services/journal_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_formatting.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'journal_note_screen.dart';
import 'widgets/journal_widgets.dart';

/// Displays private observation notes for the active child, newest first.
///
/// Handles loading, empty, error, offline, and access-denied states without
/// logging note content.
class JournalScreen extends StatefulWidget {
  /// Creates a [JournalScreen].
  ///
  /// Supply [journalService] in tests to override the signed-in API client.
  const JournalScreen({super.key, this.journalService});

  /// Service used to load notes, or `null` to use the signed-in client.
  final JournalService? journalService;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  Future<List<JournalEntry>>? _entriesFuture;
  String? _loadedChildId;
  final _searchController = TextEditingController();
  DateTime? _filterDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filters notes on-device so search terms are never sent to the server.
  List<JournalEntry> _filtered(List<JournalEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    final filterDate = _filterDate;
    final day = filterDate == null ? null : formatIsoDate(filterDate);

    return entries.where((entry) {
      final matchesQuery =
          query.isEmpty || entry.content.toLowerCase().contains(query);
      final matchesDay = day == null || entry.entryDate == day;
      return matchesQuery && matchesDay;
    }).toList();
  }

  Future<void> _pickFilterDate() async {
    final picked = await pickJournalDate(
      context,
      initialDate: _filterDate ?? DateTime.now(),
      helpText: 'Show notes from',
    );
    if (picked != null && mounted) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final childId = AuthScope.of(context).activeChild?.id;
    if (childId != null && childId != _loadedChildId) {
      // Clear active filters when switching to a different child so previous
      // criteria do not hide the newly selected child's notes.
      if (_loadedChildId != null) {
        _searchController.clear();
        _filterDate = null;
      }
      _load(childId);
    }
  }

  void _load(String childId) {
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    setState(() {
      _loadedChildId = childId;
      _entriesFuture = service.getJournalEntries(childId).then(_newestFirst);
    });
  }

  void _reload() {
    final childId = _loadedChildId;
    if (childId != null) {
      _load(childId);
    }
  }

  // Sorts newest first by ISO 'YYYY-MM-DD' entry date, then creation time.
  List<JournalEntry> _newestFirst(List<JournalEntry> entries) {
    final sortedEntries = List<JournalEntry>.from(entries);
    sortedEntries.sort((a, b) {
      final dateComparison = b.entryDate.compareTo(a.entryDate);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sortedEntries;
  }

  @override
  Widget build(BuildContext context) {
    final childName = AuthScope.of(context).activeChild?.nickname;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewNote,
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: ListView(
        // Leave bottom clearance so the extended FAB does not cover the last card.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space16,
          AppSpacing.space16,
          88,
        ),
        children: [
          ScreenHeader(
            title: 'Journal',
            subtitle: childName == null
                ? 'Your private notes.'
                : 'Your private notes about $childName.',
          ),
          const SizedBox(height: AppSpacing.space16),
          _buildFilters(),
          const SizedBox(height: AppSpacing.space16),
          FutureBuilder<List<JournalEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView(message: 'Loading notes...');
              }
              if (snapshot.hasError) {
                return _buildError(snapshot.error);
              }
              final entries = snapshot.data ?? const <JournalEntry>[];
              if (entries.isEmpty) {
                return const EmptyStateView(
                  title: 'No notes yet',
                  message:
                      'Write down a moment you noticed. '
                      'Only you can see your notes.',
                  icon: Icons.edit_note,
                );
              }
              final shown = _filtered(entries);
              if (shown.isEmpty) {
                return const EmptyStateView(
                  title: 'No notes match your search',
                  message:
                      'Try a different word or date, '
                      'or clear the filters to see all notes.',
                  icon: Icons.search_off,
                );
              }
              return Column(
                children: [
                  for (final entry in shown)
                    JournalEntryCard(
                      entry: entry,
                      onTap: () => _openNote(entry),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openNewNote() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            JournalNoteScreen(journalService: widget.journalService),
      ),
    );
    if (saved == true && mounted) {
      _reload();
    }
  }

  Future<void> _openNote(JournalEntry entry) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JournalNoteScreen(
          entry: entry,
          journalService: widget.journalService,
        ),
      ),
    );
    if (changed == true && mounted) {
      _reload();
    }
  }

  Widget _buildFilters() {
    final filterDate = _filterDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search notes',
            prefixIcon: Icon(Icons.search),
          ),
          // Rebuild on every change so the list filters while typing.
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.space12),
        Wrap(
          spacing: AppSpacing.space8,
          runSpacing: AppSpacing.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFilterDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                filterDate == null
                    ? 'Filter by date'
                    : DateFormat.yMMMd().format(filterDate),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
            if (filterDate != null)
              TextButton(
                onPressed: () => setState(() => _filterDate = null),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTarget),
                ),
                child: const Text('Clear date'),
              ),
          ],
        ),
      ],
    );
  }

  // Omits raw exception text so note or child details are never revealed.
  Widget _buildError(Object? error) {
    if (error is NoConnectionApiException) {
      return OfflineStatusCard(
        message: 'Your notes will show when you reconnect.',
        retryLabel: 'Try again',
        onRetry: _reload,
      );
    }
    // Treat 403 and 404 identically to avoid leaking profile existence.
    final denied =
        error is NotFoundApiException ||
        (error is ApiException && error.statusCode == 403);
    if (denied) {
      return const EmptyStateView(
        title: "This journal isn't available",
        message: 'It may have been removed, or it belongs to another account.',
        icon: Icons.lock_outline,
      );
    }
    return ErrorView(
      message: "Couldn't load your notes. Please try again.",
      onRetry: _reload,
    );
  }
}
