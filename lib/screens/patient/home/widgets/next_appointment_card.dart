import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../models/appointment.dart';
import '../../../../widgets/h360_button.dart';

/// Hero card for the next appointment.
class NextAppointmentCard extends StatelessWidget {
  const NextAppointmentCard({super.key, required this.appointment, required this.onViewDetails});

  final Appointment appointment;
  final VoidCallback onViewDetails;

  static String _initials(String doctorName) {
    final parts = doctorName.replaceAll('Dr. ', '').trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return 'Dr';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(color: Color(0x401D4ED8), blurRadius: 28, offset: Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              const Positioned(right: -40, top: -40, child: _Circle(size: 150, opacity: 0.10)),
              const Positioned(right: 40, bottom: -60, child: _Circle(size: 120, opacity: 0.07)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Pill(
                          icon: Icons.event_available_rounded,
                          label: 'Next appointment',
                          background: Colors.white.withOpacity(0.18),
                          foreground: Colors.white,
                        ),
                        const Spacer(),
                        _Pill(
                          label: relativeDayLabel(a.dateTime),
                          background: Colors.white,
                          foreground: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      a.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            _initials(a.doctorName),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.doctorName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                a.specialty,
                                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.white.withOpacity(0.18),
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      text: '${formatWeekdayDate(a.dateTime)} · ${formatTime(a.dateTime)}',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: a.isVideo ? Icons.videocam_rounded : Icons.place_rounded,
                      text: a.isVideo ? 'Video consultation (Google Meet)' : a.location,
                    ),
                    const SizedBox(height: 18),
                    H360Button(
                      label: 'View details',
                      icon: Icons.arrow_forward_rounded,
                      inverted: true,
                      onPressed: onViewDetails,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the patient has nothing booked yet.
class NoAppointmentCard extends StatelessWidget {
  const NoAppointmentCard({super.key, required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy_rounded, color: AppColors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            'No upcoming appointments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Book a consultation and it will show up here.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          H360Button(label: 'Book appointment', icon: Icons.add_rounded, onPressed: onBook),
        ],
      ),
    );
  }
}

/// Decorative translucent circle.
class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );
}

/// Small label on the hero card (e.g. "Next appointment", "Today").
class _Pill extends StatelessWidget {
  const _Pill({this.icon, required this.label, required this.background, required this.foreground});
  final IconData? icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

/// Icon and text line (date, time, place).
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      );
}
