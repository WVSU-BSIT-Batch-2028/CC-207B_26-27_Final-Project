import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/lookout_app_bar.dart';

class AnalyticsScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const AnalyticsScreen({super.key, this.onMenuPressed});

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: LookOutAppBar(title: 'Analytics', onMenuPressed: onMenuPressed),
      body: uid == null
          ? const Center(child: Text('Sign in to view your ride analytics.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load account details: '
                        '${userSnapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Loader.circular();
                }
                if (userSnapshot.data?.exists != true) {
                  return const Center(
                    child: Text('Unable to load your analytics profile.'),
                  );
                }

                final isDriver = userSnapshot.data?.data()?['role'] == 'driver';
                return _buildAnalytics(context, uid, isDriver: isDriver);
              },
            ),
    );
  }

  Widget _buildAnalytics(
    BuildContext context,
    String uid, {
    required bool isDriver,
  }) {
    final firestore = FirebaseFirestore.instance;
    final historyStream = isDriver
        ? firestore
              .collection('driver_trips')
              .where('driverUid', isEqualTo: uid)
              .snapshots()
        : firestore
              .collection('rides')
              .where('commuterUid', isEqualTo: uid)
              .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: historyStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load ride analytics: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Loader.circular();
        }

        final rides = snapshot.data?.docs ?? [];
        final totalSecondsByWeekday = List<double>.filled(7, 0);
        final rideCountsByWeekday = List<int>.filled(7, 0);
        var totalDurationSeconds = 0.0;
        var ridesWithDuration = 0;

        for (final ride in rides) {
          final data = ride.data();
          final startedAt = data['startedAt'];
          final durationSeconds = _durationSeconds(data);
          if (startedAt is! Timestamp ||
              durationSeconds == null ||
              durationSeconds <= 0) {
            continue;
          }

          final weekday = startedAt.toDate().toLocal().weekday - 1;
          totalSecondsByWeekday[weekday] += durationSeconds;
          rideCountsByWeekday[weekday]++;
          totalDurationSeconds += durationSeconds;
          ridesWithDuration++;
        }

        final weekdayStats = List.generate(
          _weekdayLabels.length,
          (index) => _WeekdayRideStats(
            label: _weekdayLabels[index],
            averageMinutes: rideCountsByWeekday[index] == 0
                ? 0
                : totalSecondsByWeekday[index] /
                      rideCountsByWeekday[index] /
                      60,
            rideCount: rideCountsByWeekday[index],
          ),
        );
        final weekdaysWithRides = weekdayStats
            .where((day) => day.rideCount > 0)
            .toList();
        final slowestWeekday = weekdaysWithRides.isEmpty
            ? null
            : weekdaysWithRides.reduce(
                (first, second) => first.averageMinutes >= second.averageMinutes
                    ? first
                    : second,
              );
        final overallAverageMinutes = ridesWithDuration == 0
            ? null
            : totalDurationSeconds / ridesWithDuration / 60;
        final recordType = isDriver ? 'trip' : 'ride';
        final metricCards = [
          _MetricCard(
            title: isDriver ? 'Trips recorded' : 'Rides recorded',
            value: rides.length.toString(),
            icon: Icons.route_outlined,
          ),
          _MetricCard(
            title: 'Average $recordType duration',
            value: _formatDuration(overallAverageMinutes),
            icon: Icons.schedule_outlined,
          ),
          _MetricCard(
            title: 'Longest average weekday',
            value: slowestWeekday?.label ?? '—',
            icon: Icons.trending_up,
          ),
          _MetricCard(
            title: 'Days with recorded ${isDriver ? 'trips' : 'rides'}',
            value: weekdaysWithRides.length.toString(),
            icon: Icons.calendar_today_outlined,
          ),
        ];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              isDriver ? 'Your Driver Analytics' : 'Your Ride Analytics',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Compare your average $recordType duration by weekday. Longer '
              'durations may indicate heavier traffic; this is based on your '
              'past $recordType history, not live traffic data.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 132,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metricCards.length,
              itemBuilder: (context, index) => metricCards[index],
            ),
            const SizedBox(height: 20),
            _RideDurationChart(days: weekdayStats, recordType: recordType),
          ],
        );
      },
    );
  }
}

double? _durationSeconds(Map<String, dynamic> ride) {
  final storedDuration = ride['durationSeconds'];
  if (storedDuration is num && storedDuration.isFinite && storedDuration >= 0) {
    return storedDuration.toDouble();
  }

  final startedAt = ride['startedAt'];
  final endedAt = ride['endedAt'];
  if (startedAt is Timestamp && endedAt is Timestamp) {
    final duration = endedAt.toDate().difference(startedAt.toDate()).inSeconds;
    return duration >= 0 ? duration.toDouble() : null;
  }
  return null;
}

String _formatDuration(double? minutes) {
  if (minutes == null) return '—';
  if (minutes >= 60) return '${(minutes / 60).toStringAsFixed(1)} hr';
  return '${minutes.toStringAsFixed(1)} min';
}

class _WeekdayRideStats {
  const _WeekdayRideStats({
    required this.label,
    required this.averageMinutes,
    required this.rideCount,
  });

  final String label;
  final double averageMinutes;
  final int rideCount;
}

class _RideDurationChart extends StatelessWidget {
  const _RideDurationChart({required this.days, required this.recordType});

  final List<_WeekdayRideStats> days;
  final String recordType;

  String get _pluralRecordType => recordType == 'trip' ? 'trips' : 'rides';

  double get _axisMaximum {
    final maxMinutes = days.fold<double>(
      0,
      (maximum, day) =>
          day.averageMinutes > maximum ? day.averageMinutes : maximum,
    );
    if (maxMinutes <= 0) return 10;

    final step = maxMinutes <= 10
        ? 2
        : maxMinutes <= 30
        ? 5
        : maxMinutes <= 60
        ? 10
        : 30;
    return (maxMinutes / step).ceilToDouble() * step;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final axisMaximum = _axisMaximum;
    final midpoint = (axisMaximum / 2).round();
    final hasRideData = days.any((day) => day.rideCount > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average $recordType duration by weekday',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Duration (minutes)',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                axisMaximum.round().toString(),
                                style: textTheme.labelSmall,
                              ),
                              Text(
                                midpoint.toString(),
                                style: textTheme.labelSmall,
                              ),
                              Text('0', style: textTheme.labelSmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: _DurationGridPainter(
                                      color: colors.outlineVariant,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final day in days)
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                            ),
                                            child: Tooltip(
                                              message: day.rideCount == 0
                                                  ? '${day.label}: no $recordType data'
                                                  : '${day.label}: '
                                                        '${day.averageMinutes.toStringAsFixed(1)} min average '
                                                        '(${day.rideCount} $_pluralRecordType)',
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Container(
                                                  width: 18,
                                                  height: day.rideCount == 0
                                                      ? 0
                                                      : (constraints.maxHeight *
                                                                day.averageMinutes /
                                                                axisMaximum)
                                                            .clamp(
                                                              0.0,
                                                              constraints
                                                                  .maxHeight,
                                                            )
                                                            .toDouble(),
                                                  decoration: BoxDecoration(
                                                    color: colors.primary,
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            4,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 44),
                      for (final day in days)
                        Expanded(
                          child: Column(
                            children: [
                              Text(day.label, style: textTheme.labelSmall),
                              Text(
                                day.rideCount == 0
                                    ? '—'
                                    : '${day.averageMinutes.round()}m',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!hasRideData) ...[
              const SizedBox(height: 12),
              Text(
                'Completed rides with a start time and duration will appear here.',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DurationGridPainter extends CustomPainter {
  const _DurationGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = size.height * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DurationGridPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: colors.primary),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
