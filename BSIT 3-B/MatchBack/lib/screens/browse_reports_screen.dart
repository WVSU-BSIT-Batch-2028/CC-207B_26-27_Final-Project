import 'package:flutter/material.dart';

import '../models/found_item.dart';
import '../models/lost_item.dart';
import '../services/found_item_storage.dart';
import '../services/lost_item_storage.dart';
import '../utils/date_format.dart';
import '../utils/status_labels.dart';
import '../widgets/report_image.dart';

enum ReportFilter { all, lost, found }

class BrowseReportsScreen extends StatefulWidget {
  const BrowseReportsScreen({super.key});

  @override
  State<BrowseReportsScreen> createState() => _BrowseReportsScreenState();
}

class _BrowseReportsScreenState extends State<BrowseReportsScreen> {
  final _lostStorage = LostItemStorage();
  final _foundStorage = FoundItemStorage();

  late Future<_ReportData> _reportsFuture;
  ReportFilter _selectedFilter = ReportFilter.all;

  @override
  void initState() {
    super.initState();
    _reportsFuture = loadReports();
  }

  Future<_ReportData> loadReports() async {
    final lostReports = await _lostStorage.loadAll();
    final foundReports = await _foundStorage.loadAll();

    return _ReportData(lostReports: lostReports, foundReports: foundReports);
  }

  Future<void> refreshReports() async {
    setState(() {
      _reportsFuture = loadReports();
    });

    await _reportsFuture;
  }

  Color reportStatusColor(String status) {
    switch (status) {
      case 'found':
        return Colors.teal;
      case 'claim_pending':
      case 'claimed':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'returned':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'lost':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Reports')),
      body: FutureBuilder<_ReportData>(
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
                    const Text('Could not load reports.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: refreshReports,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final allReports = [
            ...data.lostReports.map(
              (report) => ReportCardData(
                id: report.id,
                type: 'Lost',
                category: report.category,
                name: report.name,
                description: report.description,
                location: report.location,
                date: report.dateLost,
                reportedAt: report.createdAt,
                status: report.status,
                hasImage: report.hasImage,
              ),
            ),
            ...data.foundReports.map(
              (report) => ReportCardData(
                id: report.id,
                type: 'Found',
                category: report.category,
                name: report.name,
                description: report.description,
                location: report.locationFound,
                date: report.dateFound,
                readyAt: report.readyAt,
                returnedAt: report.returnedAt,
                reportedAt: report.createdAt,
                status: report.status,
                hasImage: report.hasImage,
              ),
            ),
          ];

          final filteredReports = allReports.where((report) {
            if (_selectedFilter == ReportFilter.lost) {
              return report.type == 'Lost';
            }

            if (_selectedFilter == ReportFilter.found) {
              return report.type == 'Found';
            }

            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: refreshReports,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Find an item',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browse reports and use filters to narrow the list.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedFilter == ReportFilter.all,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = ReportFilter.all;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Lost'),
                      selected: _selectedFilter == ReportFilter.lost,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = ReportFilter.lost;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Found'),
                      selected: _selectedFilter == ReportFilter.found,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = ReportFilter.found;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (filteredReports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 56),
                        SizedBox(height: 12),
                        Text('No reports match this filter.'),
                      ],
                    ),
                  )
                else
                  ...filteredReports.map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                child: Icon(
                                  report.type == 'Lost'
                                      ? Icons.search
                                      : Icons.check_circle_outline,
                                ),
                              ),
                              title: Text(report.name),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(report.description),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${report.category} - ${report.location}',
                                    ),
                                    // The date the person typed in the form.
                                    Text(
                                      report.type == 'Lost'
                                          ? 'Date lost: ${report.date}'
                                          : 'Date found: ${report.date}',
                                    ),
                                    // The time the server stored the report.
                                    if (report.reportedAt != null)
                                      Text(
                                        'Reported: ${formatPhilippineTime(report.reportedAt!)}',
                                      ),
                                  ],
                                ),
                              ),
                              trailing: Chip(
                                label: Text(itemStatusLabel(report.status)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: reportStatusColor(
                                  report.status,
                                ).withValues(alpha: 0.14),
                                labelStyle: TextStyle(
                                  color: reportStatusColor(report.status),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Shown only once staff have recorded the event,
                            // so a false collection date is never displayed.
                            if (report.returnedAt != null ||
                                report.readyAt != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Text(
                                  report.returnedAt != null
                                      ? 'Claimed / Returned: ${formatPhilippineTime(report.returnedAt!)}'
                                      : 'Ready for collection since: ${formatPhilippineTime(report.readyAt!)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (report.hasImage)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: ReportImage(
                                  key: ValueKey('${report.type}_${report.id}'),
                                  type: report.type.toLowerCase(),
                                  reportId: report.id,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportData {
  const _ReportData({required this.lostReports, required this.foundReports});

  final List<LostItem> lostReports;
  final List<FoundItem> foundReports;
}

class ReportCardData {
  const ReportCardData({
    required this.id,
    required this.type,
    required this.category,
    required this.name,
    required this.description,
    required this.location,
    required this.date,
    required this.reportedAt,
    this.readyAt,
    this.returnedAt,
    required this.status,
    required this.hasImage,
  });

  final String id;
  final String type;
  final String category;
  final String name;
  final String description;
  final String location;
  final String date;
  final DateTime? reportedAt;
  final DateTime? readyAt;
  final DateTime? returnedAt;
  final String status;
  final bool hasImage;
}
