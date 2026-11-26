import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_match_suggestion.dart';
import '../models/found_item.dart';
import '../models/lost_item.dart';
import '../services/ai_match_service.dart';
import '../services/found_item_storage.dart';
import '../services/lost_item_storage.dart';
import '../widgets/report_image.dart';
import 'browse_reports_screen.dart';
import 'claim_screen.dart';

class AiMatchScreen extends StatefulWidget {
  const AiMatchScreen({super.key});

  @override
  State<AiMatchScreen> createState() => _AiMatchScreenState();
}

class _AiMatchScreenState extends State<AiMatchScreen> {
  final _lostItemStorage = LostItemStorage();
  final _foundItemStorage = FoundItemStorage();
  final _aiMatchService = AiMatchService();

  late Future<_MatchData> _dataFuture;
  String? _selectedLostItemId;

  // null = nothing requested yet. An empty list = the AI found no match.
  List<AiMatchSuggestion>? _suggestions;

  // Found-item IDs the user marked as "Not a match".
  final Set<String> _dismissed = {};

  String? _errorMessage;
  bool _isMatching = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = loadData();
  }

  Future<_MatchData> loadData() async {
    final lostItems = await _lostItemStorage.loadAll();
    final foundItems = await _foundItemStorage.loadAll();

    return _MatchData(lostItems: lostItems, foundItems: foundItems);
  }

  void reloadData() {
    setState(() {
      _dataFuture = loadData();
      _selectedLostItemId = null;
      _suggestions = null;
      _dismissed.clear();
      _errorMessage = null;
    });
  }

  Future<void> generateSuggestions(
    List<LostItem> lostItems,
    List<FoundItem> foundItems,
  ) async {
    final selectedLostItem = lostItems.firstWhere(
      (item) => item.id == _selectedLostItemId,
    );

    setState(() {
      _isMatching = true;
      _suggestions = null;
      _dismissed.clear();
      _errorMessage = null;
    });

    try {
      final result = await _aiMatchService.suggestMatches(
        lostItem: selectedLostItem,
        foundItems: foundItems,
      );

      if (!mounted) return;

      setState(() {
        _suggestions = result;
      });
    } catch (error) {
      debugPrint('AI matching error: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMatching = false;
        });
      }
    }
  }

  /// A clear reason for each kind of failure. The manual options stay
  /// available in every case.
  String _messageFor(Object error) {
    if (error is TimeoutException) {
      return 'AI matching took too long to answer. Please try again, or '
          'use Browse Reports and Submit a Claim manually.';
    }
    if (error is FormatException) {
      return 'AI matching gave an answer that could not be read. Please '
          'try again, or use Browse Reports and Submit a Claim manually.';
    }
    return 'AI matching is temporarily unavailable. Please try again '
        'later, or use Browse Reports and Submit a Claim manually.';
  }

  void _openClaim({String? foundItemId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClaimScreen(initialFoundItemId: foundItemId),
      ),
    );
  }

  void _openBrowse() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BrowseReportsScreen()),
    );
  }

  /// The AI results panel: labeled, and every suggestion can be dismissed.
  Widget _buildSuggestions(BuildContext context, List<FoundItem> foundItems) {
    final byId = {for (final item in foundItems) item.id: item};

    // Keep only suggestions the user has not dismissed.
    final visible = _suggestions!
        .where(
          (s) =>
              byId.containsKey(s.candidateId) &&
              !_dismissed.contains(s.candidateId),
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI-generated suggestions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'These are guesses based on public descriptions only. You decide: '
            'dismiss anything that is not a match. Staff verify every claim.',
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty) ...[
            Text(
              _suggestions!.isEmpty
                  ? 'No plausible matches found. Please use manual search and '
                        'staff verification.'
                  : 'You dismissed every suggestion. You can still browse all '
                        'reports yourself.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openBrowse,
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('Browse Reports Manually'),
            ),
          ] else
            for (final suggestion in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SuggestionCard(
                  item: byId[suggestion.candidateId]!,
                  reason: suggestion.reason,
                  onDismiss: () {
                    setState(() {
                      _dismissed.add(suggestion.candidateId);
                    });
                  },
                  onClaim: () =>
                      _openClaim(foundItemId: suggestion.candidateId),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Match Suggestions')),
      body: FutureBuilder<_MatchData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load reports.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: reloadData,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final activeFoundItems = data.foundItems
              .where((item) => item.status == 'found')
              .toList();

          if (data.lostItems.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Submit a lost-item report before requesting AI match suggestions.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (activeFoundItems.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'There are no active found-item reports available to compare.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find possible matches',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI compares public report details only. Its suggestions '
                      'are not proof of ownership and must be verified by staff.',
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLostItemId,
                      decoration: const InputDecoration(
                        labelText: 'Select your lost-item report',
                        border: OutlineInputBorder(),
                      ),
                      items: data.lostItems
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.name} - ${item.location}'),
                            ),
                          )
                          .toList(),
                      onChanged: _isMatching
                          ? null
                          : (value) {
                              setState(() {
                                _selectedLostItemId = value;
                                _suggestions = null;
                                _dismissed.clear();
                                _errorMessage = null;
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _selectedLostItemId == null || _isMatching
                          ? null
                          : () => generateSuggestions(
                              data.lostItems,
                              activeFoundItems,
                            ),
                      icon: _isMatching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isMatching
                            ? 'Checking possible matches...'
                            : 'Find Possible Matches',
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isMatching)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('This can take up to 25 seconds.'),
                      ),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_errorMessage!),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _isMatching
                                  ? null
                                  : () => generateSuggestions(
                                      data.lostItems,
                                      activeFoundItems,
                                    ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _openBrowse,
                                  icon: const Icon(Icons.manage_search_rounded),
                                  label: const Text('Browse Reports Manually'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _openClaim(),
                                  icon: const Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                  label: const Text('Submit a Claim'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (_suggestions != null)
                      _buildSuggestions(context, activeFoundItems),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One suggested found item, with the AI's reason and the user's choices.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.item,
    required this.reason,
    required this.onDismiss,
    required this.onClaim,
  });

  final FoundItem item;
  final String reason;
  final VoidCallback onDismiss;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${item.category} - found at ${item.locationFound}'),
            Text('Date found: ${item.dateFound}'),
            if (item.hasImage) ...[
              const SizedBox(height: 12),
              ReportImage(
                key: ValueKey('found_${item.id}'),
                type: 'found',
                reportId: item.id,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Why the AI suggested it',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(reason),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                  label: const Text('Not a match'),
                ),
                FilledButton.icon(
                  onPressed: onClaim,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('This might be mine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchData {
  const _MatchData({required this.lostItems, required this.foundItems});

  final List<LostItem> lostItems;
  final List<FoundItem> foundItems;
}
