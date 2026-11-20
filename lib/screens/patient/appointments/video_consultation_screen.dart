import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/contact_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/appointment.dart';
import '../../../models/appointment_status.dart';
import '../../../widgets/h360_button.dart';

/// Patient Video Consultation screen.
///
/// Displays the doctor's information, a video-call-style preview,
/// Google Meet joining instructions, and clinic contact information.
/// The actual meeting is opened using the appointment's meeting URL.
class VideoConsultationScreen extends StatelessWidget {
  /// Creates the video consultation screen.
  const VideoConsultationScreen({
    super.key,
    required this.appointment,
  });

  /// Appointment information used by this screen.
  final Appointment appointment;

  /// Checks whether the appointment has a valid Google Meet link.
  bool get _hasMeetingLink {
    final link = appointment.meetingUrl?.trim() ?? '';
    final uri = Uri.tryParse(link);

    return appointment.status == AppointmentStatus.confirmed &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'meet.google.com' &&
        uri.pathSegments.isNotEmpty;
  }

  /// Opens the appointment's Google Meet URL in an external application.
  Future<void> _joinConsultation(BuildContext context) async {
    if (appointment.status != AppointmentStatus.confirmed) {
      _showMessage(
        context,
        'You can only join a confirmed appointment.',
      );
      return;
    }

    final link = appointment.meetingUrl?.trim() ?? '';

    if (link.isEmpty) {
      _showMessage(
        context,
        'The meeting link has not been provided yet.',
      );
      return;
    }

    final uri = Uri.tryParse(link);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'meet.google.com' ||
        uri.pathSegments.isEmpty) {
      _showMessage(context, 'The Google Meet link is invalid.');
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!context.mounted) return;

      if (!opened) {
        _showMessage(context, 'Unable to open the meeting link.');
      }
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'An error occurred while opening the meeting.',
      );
    }
  }

  /// Opens the phone application using the clinic's contact number.
  Future<void> _contactClinic(BuildContext context) async {
    final uri = Uri(
      scheme: 'tel',
      path: ContactInfo.supportPhone,
    );

    try {
      final opened = await launchUrl(uri);

      if (!context.mounted) return;

      if (!opened) {
        _showMessage(context, 'Unable to open the phone application.');
      }
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'An error occurred while opening the phone application.',
      );
    }
  }

  /// Displays a message using a SnackBar.
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Formats the appointment date and time.
  String _formatSchedule(BuildContext context) {
    final date = MaterialLocalizations.of(context).formatMediumDate(
      appointment.dateTime,
    );

    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(appointment.dateTime),
    );

    return '$date • $time';
  }

  /// Builds the video consultation screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          appointment.doctorName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Original doctor preview area.
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: const Color(0xFF263B59),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: Color(0xFF405777),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 54,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          appointment.doctorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Video consultation',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Small video indicator.
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Appointment details.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointment Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Doctor',
                    value: appointment.doctorName,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: Icons.medical_services_outlined,
                    label: 'Specialty',
                    value: appointment.specialty,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Schedule',
                    value: _formatSchedule(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Instructions for joining Google Meet.
            Text(
              'How to Join',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),

            const _InstructionRow(
              number: '1',
              text: 'Tap Join Consultation to open your Google Meet link.',
            ),
            const _InstructionRow(
              number: '2',
              text:
                  'Use the Google Meet app or open the meeting in your phone browser.',
            ),
            const _InstructionRow(
              number: '3',
              text:
                  'Allow Google Meet to access your camera and microphone when prompted.',
            ),

            const SizedBox(height: AppSpacing.md),

            // Internet connection reminder.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.wifi_rounded,
                    color: Colors.white,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Make sure you have a stable internet connection '
                      'before joining your consultation.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Join button is enabled only for confirmed appointments
            // that have a valid Google Meet URL.
            H360Button(
              label: _hasMeetingLink
                  ? 'Join Consultation'
                  : appointment.status != AppointmentStatus.confirmed
                      ? 'Appointment Not Confirmed'
                      : 'Meeting Link Not Available',
              icon: Icons.video_call_rounded,
              onPressed:
                  _hasMeetingLink ? () => _joinConsultation(context) : null,
              expanded: true,
            ),

            const SizedBox(height: AppSpacing.md),

            // Clinic contact action.
            OutlinedButton.icon(
              onPressed: () => _contactClinic(context),
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Contact Clinic'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Clinic contact: ${ContactInfo.supportPhone}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Displays one appointment detail with an icon and label.
class _DetailRow extends StatelessWidget {
  /// Creates an appointment detail row.
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Builds the appointment detail row.
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 19),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays one numbered instruction for joining the consultation.
class _InstructionRow extends StatelessWidget {
  /// Creates a numbered joining instruction.
  const _InstructionRow({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  /// Builds the instruction row.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.brandNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
