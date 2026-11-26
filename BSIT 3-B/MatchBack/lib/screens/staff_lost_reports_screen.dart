import 'package:flutter/material.dart';

import '../models/lost_item.dart';
import '../services/auth_service.dart';
import '../services/lost_item_storage.dart';
import '../theme/paper_theme.dart';
import '../utils/date_format.dart';
import '../widgets/contact_reveal.dart';
import '../widgets/report_image.dart';

class StaffLostReportsScreen extends StatefulWidget {
  const StaffLostReportsScreen({super.key});

  @override
  State<StaffLostReportsScreen> createState() => _StaffLostReportsScreenState();
}

class _StaffLostReportsScreenState extends State<StaffLostReportsScreen> {
  final _storage = LostItemStorage();
  late Future<List<LostItem>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _storage.loadAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _reportsFuture = _storage.loadAll();
    });
    await _reportsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = AuthService.current?.isStaff ?? false;

    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lost-Report Details')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This page is for staff only.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lost-Report Details')),
      body: FutureBuilder<List<LostItem>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('Could not load lost reports.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(child: Text('No lost reports yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = reports[index];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(report.description),
                            const SizedBox(height: 6),
                            Text('${report.category} - ${report.location}'),
                            Text('Date lost: ${report.dateLost}'),
                            if (report.createdAt != null)
                              Text(
                                'Reported: ${formatPhilippineTime(report.createdAt!)}',
                              ),
                            const SizedBox(height: 12),
                            ContactReveal(
                              key: ValueKey('lost_contact_${report.id}'),
                              kind: 'lost',
                              refId: report.id,
                            ),
                            if (report.hasImage) ...[
                              const SizedBox(height: 12),
                              ReportImage(
                                key: ValueKey('lost_${report.id}'),
                                type: 'lost',
                                reportId: report.id,
                              ),
                            ],
                            const SizedBox(height: 12),
                            _PrivateDetail(
                              storage: _storage,
                              reportId: report.id,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Loads the protected private detail only when staff ask for it.
class _PrivateDetail extends StatefulWidget {
  const _PrivateDetail({required this.storage, required this.reportId});

  final LostItemStorage storage;
  final String reportId;

  @override
  State<_PrivateDetail> createState() => _PrivateDetailState();
}

class _PrivateDetailState extends State<_PrivateDetail> {
  bool _loading = false;
  bool _loaded = false;
  String? _detail;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await widget.storage.loadPrivateDetail(widget.reportId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the private detail. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading...'),
        ],
      );
    }

    if (_loaded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Paper.mustard.withValues(alpha: 0.25),
          border: Border.all(color: Paper.ink, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRIVATE DETAIL', style: Paper.mono(11)),
            const SizedBox(height: 6),
            Text(
              _detail ?? 'No private detail was saved for this report.',
              style: Paper.body(15, color: Paper.ink),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Show private detail'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        ],
      ],
    );
  }
}
